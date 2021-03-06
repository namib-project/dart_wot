// Copyright 2021 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';
import 'dart:convert';

import 'package:coap/coap.dart' as coap;
import 'package:coap/config/coap_config_default.dart';

import '../core/content.dart';
import '../core/credentials/psk_credentials.dart';
import '../core/discovery/core_link_format.dart';
import '../core/protocol_interfaces/protocol_client.dart';
import '../core/security_provider.dart';
import '../core/thing_discovery.dart';
import '../definitions/form.dart';
import '../definitions/operation_type.dart';
import '../definitions/security/psk_security_scheme.dart';
import '../definitions/thing_description.dart';
import '../scripting_api/subscription.dart';
import 'coap_binding_exception.dart';
import 'coap_config.dart';
import 'coap_definitions.dart';
import 'coap_extensions.dart';
import 'coap_subscription.dart';

class _InternalCoapConfig extends CoapConfigDefault {
  _InternalCoapConfig(CoapConfig coapConfig, this._form)
      : preferredBlockSize =
            coapConfig.blocksize ?? coap.CoapConstants.preferredBlockSize {
    if (!_dtlsNeeded) {
      return;
    }

    final form = _form;

    if (form == null) {
      return;
    }

    if (_usesPskScheme(form) && coapConfig.useTinyDtls) {
      dtlsBackend = coap.DtlsBackend.TinyDtls;
    } else if (coapConfig.useOpenSsl) {
      dtlsBackend = coap.DtlsBackend.OpenSsl;
    }
  }

  @override
  int preferredBlockSize;

  @override
  coap.DtlsBackend? dtlsBackend;

  final Form? _form;

  bool get _dtlsNeeded => _form?.resolvedHref.scheme == 'coaps';
}

bool _usesPskScheme(Form form) {
  return form.securityDefinitions.whereType<PskSecurityScheme>().isNotEmpty;
}

class _CoapRequest {
  /// Creates a new [_CoapRequest]
  _CoapRequest(
    this._form,
    this._requestMethod,
    CoapConfig _coapConfig,
    ClientSecurityProvider? _clientSecurityProvider, [
    this._subprotocol,
  ])  : _coapClient = coap.CoapClient(
          _form.resolvedHref,
          _InternalCoapConfig(_coapConfig, _form),
          pskCredentialsCallback:
              _createPskCallback(_form, _clientSecurityProvider),
        ),
        _requestUri = _form.resolvedHref;

  /// The [CoapClient] which sends out request messages.
  final coap.CoapClient _coapClient;

  /// The [Uri] describing the endpoint for the request.
  final Uri _requestUri;

  /// A reference to the [Form] that is the basis for this request.
  final Form _form;

  /// The [CoapRequestMethod] used in the request message (e. g.
  /// [CoapRequestMethod.get] or [CoapRequestMethod.post]).
  final CoapRequestMethod _requestMethod;

  /// The subprotocol that should be used for requests.
  final CoapSubprotocol? _subprotocol;

  // TODO(JKRhb): blockwise parameters cannot be handled at the moment due to
  //              limitations of the CoAP library
  Future<coap.CoapResponse> _makeRequest(
    String? payload, {
    int format = coap.CoapMediaType.textPlain,
    int accept = coap.CoapMediaType.textPlain,
    int? block1Size,
    int? block2Size,
  }) async {
    final coap.CoapResponse? response;
    switch (_requestMethod) {
      case CoapRequestMethod.get:
        response = await _coapClient.get(
          _requestUri.path,
          earlyBlock2Negotiation: true,
          accept: accept,
        );
        break;
      case CoapRequestMethod.post:
        response = await _coapClient.post(
          _requestUri.path,
          payload: payload ?? '',
          format: format,
        );
        break;
      case CoapRequestMethod.put:
        response = await _coapClient.put(
          _requestUri.path,
          payload: payload ?? '',
          format: format,
        );
        break;
      case CoapRequestMethod.delete:
        response = await _coapClient.delete(_requestUri.path);
        break;
      default:
        throw UnimplementedError(
          'CoAP request method $_requestMethod is not supported yet.',
        );
    }
    _coapClient.close();
    if (response == null) {
      throw CoapBindingException('Sending CoAP request to $_requestUri failed');
    }
    return response;
  }

  static coap.PskCredentialsCallback? _createPskCallback(
    Form form,
    ClientSecurityProvider? clientSecurityProvider,
  ) {
    final pskCredentialsCallback =
        clientSecurityProvider?.pskCredentialsCallback;
    if (!_usesPskScheme(form) || pskCredentialsCallback == null) {
      return null;
    }

    return (identityHint) {
      final PskCredentials? pskCredentials =
          pskCredentialsCallback(form.resolvedHref, form, identityHint);

      if (pskCredentials == null) {
        throw CoapBindingException(
          'Missing PSK credentials for CoAPS request!',
        );
      }

      return coap.PskCredentials(
        identity: pskCredentials.identity,
        preSharedKey: pskCredentials.preSharedKey,
      );
    };
  }

  // TODO(JKRhb): Revisit name of this method
  Future<Content> resolveInteraction(String? payload) async {
    final response = await _makeRequest(
      payload,
      format: _form.format,
      accept: _form.accept,
      block1Size: _form.block1Size,
      block2Size: _form.block2Size,
    );
    final type = coap.CoapMediaType.name(response.contentFormat);
    final body = _getPayloadFromResponse(response);
    return Content(type, body);
  }

  Future<CoapSubscription> startObservation(
    void Function(Content content) next,
    void Function() complete,
  ) async {
    void handleResponse(coap.CoapResponse? response) {
      if (response == null) {
        return;
      }

      final type = coap.CoapMediaType.name(response.contentFormat);
      final body = _getPayloadFromResponse(response);
      final content = Content(type, body);
      next(content);
    }

    final requestContentFormat = _form.format;

    if (_subprotocol == CoapSubprotocol.observe) {
      final request = _requestMethod.generateRequest()
        ..contentFormat = requestContentFormat;
      final observeClientRelation = await _coapClient.observe(request);
      observeClientRelation.stream.listen((event) {
        handleResponse(event.resp);
      });
      return CoapSubscription(_coapClient, observeClientRelation, complete);
    }

    final response = await _makeRequest(null, format: requestContentFormat);
    handleResponse(response);
    return CoapSubscription(_coapClient, null, complete);
  }

  /// Aborts the request and closes the client.
  ///
  // TODO(JKRhb): Check if this is actually enough
  void abort() {
    _coapClient.close();
  }
}

Stream<List<int>> _getPayloadFromResponse(coap.CoapResponse response) {
  if (response.payload != null) {
    return Stream.value(response.payload!);
  } else {
    return const Stream.empty();
  }
}

/// A [ProtocolClient] for the Constrained Application Protocol (CoAP).
class CoapClient extends ProtocolClient {
  /// Creates a new [CoapClient] based on an optional [CoapConfig].
  CoapClient([this._coapConfig, this._clientSecurityProvider]);

  final List<_CoapRequest> _pendingRequests = [];
  final CoapConfig? _coapConfig;

  final ClientSecurityProvider? _clientSecurityProvider;

  _CoapRequest _createRequest(Form form, OperationType operationType) {
    final requestMethod =
        CoapRequestMethod.fromForm(form) ?? operationType.requestMethod;
    final CoapSubprotocol? subprotocol =
        form.coapSubprotocol ?? operationType.subprotocol;
    final coapConfig = _coapConfig ?? CoapConfig();
    final request = _CoapRequest(
      form,
      requestMethod,
      coapConfig,
      _clientSecurityProvider,
      subprotocol,
    );
    _pendingRequests.add(request);
    return request;
  }

  Future<String> _getInputFromContent(Content content) async {
    final inputBuffer = await content.byteBuffer;
    return utf8.decoder
        .convert(inputBuffer.asUint8List().toList(growable: false));
  }

  @override
  Future<Content> readResource(Form form) async {
    final request = _createRequest(form, OperationType.readproperty);
    return request.resolveInteraction(null);
  }

  @override
  Future<void> writeResource(Form form, Content content) async {
    final request = _createRequest(form, OperationType.writeproperty);
    final input = await _getInputFromContent(content);
    await request.resolveInteraction(input);
  }

  @override
  Future<Content> invokeResource(Form form, Content content) async {
    final request = _createRequest(form, OperationType.invokeaction);
    final input = await _getInputFromContent(content);
    return request.resolveInteraction(input);
  }

  @override
  Future<Subscription> subscribeResource(
    Form form, {
    required void Function(Content content) next,
    void Function(Exception error)? error,
    required void Function() complete,
  }) async {
    final OperationType operationType = form.op.firstWhere(
      (element) => [OperationType.subscribeevent, OperationType.observeproperty]
          .contains(element),
      orElse: () => throw CoapBindingException(
        "Subscription form contained neither 'subscribeevent' "
        "nor 'observeproperty' operation type.",
      ),
    );

    final request = _createRequest(form, operationType);

    return request.startObservation(next, complete);
  }

  @override
  Future<void> start() async {
    // Do nothing
  }

  @override
  Future<void> stop() async {
    for (final request in _pendingRequests) {
      request.abort();
    }
    _pendingRequests.clear();
  }

  ThingDescription _handleDiscoveryResponse(
    coap.CoapResponse? response,
    Uri uri,
  ) {
    final rawThingDescription = response?.payloadString;

    if (response == null) {
      throw DiscoveryException('Direct CoAP Discovery from $uri failed!');
    }

    return ThingDescription(rawThingDescription);
  }

  Stream<ThingDescription> _discoverFromMulticast(
    coap.CoapClient client,
    Uri uri,
  ) async* {
    // TODO(JKRhb): This method currently does not work with block-wise transfer
    //               due to a bug in the CoAP library.
    final streamController = StreamController<ThingDescription>();
    final request = coap.CoapRequest(coap.CoapCode.get, confirmable: false)
      ..uriPath = uri.path
      ..accept = coap.CoapMediaType.applicationTdJson;
    final multicastResponseHandler = coap.CoapMulticastResponseHandler(
      (data) {
        final thingDescription = _handleDiscoveryResponse(data.resp, uri);
        streamController.add(thingDescription);
      },
      onError: streamController.addError,
      onDone: () async {
        await streamController.close();
      },
    );

    final response =
        client.send(request, onMulticastResponse: multicastResponseHandler);
    unawaited(response);
    unawaited(
      Future.delayed(
          _coapConfig?.multicastDiscoveryTimeout ?? const Duration(seconds: 20),
          () {
        client
          ..cancel(request)
          ..close();
      }),
    );
    yield* streamController.stream;
  }

  Stream<ThingDescription> _discoverFromUnicast(
    coap.CoapClient client,
    Uri uri,
  ) async* {
    final response = await client.get(
      uri.path,
      accept: coap.CoapMediaType.applicationTdJson,
    );
    client.close();
    yield _handleDiscoveryResponse(response, uri);
  }

  @override
  Stream<ThingDescription> discoverDirectly(
    Uri uri, {
    bool disableMulticast = false,
  }) async* {
    final config = CoapConfigDefault();
    final client = coap.CoapClient(uri, config);

    if (uri.isMulticastAddress) {
      if (!disableMulticast) {
        yield* _discoverFromMulticast(client, uri);
      }
    } else {
      yield* _discoverFromUnicast(client, uri);
    }
  }

  @override
  Stream<Uri> discoverWithCoreLinkFormat(Uri uri) async* {
    final discoveryUri = createCoreLinkFormatDiscoveryUri(uri);
    final coapConfig = _coapConfig ?? CoapConfig();

    final coapClient =
        coap.CoapClient(discoveryUri, _InternalCoapConfig(coapConfig, null));

    // TODO(JKRhb): Multicast could be supported here as well.
    final request = coap.CoapRequest(coap.CoapCode.get)
      ..uriPath = discoveryUri.path
      ..accept = coap.CoapMediaType.applicationLinkFormat;
    final response = await coapClient.send(request);

    coapClient.close();

    if (response == null) {
      throw DiscoveryException(
        'Got no CoRE Link Format Discovery response for $uri',
      );
    }

    final actualContentFormat = response.contentFormat;
    const expectedContentFormat = coap.CoapMediaType.applicationLinkFormat;

    if (actualContentFormat != expectedContentFormat) {
      throw DiscoveryException(
        'Got wrong format for '
        'CoRE Link Format Discovery (expected $expectedContentFormat, got '
        '$actualContentFormat).',
      );
    }

    final payloadString = response.payloadString;

    if (payloadString == null) {
      throw DiscoveryException(
        'Received empty payload for CoRE Link Format Discovery from $uri',
      );
    }

    yield* Stream.fromIterable(parseCoreLinkFormat(payloadString, uri));
  }
}
