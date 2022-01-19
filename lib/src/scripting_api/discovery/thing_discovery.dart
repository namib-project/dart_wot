// Copyright 2021 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'thing_filter.dart';

/// Interface
abstract class ThingDiscovery {
  /// The [thingFilter] that is applied during the discovery process.
  ThingFilter? get thingFilter;

  /// Indicates if this [ThingDiscovery] object is active.
  bool get active;

  /// Indicates if this [ThingDiscovery] object is done.
  bool get done;

  /// The [Exception] that is thrown when an error occurs.
  Exception? get error;

  /// Starts the discovery process.
  void start();

  /// Stops the discovery process.
  void stop();
}
