// Copyright 2022 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'package:dcaf/dcaf.dart';

import '../definitions/form.dart';
import 'credentials/ace_credentials.dart';
import 'credentials/apikey_credentials.dart';
import 'credentials/basic_credentials.dart';
import 'credentials/bearer_credentials.dart';
import 'credentials/credentials.dart';
import 'credentials/digest_credentials.dart';
import 'credentials/oauth2_credentials.dart';
import 'credentials/psk_credentials.dart';

/// Function signature for a synchronous callback for providing client
/// [PskCredentials] at runtime.
///
/// If no credentials can be retrieved, a `null` value should be returned (which
/// will lead to the throw of an exception in the respective binding). This
/// behavior might change in future versions of `dart_wot`.
///
/// Users can retrieve or generate credentials based on the endpoint's [uri] or
/// an [identityHint] that might be given by the server. In the case of
/// interactions, the corresponding [Form] is also provided.
typedef ClientPskCallback = PskCredentials? Function(
  Uri uri,
  Form? form,
  String? identityHint,
);

/// Function signature for a synchronous callback for providing client
/// [ACECredentials] at runtime, based on an optional [creationHint]
/// given by the Resource Server.
typedef AceSecurityCallback = Future<ACECredentials?> Function(
  Uri uri,
  Form? form,
  AuthServerRequestCreationHint? creationHint,
);

/// Function signature for a synchronous callback for providing client
/// [Credentials] at runtime.
///
/// Users can retrieve or generate credentials based on the endpoint's [uri].
/// In the case of interactions, the corresponding [Form] is also retrieved.
///
/// If no credentials can be retrieved, a `null` value should be returned (which
/// will lead to the throw of an exception in the respective binding). This
/// behavior might change in future versions of `dart_wot`.
///
/// This callback signature is currently only used for [PskCredentials] due to
/// implementation limititations, which do not allow for asynchronous callbacks.
typedef AsyncClientSecurityCallback<T extends Credentials> = Future<T?>
    Function(Uri uri, Form? form);

/// Class for providing callbacks for client [Credentials] at runtime.
///
/// Accepts either an [AsyncClientSecurityCallback] for each supported type of
/// [Credentials] or – in the case of [PskCredentials] – a (synchronous)
/// [ClientPskCallback].
///
/// Note that not all security schemes are implemented yet, therefore not every
/// callback might actually be usable in practice.
class ClientSecurityProvider {
  /// Constructor.
  ClientSecurityProvider({
    this.pskCredentialsCallback,
    this.basicCredentialsCallback,
    this.bearerCredentialsCallback,
    this.digestCredentialsCallback,
    this.apikeyCredentialsCallback,
    this.oauth2CredentialsCallback,
    this.aceCredentialsCallback,
  });

  /// Asychronous callback for [ApiKeyCredentials].
  final AsyncClientSecurityCallback<ApiKeyCredentials>?
      apikeyCredentialsCallback;

  /// Sychronous callback for [PskCredentials].
  final ClientPskCallback? pskCredentialsCallback;

  /// Asychronous callback for [BasicCredentials].
  final AsyncClientSecurityCallback<BasicCredentials>? basicCredentialsCallback;

  /// Asychronous callback for [DigestCredentials].
  final AsyncClientSecurityCallback<DigestCredentials>?
      digestCredentialsCallback;

  /// Asychronous callback for [BearerCredentials].
  final AsyncClientSecurityCallback<BearerCredentials>?
      bearerCredentialsCallback;

  // TODO(JKRhb): Is this callback actually needed?
  /// Asychronous callback for [OAuth2Credentials].
  final AsyncClientSecurityCallback<OAuth2Credentials>?
      oauth2CredentialsCallback;

  /// Asychronous callback for [ACECredentials].
  final AceSecurityCallback? aceCredentialsCallback;
}

/// Function signature for a synchronous callback retrieving server
/// [Credentials] by Thing [id] at runtime.
///
/// The returned hash map should map the keys of the individual Security
/// Definitions to concrete [Credentials].
///
/// Note: The exact API for retrieving server [Credentials] is still Work in
/// Progress.
typedef ServerSecurityCallback = Map<String, Credentials> Function(String id);
