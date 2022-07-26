// Copyright 2021 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:typed_data';

import 'package:http_parser/http_parser.dart';
import 'package:json_schema3/json_schema3.dart';

import '../definitions/data_schema.dart';
import 'codecs/cbor_codec.dart';
import 'codecs/content_codec.dart';
import 'codecs/json_codec.dart';
import 'codecs/link_format_codec.dart';
import 'content.dart';

// TODO(JKRhb): Check if these constants are actually necessary
/// Constant for the media type `application/json`.
const jsonContentType = 'application/json';

/// Constant for the media type `application/td+json`.
const tdContentType = 'application/td+json';

/// Constant for the media type `application/ld+json`.
const jsonLdContentType = 'application/ld+json';

/// Defines `application/json` as the default content type.
const defaultContentType = jsonContentType;

// TODO: Replace with enum.
const _linkFormatKey = 'LinkFormat';

/// Custom [Exception] that is thrown when Serialization or Deserialization
/// fails.
class ContentSerdesException implements Exception {
  /// Constructor.
  ContentSerdesException(this.message);

  /// The error message of this [ContentSerdesException].
  String? message;

  @override
  String toString() {
    return 'ContentSerdesException: $message';
  }
}

/// Class providing serializing and deserializing capabilities.
///
// TODO(JKRhb): Decide if a class-based approach is the right way to go.
// TODO(JKRhb): Getters and setters might have to be revisited
class ContentSerdes {
  /// Creates a new [ContentSerdes] object which supports JSON and CBOR based
  /// media types by default.
  ContentSerdes() {
    _addDefaultCodecs();
  }

  final Map<String, ContentCodec> _supportedCodecs = {};

  final Map<String, String> _supportedContentTypes = {};

  /// Codecs offered by a new ExposedThing.
  Set<String> offeredContentTypes = {};

  void _addDefaultCodecs() {
    _supportedCodecs['JSON'] = JsonCodec();
    _supportedCodecs['CBOR'] = CborCodec();
    _supportedCodecs[_linkFormatKey] = LinkFormatCodec();

    // TODO(JKRhb): Add codecs for text-based media types
    // TODO(JKRhb): Add codecs for XML based media types
    // TODO(JKRhb): Add codecs for Base64 media types
    // TODO(JKRhb): Add codec for OctetStream media type

    _addDefaultJsonContentTypes();
    _addDefaultCborContentTypes();
    addContentTypeSupport('application/link-format', _linkFormatKey);
  }

  /// Adds support for a new [contentType] that has to use a [Codec] that has
  /// previously been registered by using a [codecName] as key.
  ///
  /// If the [contentType] is being [offered], then exposed Things will provide
  /// additional Forms in their Thing Description.
  void addContentTypeSupport(
    String contentType,
    String codecName, {
    bool offered = false,
  }) {
    if (!_supportedCodecs.containsKey(codecName)) {
      throw UnsupportedError('$codecName has no registered ContentCodec.');
    }

    _supportedContentTypes[contentType] = codecName;

    if (offered) {
      offeredContentTypes.add(contentType);
    }
  }

  /// Adds the JSON based Content-Types that are supported by default.
  void _addDefaultJsonContentTypes() {
    addContentTypeSupport(jsonContentType, 'JSON', offered: true);

    const jsonContentTypes = [
      'application/json-patch+json',
      'application/merge-patch+json',
      'application/senml+json',
      'application/sensml+json',
      'application/coap-group+json',
      'application/senml-etch+json',
      tdContentType,
      jsonLdContentType,
    ];

    for (final contentType in jsonContentTypes) {
      addContentTypeSupport(contentType, 'JSON');
    }
  }

  /// Adds the CBOR based Content-Types that are supported by default.
  void _addDefaultCborContentTypes() {
    addContentTypeSupport('application/cbor', 'CBOR', offered: true);

    const cborContentTypes = [
      'application/ace+cbor',
      'application/senml+cbor',
      'application/sensml+cbor',
      'application/dots+cbor',
      'application/senml-etch+cbor',
    ];

    for (final contentType in cborContentTypes) {
      addContentTypeSupport(contentType, 'CBOR');
    }
  }

  /// Registers a new [contentCodec] to a given [codecName].
  void addCodec(ContentCodec contentCodec, String codecName) {
    _supportedCodecs[codecName] = contentCodec;
  }

  /// Removes a [ContentCodec] with the given [codecName] from the registry.
  ///
  /// Returns the [ContentCodec] in question if removal was successful and null
  /// otherwise.
  ContentCodec? removeCodec(String codecName) {
    final contentCodec = _supportedCodecs.remove(codecName);
    if (contentCodec != null) {
      _supportedContentTypes.removeWhere((key, value) => value == codecName);
    }
    return contentCodec;
  }

  /// Checks if a given [mediaType] is supported.
  bool isSupportedMediaType(String mediaType) {
    final String? codecName = _supportedContentTypes[mediaType];
    return _supportedCodecs.containsKey(codecName);
  }

  /// Returns a [List] of supported media types.
  List<String> get supportedMediaTypes =>
      _supportedContentTypes.keys.toList(growable: false);

  /// Returns a [List] of media types which are offered when a Thing is exposed.
  List<String> get offeredMediaTypes =>
      offeredContentTypes.toList(growable: false);

  ContentCodec? _getCodecFromMediaType(String mediaType) {
    final codecName = _supportedContentTypes[mediaType];
    return _supportedCodecs[codecName];
  }

  void _validateValue(Object? value, DataSchema? dataSchema) {
    final dataSchemaJson = dataSchema?.rawJson;
    if (dataSchemaJson == null) {
      return;
    }
    final schema =
        JsonSchema.create(dataSchemaJson, schemaVersion: SchemaVersion.draft7);
    if (!schema.validate(value).isValid) {
      throw ContentSerdesException('JSON Schema validation failed.');
    }
  }

  /// Converts an [Object] to a byte representation based on its [contentType].
  ///
  /// A [dataSchema] can be passed for validating the input [value] before the
  /// conversion.
  Content valueToContent(
    Object? value,
    DataSchema? dataSchema,
    String? contentType,
  ) {
    _validateValue(value, dataSchema);

    final resolvedContentType = contentType ?? defaultContentType;

    final parsedMediaType = MediaType.parse(resolvedContentType);
    final mimeType = parsedMediaType.mimeType;
    final parameters = parsedMediaType.parameters;

    ByteBuffer bytes;
    final codec = _getCodecFromMediaType(mimeType);
    if (codec != null) {
      bytes = codec.valueToBytes(value, dataSchema, parameters);
    } else {
      // Media Type is unsupported. Convert the String representation to bytes
      // instead.
      // TODO(JKRhb): Could be moved to a dedicated Value class method.
      bytes = utf8.encoder.convert(value.toString()).buffer;
    }

    // TODO(JKRhb): Make sure this list does not need to be growable
    final byteList = bytes.asUint8List().toList(growable: false);
    return Content(resolvedContentType, Stream.value(byteList));
  }

  /// Converts a [Content] object to a typed [Object].
  ///
  /// A [dataSchema] can be passed for validating the result. If the media type
  /// specified in the [content] is not supported, its body is converted to an
  /// UTF-8 string.
  Future<Object?> contentToValue(
    Content content,
    DataSchema? dataSchema,
  ) async {
    final parsedMediaType = MediaType.parse(content.type);
    final mimeType = parsedMediaType.mimeType;
    final parameters = parsedMediaType.parameters;

    final bytes = await content.byteBuffer;

    // TODO: Should null be returned in this case?
    if (bytes.lengthInBytes == 0) {
      return null;
    }

    final codec = _getCodecFromMediaType(mimeType);
    if (codec != null) {
      final value = codec.bytesToValue(bytes, dataSchema, parameters);
      _validateValue(value, dataSchema);
      return value;
    } else {
      // TODO(JKRhb): Should unsupported data be returned as a String?
      return utf8.decode(bytes.asUint8List());
    }
  }
}
