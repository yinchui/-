import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/core/sync/sync_service.dart';

void main() {
  test('sync result reports pushed and failed counts', () {
    const result = SyncResult(pushed: 2, failed: 1);

    expect(result.hasFailures, isTrue);
    expect(result.summary, '2 pushed, 1 failed');
  });
}
