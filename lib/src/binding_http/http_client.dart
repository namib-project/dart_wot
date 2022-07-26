// Copyright 2022 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';

import '../core/content.dart';
import '../core/credentials/basic_credentials.dart';
import '../core/credentials/bearer_credentials.dart';
import '../core/discovery/core_link_format.dart';
import '../core/protocol_interfaces/protocol_client.dart';
import '../core/security_provider.dart';
import '../definitions/form.dart';
import '../definitions/operation_type.dart';
import '../definitions/security/basic_security_scheme.dart';
import '../definitions/security/bearer_security_scheme.dart';
import '../scripting_api/subscription.dart';
import 'http_request_method.dart';
import 'http_security_exception.dart';

const _authorizationHeader = 'Authorization';

/// A [ProtocolClient] for the Hypertext Transfer Protocol (HTTP).
///
/// Supports both HTTP and HTTPS as well as the Basic ([RFC 7617]) and Bearer
/// Token ([RFC 6750]) Security Schemes.
///
/// At most one of the aforementioned Security Schemes should be defined for
/// any [Form] (as there is only one possible value for the `Authorization`
/// header that is used for these Security Schemes).  If multiple Schemes are
/// defined in a [Form], then Bearer > Basic is followed as an order of
/// priority. The definition of multiple Security Schemes will be reworked in
/// the feature using the newly introduced [`ComboSecurityScheme`], which is
/// currently still at risk.
///
/// The use of Proxies is not supported yet, while support for the digest
/// security scheme has been temporarily removed.
///
/// [RFC 7617]: https://datatracker.ietf.org/doc/html/rfc7617
/// [RFC 7616]: https://datatracker.ietf.org/doc/html/rfc7616
/// [RFC 6750]: https://datatracker.ietf.org/doc/html/rfc6750
/// [`ComboSecurityScheme`]: https://w3c.github.io/wot-thing-description/#combosecurityscheme
class HttpClient extends ProtocolClient {
  /// Creates a new [HttpClient].
  HttpClient(this._clientSecurityProvider);

  final _client = Client();

  final ClientSecurityProvider? _clientSecurityProvider;

  Future<void> _applyCredentialsFromForm(Request request, Form form) async {
    // TODO(JKRhb): Add DigestSecurity back in
    if (await _applyBearerCredentialsFromForm(request, form)) {
      return;
    }

    if (await _applyBasicCredentialsFromForm(request, form)) {
      return;
    }
  }

  Future<bool> _applyBasicCredentialsFromForm(
    Request request,
    Form form,
  ) async {
    final basicSecuritySchemes =
        form.securityDefinitions.whereType<BasicSecurityScheme>();

    if (basicSecuritySchemes.isEmpty) {
      return false;
    }

    final basicCredentials =
        await _getBasicCredentials(form.resolvedHref, form);

    if (basicCredentials == null) {
      return false;
    }

    _applyBasicCredentials(basicCredentials, request);

    return true;
  }

  Future<bool> _applyBearerCredentialsFromForm(
    Request request,
    Form form,
  ) async {
    final bearerSecuritySchemes =
        form.securityDefinitions.whereType<BearerSecurityScheme>();

    if (bearerSecuritySchemes.isEmpty) {
      return false;
    }

    final bearerCredentials =
        await _getBearerCredentials(form.resolvedHref, form);

    if (bearerCredentials == null) {
      return false;
    }

    _applyBearerCredentials(bearerCredentials, request);

    return true;
  }

  void _applyBasicCredentials(BasicCredentials credentials, Request request) {
    final username = credentials.username;
    final password = credentials.password;

    final bytes = utf8.encode('$username:$password');
    final base64Credentials = base64.encode(bytes);
    request.headers[_authorizationHeader] = 'Basic $base64Credentials';
  }

  void _applyBearerCredentials(
    BearerCredentials credentials,
    Request request,
  ) {
    request.headers[_authorizationHeader] = 'Bearer ${credentials.token}';
  }

  Request _copyRequest(Request request) {
    return Request(request.method, request.url)
      ..body = request.body
      ..headers.addAll(request.headers);
  }

  Future<StreamedResponse> _createBasicAuthRequest(
    Request originalRequest,
    Form? form,
  ) async {
    final request = _copyRequest(originalRequest);
    final basicCredentials = await _getBasicCredentials(request.url, form);

    if (basicCredentials == null) {
      throw HttpSecurityException('No BasicCredentials have been provided.');
    }

    _applyBasicCredentials(basicCredentials, request);

    return _client.send(request);
  }

  Future<StreamedResponse> _createBearerAuthRequest(
    Request originalRequest,
    Form? form,
  ) async {
    final request = _copyRequest(originalRequest);
    final bearerCredentials = await _getBearerCredentials(request.url, form);

    if (bearerCredentials == null) {
      throw HttpSecurityException('No BearerCredentials have been provided.');
    }

    _applyBearerCredentials(bearerCredentials, request);

    return _client.send(request);
  }

  Future<StreamedResponse> _handleResponse(
    Request originalRequest,
    StreamedResponse response, [
    Form? form,
  ]) async {
    if (response.statusCode == HttpStatus.unauthorized) {
      final authenticate = response.headers['www-authenticate'];

      if (authenticate != null) {
        final method = authenticate.split(' ')[0];
        switch (method) {
          case 'Basic':
            return _createBasicAuthRequest(originalRequest, form);
          case 'Bearer':
            return _createBearerAuthRequest(originalRequest, form);
        }
      }
    }

    return response;
  }

  Future<StreamedResponse> _createRequest(
    Form form,
    OperationType operationType,
    String? payload,
  ) async {
    final requestMethod =
        HttpRequestMethod.getRequestMethod(form, operationType);
    final Uri uri = form.resolvedHref;

    final request = Request(requestMethod.methodName, uri)
      ..headers.addAll(_getHeadersFromForm(form));

    if (payload != null) {
      request.body = payload;
    }

    await _applyCredentialsFromForm(request, form);

    final response = await _client.send(request);

    return _handleResponse(request, response, form);
  }

  Future<BasicCredentials?> _getBasicCredentials(Uri uri, Form? form) async {
    return _clientSecurityProvider?.basicCredentialsCallback?.call(uri, form);
  }

  Future<BearerCredentials?> _getBearerCredentials(Uri uri, Form? form) async {
    return _clientSecurityProvider?.bearerCredentialsCallback?.call(uri, form);
  }

  static Map<String, String> _getHeadersFromForm(Form form) {
    final Map<String, String> headers = {'Content-Type': form.contentType};

    final dynamic formHeaders = form.additionalFields['htv:headers'];
    if (formHeaders is List<Map<String, String>>) {
      for (final formHeader in formHeaders) {
        final key = formHeader['htv:fieldName'];
        final value = formHeader['htv:fieldValue'];

        if (key != null && value != null) {
          headers[key] = value;
        }
      }
    }

    return headers;
  }

  Future<String> _getInputFromContent(Content content) async {
    final inputBuffer = await content.byteBuffer;
    return utf8.decoder
        .convert(inputBuffer.asUint8List().toList(growable: false));
  }

  Content _contentFromResponse(Form form, StreamedResponse response) {
    final type = response.headers['Content-Type'] ?? form.contentType;
    final responseStream = response.stream.asBroadcastStream()
      ..listen(null, onDone: stop);
    return Content(type, responseStream);
  }

  @override
  Future<Content> invokeResource(Form form, Content content) async {
    final input = await _getInputFromContent(content);
    final response =
        await _createRequest(form, OperationType.invokeaction, input);
    return _contentFromResponse(form, response);
  }

  @override
  Future<Content> readResource(Form form) async {
    final response =
        await _createRequest(form, OperationType.readproperty, null);
    return _contentFromResponse(form, response);
  }

  @override
  Future<void> start() async {
    // Do nothing
  }

  @override
  Future<void> stop() async {
    _client.close();
  }

  @override
  Future<void> writeResource(Form form, Content content) async {
    final input = await _getInputFromContent(content);
    await _createRequest(form, OperationType.writeproperty, input);
  }

  @override
  Future<Subscription> subscribeResource(
    Form form, {
    required void Function(Content content) next,
    void Function(Exception error)? error,
    required void Function() complete,
  }) async {
    // TODO(JKRhb): implement subscribeResource
    throw UnimplementedError();
  }

  Future<Content> _sendDiscoveryRequest(
    Request request, {
    required String acceptHeaderValue,
  }) async {
    request.headers['Accept'] = acceptHeaderValue;
    final response = await _client.send(request);
    final finalResponse = await _handleResponse(request, response);
    return Content(
      response.headers['Content-Type'] ?? acceptHeaderValue,
      finalResponse.stream,
    );
  }

  @override
  Stream<Content> discoverDirectly(
    Uri uri, {
    bool disableMulticast = false,
  }) async* {
    final request = Request(HttpRequestMethod.get.methodName, uri);

    yield await _sendDiscoveryRequest(
      request,
      acceptHeaderValue: 'application/td+json',
    );
  }

  @override
  Stream<Content> discoverWithCoreLinkFormat(Uri uri) async* {
    final discoveryUri = createCoreLinkFormatDiscoveryUri(uri);

    final request = Request(HttpRequestMethod.get.methodName, discoveryUri);

    final encodedLinks = await _sendDiscoveryRequest(
      request,
      acceptHeaderValue: 'application/link-format',
    );

    yield encodedLinks;
  }
}
