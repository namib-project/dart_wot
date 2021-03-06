// Copyright 2022 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'helper_functions.dart';
import 'security_scheme.dart';

/// An automatic security configuration identified by the
/// vocabulary term `auto`.
class AutoSecurityScheme extends SecurityScheme {
  /// Creates an [AutoSecurityScheme] from a [json] object.
  AutoSecurityScheme.fromJson(Map<String, dynamic> json) {
    _parsedJsonFields.addAll(parseSecurityJson(this, json));
    parseAdditionalFields(additionalFields, json, _parsedJsonFields);
  }

  @override
  String get scheme => 'auto';

  final List<String> _parsedJsonFields = [];
}
