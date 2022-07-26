// Copyright 2021 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:coap/coap.dart' as coap;
import 'package:coap/config/coap_config_default.dart';
import 'package:typed_data/typed_buffers.dart';

import '../core/content.dart';
import '../core/credentials/psk_credentials.dart';
import '../core/discovery/core_link_format.dart';
import '../core/protocol_interfaces/protocol_client.dart';
import '../core/security_provider.dart';
import '../core/thing_discovery.dart';
import '../definitions/form.dart';
import '../definitions/operation_type.dart';
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

    if (form.usesPskScheme && coapConfig.useTinyDtls) {
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

coap.PskCredentialsCallback? _createPskCallback(
  Uri uri,
  Form? form,
  ClientSecurityProvider? clientSecurityProvider,
) {
  final usesPskScheme = form?.usesPskScheme ?? false;
  final pskCredentialsCallback = clientSecurityProvider?.pskCredentialsCallback;

  if (!usesPskScheme || pskCredentialsCallback == null) {
    return null;
  }

  return (identityHint) {
    final PskCredentials? pskCredentials =
        pskCredentialsCallback(uri, form, identityHint);

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

Stream<List<int>> _getPayloadFromResponse(coap.CoapResponse response) {
  final payload = response.payload;
  if (payload != null) {
    return Stream.value(payload);
  } else {
    return const Stream.empty();
  }
}

Content _getContentFromResponse(coap.CoapResponse response) {
  final type = coap.CoapMediaType.name(response.contentFormat);
  final body = _getPayloadFromResponse(response);
  return Content(type, body);
}

/// A [ProtocolClient] for the Constrained Application Protocol (CoAP).
class CoapClient extends ProtocolClient {
  /// Creates a new [CoapClient] based on an optional [CoapConfig].
  CoapClient([this._coapConfig, this._clientSecurityProvider]);

  final CoapConfig? _coapConfig;

  final ClientSecurityProvider? _clientSecurityProvider;

  Future<coap.CoapRequest> _createRequest(
    int code,
    Uri uri,
    Content? content,
    int? format,
    int? accept,
    int? block1Size,
    int? block2Size,
  ) async {
    if (!coap.CoapCode.isRequest(code)) {
      throw CoapBindingException(
        '$code is not a valid request method code.',
      );
    }

    final payload = Uint8Buffer();
    if (content != null) {
      payload.addAll((await content.byteBuffer).asUint8List());
    }

    return coap.CoapRequest(code)
      ..payload = payload
      ..uriPath = uri.path
      ..accept = accept ?? coap.CoapMediaType.undefined
      ..contentFormat = format ?? coap.CoapMediaType.undefined;
  }

  Future<Content> _sendRequestFromForm(
    Form form,
    Content? content,
    OperationType operationType,
  ) async {
    final requestMethod =
        CoapRequestMethod.fromForm(form) ?? operationType.requestMethod;
    final code = requestMethod.code;

    return _sendRequest(
      form.resolvedHref,
      content,
      code,
      format: form.format,
      accept: form.accept,
      form: form,
    );
  }

  // TODO(JKRhb): blockwise parameters cannot be handled at the moment due to
  //              limitations of the CoAP library
  Future<Content> _sendRequest(
    Uri uri,
    Content? content,
    int method, {
    required Form? form,
    int? format,
    int? accept,
    int? block1Size,
    int? block2Size,
    coap.CoapMulticastResponseHandler? multicastResponseHandler,
  }) async {
    final coapClient = coap.CoapClient(
      uri,
      _InternalCoapConfig(_coapConfig ?? CoapConfig(), form),
      pskCredentialsCallback:
          _createPskCallback(uri, form, _clientSecurityProvider),
    );

    final request = await _createRequest(
      method,
      uri,
      content,
      format,
      accept,
      block1Size,
      block2Size,
    );

    final response = await coapClient.send(
      request,
      onMulticastResponse: multicastResponseHandler,
    );
    coapClient.close();
    if (response == null) {
      throw CoapBindingException('Sending CoAP request to $uri failed');
    }
    return _getContentFromResponse(response);
  }

  @override
  Future<Content> readResource(Form form) async {
    return _sendRequestFromForm(form, null, OperationType.readproperty);
  }

  @override
  Future<void> writeResource(Form form, Content content) async {
    await _sendRequestFromForm(form, content, OperationType.writeproperty);
  }

  @override
  Future<Content> invokeResource(Form form, Content content) async {
    return _sendRequestFromForm(form, content, OperationType.invokeaction);
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

    return _startObservation(form, operationType, next, complete);
  }

  Future<CoapSubscription> _startObservation(
    Form form,
    OperationType operationType,
    void Function(Content content) next,
    void Function() complete,
  ) async {
    void handleResponse(coap.CoapResponse? response) {
      if (response == null) {
        return;
      }

      next(_getContentFromResponse(response));
    }

    final requestMethod =
        (CoapRequestMethod.fromForm(form) ?? CoapRequestMethod.get).code;

    final request = await _createRequest(
      requestMethod,
      form.resolvedHref,
      null,
      form.format,
      form.accept,
      null,
      null,
    );

    final subprotocol = form.coapSubprotocol ?? operationType.subprotocol;

    final coapClient = coap.CoapClient(
      form.resolvedHref,
      _InternalCoapConfig(_coapConfig ?? CoapConfig(), form),
    );

    if (subprotocol == CoapSubprotocol.observe) {
      final observeClientRelation = await coapClient.observe(request);
      observeClientRelation.stream.listen((event) {
        handleResponse(event.resp);
      });
      return CoapSubscription(coapClient, observeClientRelation, complete);
    }

    final response = await coapClient.send(request);
    handleResponse(response);
    return CoapSubscription(coapClient, null, complete);
  }

  @override
  Future<void> start() async {
    // Do nothing
  }

  @override
  Future<void> stop() async {}

  Stream<Content> _discoverFromMulticast(
    coap.CoapClient client,
    Uri uri,
  ) async* {
    // TODO(JKRhb): This method currently does not work with block-wise transfer
    //               due to a bug in the CoAP library.
    final streamController = StreamController<Content>();
    final multicastResponseHandler = coap.CoapMulticastResponseHandler(
      (data) {
        streamController.add(_getContentFromResponse(data.resp));
      },
      onError: streamController.addError,
      onDone: () async {
        await streamController.close();
      },
    );

    final content = _sendRequest(
      uri,
      null,
      coap.CoapCode.get,
      form: null,
      accept: coap.CoapMediaType.applicationTdJson,
      multicastResponseHandler: multicastResponseHandler,
    );
    unawaited(content);
    yield* streamController.stream;
  }

  Stream<Content> _discoverFromUnicast(
    coap.CoapClient client,
    Uri uri,
  ) async* {
    yield await _sendRequest(
      uri,
      null,
      coap.CoapCode.get,
      form: null,
      accept: coap.CoapMediaType.applicationTdJson,
    );
  }

  @override
  Stream<Content> discoverDirectly(
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

  Content _handleCoreLinkFormatContent(Content content) {
    final actualContentFormat = content.type;
    const expectedContentFormat = 'application/link-format';

    if (actualContentFormat != expectedContentFormat) {
      throw DiscoveryException(
        'Got wrong format for '
        'CoRE Link Format Discovery (expected $expectedContentFormat, got '
        '$actualContentFormat).',
      );
    }

    return content;
  }

  @override
  Stream<Content> discoverWithCoreLinkFormat(Uri uri) async* {
    final discoveryUri = createCoreLinkFormatDiscoveryUri(uri);
    coap.CoapMulticastResponseHandler? multicastResponseHandler;
    final streamController = StreamController<Content>();

    if (uri.isMulticastAddress) {
      multicastResponseHandler = coap.CoapMulticastResponseHandler(
        (data) {
          final content = _getContentFromResponse(data.resp);
          final handledContent = _handleCoreLinkFormatContent(content);
          streamController.add(handledContent);
        },
        onError: streamController.addError,
        onDone: () async {
          await streamController.close();
        },
      );
    }

    final content = await _sendRequest(
      discoveryUri,
      null,
      coap.CoapCode.get,
      form: null,
      accept: coap.CoapMediaType.applicationLinkFormat,
      multicastResponseHandler: multicastResponseHandler,
    );

    if (uri.isMulticastAddress) {
      yield* streamController.stream;
    } else {
      yield _handleCoreLinkFormatContent(content);
    }
  }
}
