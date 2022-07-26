// Copyright 2021 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import '../../definitions/form.dart';
import '../../scripting_api/subscription.dart';
import '../content.dart';

/// Base class for a Protocol Client.
abstract class ProtocolClient {
  /// Starts this [ProtocolClient].
  Future<void> start();

  /// Stops this [ProtocolClient].
  Future<void> stop();

  /// Discovers one or more Thing Descriptions from a [uri], returning a
  /// [Stream] of [Content].
  ///
  /// Allows the caller to explicitly [disableMulticast], overriding the
  /// multicast settings in the config of the underlying binding implementation.
  Stream<Content> discoverDirectly(
    Uri uri, {
    bool disableMulticast = false,
  });

  /// Discovers one or more Thing Descriptions from a [uri] using the CoRE Link
  /// Format and Web Linking (see [RFC 6690]), returning a [Stream] of
  /// [Content].
  ///
  /// The [uri] must point to either the resource lookup interface of a CoRE
  /// Resource Directory (see [RFC 9176]) or to a CoRE Resource Discovery
  /// resource like `/.well-known/core`.
  ///
  /// Certain protocols (like CoAP) might also use multicast for this discovery
  /// method if the underlying binding implementation supports it and if it is
  /// activated in the config.
  ///
  /// [RFC 9176]: https://datatracker.ietf.org/doc/html/rfc9176
  /// [RFC 6690]: https://datatracker.ietf.org/doc/html/rfc6690
  Stream<Content> discoverWithCoreLinkFormat(Uri uri);

  /// Requests the client to perform a `readproperty` operation on a [form].
  Future<Content> readResource(Form form);

  /// Requests the client to perform a `writeproperty` operation on a [form]
  /// using the given [content].
  Future<void> writeResource(Form form, Content content);

  /// Requests the client to perform an `invokeaction` operation on a [form]
  /// using the given [content].
  Future<Content> invokeResource(Form form, Content content);

  /// Requests the client to perform a `subscribeproperty` operation on a
  /// [form].
  Future<Subscription> subscribeResource(
    Form form, {
    required void Function(Content content) next,
    void Function(Exception error)? error,
    required void Function() complete,
  });
}
