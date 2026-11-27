import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peel/core/build_info.dart';

void main() {
  test('Settings shows the version in pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(line.split(' ').last.split('+').first, appVersion);
  });

  test('store builds leave the test lab out', () {
    expect(showTestLab, isFalse);
  });
}
