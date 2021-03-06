// Copyright 2021 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

/// Parses a [json] object and adds its contents to a [dataSchema].
void parseDataSchemaJson(DataSchema dataSchema, Map<String, dynamic> json) {
  // TODO(JKRhb): Parse more DataSchema values
  final Object? atType = json['@type'];
  if (atType is String) {
    dataSchema.atType = [atType];
  } else if (atType is List<String>) {
    dataSchema.atType = atType;
  }

  final Object? type = json['type'];
  if (type is String) {
    dataSchema.type = type;
  }

  final Object? readOnly = json['readOnly'];
  if (readOnly is bool) {
    dataSchema.readOnly = readOnly;
  }

  final Object? writeOnly = json['writeOnly'];
  if (writeOnly is bool) {
    dataSchema.writeOnly = writeOnly;
  }
}

/// Metadata that describes the data format used. It can be used for validation.
///
/// See W3C WoT Thing Description specification, [section 5.3.2.1][spec link].
///
/// [spec link]: https://w3c.github.io/wot-thing-description/#dataschema
class DataSchema {
  /// Creates a new [DataSchema] from a [json] object.
  DataSchema.fromJson(Map<String, dynamic> json) {
    parseDataSchemaJson(this, json);
    rawJson = json;
  }

  /// JSON-LD keyword (@type) to label the object with semantic tags (or types).
  List<String>? atType;

  /// The (default) title of this [DataSchema].
  String? title;

  /// A multi-language map of [titles].
  Map<String, String>? titles;

  /// The default [description] of this [DataSchema].
  String? description;

  /// A multi-language map of [descriptions].
  Map<String, String>? descriptions;

  /// A [constant] value.
  Object? constant;

  /// A default value if no actual value is set.
  Object? defaultValue;

  /// The [unit] of the value.
  String? unit;

  /// Allows the specification of multiple [DataSchema]s for validation.
  ///
  /// Data has to be valid against exactly one of these [DataSchema]s.
  List<DataSchema>? oneOf;

  /// Restricted set of values provided as a [List].
  List<Object>? enumeration;

  /// Indicates if a value is read only.
  bool? readOnly;

  /// Indicates if a value is write only.
  bool? writeOnly;

  /// Allows validation based on a format pattern.
  ///
  /// Examples are "date-time", "email", "uri", etc.
  String? format;

  /// JSON-based data type compatible with JSON Schema.
  ///
  /// This value can be one of boolean, integer, number, string, object, array,
  /// or null.
  String? type;

  /// The original JSON object that was parsed when creating this [DataSchema].
  Map<String, dynamic>? rawJson;
}
