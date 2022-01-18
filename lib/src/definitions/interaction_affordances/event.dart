// Copyright 2021 The NAMIB Project Developers
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// https://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or https://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.
//
// SPDX-License-Identifier: MIT OR Apache-2.0

import '../data_schema.dart';
import '../form.dart';
import 'interaction_affordance.dart';

/// Class representing an [Event] Affordance in a Thing Description.
class Event extends InteractionAffordance {
  /// Defines data that needs to be passed upon [subscription].
  DataSchema? subscription;

  /// Defines the [DataSchema] of the Event instance messages pushed by the
  /// Thing.
  DataSchema? data;

  /// Defines any data that needs to be passed to cancel a subscription.
  DataSchema? cancellation;

  /// Creates a new [Event] from a [List] of [forms].
  Event(List<Form> forms) : super(forms);

  /// Creates a new [Event] from a [json] object.
  Event.fromJson(Map<String, dynamic> json) : super([]) {
    parseAffordanceFields(json);
    _parseEventFields(json);
  }

  void _parseEventFields(Map<String, dynamic> json) {
    subscription = DataSchema.fromJson(json);
    data = DataSchema.fromJson(json);
    cancellation = DataSchema.fromJson(json);
  }
}
