// Copyright 2022 The NAMIB Project Developers. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
//
// SPDX-License-Identifier: BSD-3-Clause

import 'package:dart_wot/src/core/content.dart';
import 'package:dart_wot/src/core/content_serdes.dart';
import 'package:dart_wot/src/definitions/data_schema.dart';
import 'package:test/test.dart';

Content _getTestContent(String input) {
  return Content('application/json', Stream<List<int>>.value(input.codeUnits));
}

void main() {
  group('Content Serdes Tests', () {
    setUp(() {
      // Additional setup goes here.
    });
  });

  test('Content Validation', () async {
    final contentSerdes = ContentSerdes();

    final testContent1 = _getTestContent('42');
    final successfulSchema =
        DataSchema.fromJson(<String, dynamic>{'type': 'number'});

    expect(
      await contentSerdes.contentToValue(testContent1, successfulSchema),
      42,
    );

    final testContent2 = _getTestContent('42');
    final failingSchema =
        DataSchema.fromJson(<String, dynamic>{'type': 'string'});

    expect(
      contentSerdes.contentToValue(testContent2, failingSchema),
      throwsA(const TypeMatcher<ContentSerdesException>()),
    );

    expect(
      () => contentSerdes.valueToContent(42, failingSchema, 'application/json'),
      throwsA(const TypeMatcher<ContentSerdesException>()),
    );
  });
}
