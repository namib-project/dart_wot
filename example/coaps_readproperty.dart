// Copyright 2022 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:dart_wot/dart_wot.dart';

/// Matches [PskCredentials] by hostname and URI scheme.
final Map<Uri, PskCredentials> _pskCredentialsStore = {
  Uri(host: 'californium.eclipseprojects.io', scheme: 'coaps'): PskCredentials(
    identity: Uint8List.fromList('Client_identity'.codeUnits),
    preSharedKey: Uint8List.fromList('secretPSK'.codeUnits),
  )
};

PskCredentials? _pskCredentialsCallback(
  Uri uri,
  Form? form,
  Uint8List? identityHint,
) {
  final key = Uri(scheme: uri.scheme, host: uri.host);

  return _pskCredentialsStore[key];
}

Future<void> main(List<String> args) async {
  final CoapClientFactory coapClientFactory =
      CoapClientFactory(CoapConfig(useTinyDtls: true));
  final securityProvider =
      ClientSecurityProvider(pskCredentialsCallback: _pskCredentialsCallback);
  final servient = Servient(clientSecurityProvider: securityProvider)
    ..addClientFactory(coapClientFactory);

  final wot = await servient.start();

  const thingDescriptionJson = '''
  {
    "@context": "http://www.w3.org/ns/td",
    "title": "Test Thing",
    "base": "coaps://californium.eclipseprojects.io",
    "security": ["psk_sc"],
    "securityDefinitions": {
      "psk_sc": {
        "scheme": "psk",
        "identity": "Client_identity"
      }
    },
    "properties": {
      "status": {
        "forms": [
          {
            "href": "/test"
          }
        ]
      }
    }
  }
  ''';

  final thingDescription = ThingDescription(thingDescriptionJson);
  final consumedThing = await wot.consume(thingDescription);
  final status = await consumedThing.readProperty('status');
  final value = await status.value();
  print(value);
}
