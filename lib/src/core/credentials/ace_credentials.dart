// Copyright 2022 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'credentials.dart';

/// [Credentials] used for the `OAuth2SecurityScheme`.
class ACECredentials extends Credentials {
  /// The optional secret for these [ACECredentials].
  String? secret;

  /// A JSON string representation of ACE credentials.
  ///
  /// Used to store obtained credentials from an authorization server.
  String? credentialsJson;

  /// Constructor.
  ACECredentials([this.secret]) : super("ace:ACESecurityScheme");
}
