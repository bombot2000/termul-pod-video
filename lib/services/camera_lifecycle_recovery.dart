/// Tracks camera restarts deferred while startVideoRecording is in flight.
///
/// A lifecycle pause/resume can happen before the camera plugin completes its
/// start operation. The controller must not be reused after that interruption.
class CameraLifecycleRecovery {
  bool _restartAfterRecordingStart = false;

  void deferRestartUntilRecordingStartCompletes() {
    _restartAfterRecordingStart = true;
  }

  bool consumeRestartAfterRecordingStart() {
    final shouldRestart = _restartAfterRecordingStart;
    _restartAfterRecordingStart = false;
    return shouldRestart;
  }
}
