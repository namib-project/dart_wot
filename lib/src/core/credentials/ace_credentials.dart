// Copyright 2022 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'package:dcaf/dcaf.dart';

import 'credentials.dart';

/// [Credentials] used for the `OAuth2SecurityScheme`.
class ACECredentials extends Credentials {
  /// Constructor.
  ACECredentials(this.accessToken) : super('ace:ACESecurityScheme');

  /// The access token obtained from an Authorization Server.
  // TODO: Replace with a custom accessToken class
  final AccessTokenResponse accessToken;
}
