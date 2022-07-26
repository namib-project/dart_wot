// Copyright 2022 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'package:coap/coap.dart';
import 'package:curie/curie.dart';

import '../definitions/form.dart';

/// [PrefixMapping] for expanding CoAP Vocabulary terms from compact IRIs.
final coapPrefixMapping =
    PrefixMapping(defaultPrefixValue: 'http://www.example.org/coap-binding#');

/// Defines the available CoAP request methods.
enum CoapRequestMethod {
  /// Corresponds with the GET request method.
  get(CoapCode.get),

  /// Corresponds with the PUT request method.
  put(CoapCode.put),

  /// Corresponds with the POST request method.
  post(CoapCode.post),

  /// Corresponds with the DELETE request method.
  delete(CoapCode.delete),

  /// Corresponds with the FETCH request method.
  fetch(CoapCode.notSet),

  /// Corresponds with the PATCH request method.
  patch(CoapCode.notSet),

  /// Corresponds with the iPATCH request method.
  ipatch(CoapCode.get);

  /// Constructor
  const CoapRequestMethod(this.code);

  /// The numeric code of this [CoapRequestMethod].
  final int code;

  static CoapRequestMethod? _fromString(String stringValue) {
    switch (stringValue) {
      case 'POST':
        return CoapRequestMethod.post;
      case 'PUT':
        return CoapRequestMethod.put;
      case 'DELETE':
        return CoapRequestMethod.delete;
      case 'GET':
        return CoapRequestMethod.get;
      default:
        return null;
    }
  }

  /// Determines the [CoapRequestMethod] to use based on a given [form].
  static CoapRequestMethod? fromForm(Form form) {
    final curieString =
        coapPrefixMapping.expandCurie(Curie(reference: 'method'));
    final dynamic formDefinition = form.additionalFields[curieString];
    if (formDefinition is String) {
      final requestMethod = CoapRequestMethod._fromString(formDefinition);
      if (requestMethod != null) {
        return requestMethod;
      }
    }

    return null;
  }
}

/// Enumeration of available CoAP subprotocols.
enum CoapSubprotocol {
  /// Subprotocol for observing CoAP resources.
  observe,
}
