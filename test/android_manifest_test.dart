import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('android manifest declares internet permission for cloud sync', () async {
    final manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();

    expect(
      manifest,
      contains('android.permission.INTERNET'),
    );
  });
}
