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
  get,

  /// Corresponds with the PUT request method.
  put,

  /// Corresponds with the POST request method.
  post,

  /// Corresponds with the DELETE request method.
  delete,

  /// Corresponds with the FETCH request method.
  fetch,

  /// Corresponds with the PATCH request method.
  patch,

  /// Corresponds with the iPATCH request method.
  ipatch;

  /// Generate a new [CoapRequest] based on this [CoapRequestMethod].
  CoapRequest generateRequest() {
    final int code;
    switch (this) {
      case CoapRequestMethod.get:
        code = CoapCode.get;
        break;
      case CoapRequestMethod.post:
        code = CoapCode.post;
        break;
      case CoapRequestMethod.put:
        code = CoapCode.put;
        break;
      case CoapRequestMethod.delete:
        code = CoapCode.delete;
        break;
      default:
        throw UnimplementedError();
    }
    final request = CoapRequest(code);
    return request;
  }

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
