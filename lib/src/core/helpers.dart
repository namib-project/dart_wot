// Copyright 2021 The NAMIB Project Developers
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// https://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or https://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import '../../definitions.dart';
import '../../scripting_api.dart';
import 'content_serdes.dart';
import 'servient.dart';

/// Custom [Exception] that is thrown when the fetching of a [ThingDescription]
/// fails.
class ThingDescriptionFetchException implements Exception {
  /// The error message of this exception.
  final String message;

  /// Creates a new [ThingDescriptionFetchException].
  ///
  /// The resulting [Exception] will display the passed [uri] in its error
  ///  [message].
  ThingDescriptionFetchException(String uri)
      : message = "Fetching Thing Description from $uri failed.";
}

/// Fetches a Thing Description from a given [uri].
Future<ThingDescription> fetchThingDescription(
    String uri, Servient servient, InteractionOptions? options) async {
  final parsedUri = Uri.parse(uri);
  final client = servient.clientFor(parsedUri.scheme);
  final fetchForm = Form(uri, "application/td+json");

  final content = await client.readResource(fetchForm);
  await client.stop();

  final contentSerdes = ContentSerdes();

  final value = await contentSerdes.contentToValue(content, null);
  if (value is Map<String, dynamic>) {
    return ThingDescription.fromJson(value);
  }

  throw ThingDescriptionFetchException(uri);
}