import 'package:flutter_test/flutter_test.dart';
import 'package:termul_pod_video/services/camera_lifecycle_recovery.dart';

void main() {
  group('CameraLifecycleRecovery', () {
    test('does not request restart without an interrupted start', () {
      final recovery = CameraLifecycleRecovery();

      expect(recovery.consumeRestartAfterRecordingStart(), isFalse);
      expect(recovery.consumeRestartAfterRecordingStart(), isFalse);
    });

    test('defers restart until recording start completes', () {
      final recovery = CameraLifecycleRecovery();

      recovery.deferRestartUntilRecordingStartCompletes();

      expect(recovery.consumeRestartAfterRecordingStart(), isTrue);
      expect(recovery.consumeRestartAfterRecordingStart(), isFalse);
    });

    test('coalesces pause and resume during the same start operation', () {
      final recovery = CameraLifecycleRecovery();

      recovery.deferRestartUntilRecordingStartCompletes();
      recovery.deferRestartUntilRecordingStartCompletes();

      expect(recovery.consumeRestartAfterRecordingStart(), isTrue);
      expect(recovery.consumeRestartAfterRecordingStart(), isFalse);
    });
  });
}
