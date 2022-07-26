// Copyright 2022 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'dart:convert';
import 'dart:typed_data';

import 'package:coap/coap.dart';

import '../../definitions/data_schema.dart';
import 'content_codec.dart';

/// A [ContentCodec] that encodes and decodes the CoRE Link Format ([RFC 6690]).
///
/// [RFC 6690]: https://datatracker.ietf.org/doc/html/rfc6690
class LinkFormatCodec extends ContentCodec {
  @override
  ByteBuffer valueToBytes(
    Object? value,
    DataSchema? dataSchema,
    Map<String, String>? parameters,
  ) {
    if (value is CoapIResource) {
      return Uint8List.fromList(CoapLinkFormat.serialize(value).codeUnits)
          .buffer;
    }

    // TODO: Use other exception instead?
    throw FormatException('Error deserializing CoRE Link Format', value);
  }

  @override
  Object? bytesToValue(
    ByteBuffer bytes,
    DataSchema? dataSchema,
    Map<String, String>? parameters,
  ) {
    final string = utf8.decode(bytes.asUint8List().toList(growable: false));
    return CoapLinkFormat.parse(string);
  }
}
