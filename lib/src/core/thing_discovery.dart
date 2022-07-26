// Copyright 2021 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:async';

import 'package:coap/coap.dart';

import '../../core.dart';
import '../../scripting_api.dart' as scripting_api;
import '../definitions/thing_description.dart';
import 'content.dart';

/// Custom [Exception] that is thrown when the discovery process fails.
class DiscoveryException implements Exception {
  /// Creates a new [DiscoveryException] with the specified error [message].
  DiscoveryException(this.message);

  /// The error message of this exception.
  final String message;

  @override
  String toString() {
    return 'DiscoveryException: $message';
  }
}

/// Implemention of the [scripting_api.ThingDiscovery] interface.
class ThingDiscovery extends Stream<ThingDescription>
    implements scripting_api.ThingDiscovery {
  /// Creates a new [ThingDiscovery] object with a given [thingFilter].
  ThingDiscovery(this.thingFilter, this._servient)
      : _client = _servient.clientFor(thingFilter.url.scheme) {
    _stream = _start();
  }

  final Servient _servient;

  bool _active = true;

  @override
  bool get active => _active;

  @override
  final scripting_api.ThingFilter thingFilter;

  late final Stream<ThingDescription> _stream;

  final ProtocolClient _client;

  Stream<ThingDescription> _start() async* {
    final discoveryMethod = thingFilter.method;

    switch (discoveryMethod) {
      case scripting_api.DiscoveryMethod.direct:
        yield* _discoverDirectly(thingFilter.url);
        break;
      case scripting_api.DiscoveryMethod.coreLinkFormat:
        yield* _discoverWithCoreLinkFormat(thingFilter.url);
        break;
      default:
        throw UnimplementedError();
    }
  }

  @override
  Future<void> stop() async {
    await _client.stop();
    _active = false;
  }

  Object? _decodeThingDescription(Content content) async {
    try {
      return await _servient.contentSerdes.contentToValue(content, null);
    } on Exception {
      return null;
    }
  }

  Stream<ThingDescription> _discoverDirectly(Uri uri) async* {
    yield* _client
        .discoverDirectly(uri, disableMulticast: true)
        // TODO: Should errors be passed to the stream here?
        .asyncMap(_decodeThingDescription)
        .where((event) => event is Map<String, dynamic>)
        .cast<Map<String, dynamic>>()
        .map(ThingDescription.fromJson);
  }

  Stream<ThingDescription> _discoverWithCoreLinkFormat(Uri uri) async* {
    final Set<Uri> discoveredUris = {};
    await for (final coreWebLink in _client.discoverWithCoreLinkFormat(uri)) {
      final value =
          await _servient.contentSerdes.contentToValue(coreWebLink, null);

      if (value is! CoapWebLink ||
          !(value.attributes.getContentTypes()?.contains('wot.thing') ??
              false)) {
        continue;
      }

      Uri? parsedUri = Uri.tryParse(value.uri);

      if (parsedUri == null) {
        // TODO: Should an error be passed on here instead?
        continue;
      }

      if (!parsedUri.isAbsolute) {
        parsedUri = parsedUri.replace(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.port,
        );
      }
      if (discoveredUris.contains(parsedUri)) {
        continue;
      }
      discoveredUris.add(parsedUri);
      yield* _discoverDirectly(parsedUri);
    }
  }

  @override
  StreamSubscription<ThingDescription> listen(
    void Function(ThingDescription event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    Future<void> cleanUpAndDone() async {
      await stop();
      if (onDone != null) {
        onDone();
      }
    }

    return _stream.listen(
      onData,
      onError: onError,
      onDone: cleanUpAndDone,
      cancelOnError: cancelOnError,
    );
  }
}
