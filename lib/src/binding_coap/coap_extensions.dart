import 'dart:io';

import 'package:coap/coap.dart';

import '../definitions/form.dart';
import '../definitions/operation_type.dart';
import 'coap_definitions.dart';

const _validBlockwiseValues = [16, 32, 64, 128, 256, 512, 1024];

/// Extension which makes it easier to handle [Uri]s containing
/// [InternetAddress]es.
extension InternetAddressMethods on Uri {
  /// Checks whether the host of this [Uri] is a multicast [InternetAddress].
  bool get isMulticastAddress {
    return InternetAddress.tryParse(host)?.isMulticast ?? false;
  }
}

/// CoAP-specific extensions for the [Form] class.
extension CoapFormExtension on Form {
  /// Get the [CoapSubprotocol] for this [Form], if one is set.
  CoapSubprotocol? get coapSubprotocol {
    if (subprotocol == coapPrefixMapping.expandCurieString('observe')) {
      return CoapSubprotocol.observe;
    }

    return null;
  }

  CoapMediaType _determineContentFormat(String contentType, String? encoding) {
    return CoapMediaType.parse(contentType, encoding) ??
        CoapMediaType.applicationJson;
  }

  /// The Content-Format for CoAP request and response payloads.
  CoapMediaType get format {
    return _determineContentFormat(contentType, contentCoding);
  }

  /// The Content-Format for the Accept option CoAP request and response
  /// payloads.
  CoapMediaType get accept {
    // TODO: The algorithm for accept needs to be adjusted
    return _determineContentFormat(contentType, contentCoding);
  }

  int? _determineBlockSize(String fieldName) {
    const _blockwiseVocabularyName = 'blockwise';
    final curieString =
        coapPrefixMapping.expandCurieString(_blockwiseVocabularyName);
    final dynamic formDefinition = additionalFields[curieString];

    if (formDefinition is! Map<String, dynamic>) {
      return null;
    }

    final blockwiseParameterName =
        coapPrefixMapping.expandCurieString(fieldName);
    final dynamic value = formDefinition[blockwiseParameterName];

    if (value is int && !_validBlockwiseValues.contains(value)) {
      return value;
    }

    return null;
  }

  /// Indicates the Block2 size preferred by a server.
  int? get block2Size => _determineBlockSize('block2SZX');

  /// Indicates the Block1 size preferred by a server.
  int? get block1Size => _determineBlockSize('block1SZX');
}

/// Extension for determining the corresponding [CoapRequestMethod] and
/// [CoapSubprotocol] for an [OperationType].
extension OperationTypeExtension on OperationType {
  /// Determines the [CoapRequestMethod] for this [OperationType].
  CoapRequestMethod get requestMethod {
    switch (this) {
      case OperationType.readproperty:
      case OperationType.readmultipleproperties:
      case OperationType.readallproperties:
        return CoapRequestMethod.get;
      case OperationType.writeproperty:
      case OperationType.writemultipleproperties:
        return CoapRequestMethod.put;
      case OperationType.invokeaction:
        return CoapRequestMethod.post;
      case OperationType.observeproperty:
      case OperationType.unobserveproperty:
        return CoapRequestMethod.get;
      case OperationType.subscribeevent:
      case OperationType.unsubscribeevent:
        return CoapRequestMethod.get;
    }
  }

  /// Determines the [CoapSubprotocol] (if any) for this [OperationType].
  ///
  /// The only supported subprotocol at the moment is `observe`.
  CoapSubprotocol? get subprotocol {
    if ([
      OperationType.subscribeevent,
      OperationType.unsubscribeevent,
      OperationType.observeproperty,
      OperationType.unobserveproperty
    ].contains(this)) {
      return CoapSubprotocol.observe;
    }

    return null;
  }
}
