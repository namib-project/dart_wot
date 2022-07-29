// Copyright 2022 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'helper_functions.dart';
import 'security_scheme.dart';

/// Experimental ACE Security Scheme.
// TODO(JKRhb): Check whether an audience field is needed or if this implied by
// the base field/form href.
class ACESecurityScheme extends SecurityScheme {
  /// Constructor.
  ACESecurityScheme({
    String? description,
    this.as,
    this.audience,
    this.scopes,
    this.cnonce,
    Map<String, String>? descriptions,
  }) {
    this.description = description;
    this.descriptions.addAll(descriptions ?? {});
  }

  /// Creates a [ACESecurityScheme] from a [json] object.
  ACESecurityScheme.fromJson(Map<String, dynamic> json) {
    _parsedJsonFields.addAll(parseSecurityJson(this, json));

    final dynamic jsonAs = _getJsonValue(json, 'ace:as');
    if (jsonAs is String) {
      as = jsonAs;
      _parsedJsonFields.add('ace:as');
    }

    final dynamic jsonCnonce = _getJsonValue(json, 'ace:cnonce');
    if (jsonCnonce is bool) {
      cnonce = jsonCnonce;
      _parsedJsonFields.add('ace:cnonce');
    }

    final dynamic jsonAudience = _getJsonValue(json, 'ace:audience');
    if (jsonAudience is String) {
      audience = jsonAudience;
      _parsedJsonFields.add('ace:audience');
    }

    final dynamic jsonScopes = _getJsonValue(json, 'ace:scopes');
    if (jsonScopes is String) {
      scopes = [jsonScopes];
      _parsedJsonFields.add('ace:scopes');
    } else if (jsonScopes is List<dynamic>) {
      scopes = jsonScopes.whereType<String>().toList();
      _parsedJsonFields.add('ace:scopes');
    }

    parseAdditionalFields(additionalFields, json, _parsedJsonFields);
  }

  @override
  String get scheme => 'ace:ACESecurityScheme';

  /// URI of the authorization server.
  String? as;

  /// The intended audience for this [ACESecurityScheme].
  String? audience;

  /// Set of authorization scope identifiers provided as an array.
  ///
  /// These are provided in tokens returned by an authorization server and
  /// associated with forms in order to identify what resources a client may
  /// access and how. The values associated with a form should be chosen from
  /// those defined in an [ACESecurityScheme] active on that form.
  List<String>? scopes;

  /// Indicates whether a [cnonce] is required by the Resource Server.
  bool? cnonce;

  final List<String> _parsedJsonFields = [];

  dynamic _getJsonValue(Map<String, dynamic> json, String key) {
    _parsedJsonFields.add(key);
    return json[key];
  }
}
