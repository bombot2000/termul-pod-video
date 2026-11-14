import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:termul_pod_video/services/pod_watermark_settings_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to classic for new installs', () async {
    expect(
      await PodWatermarkSettingsService().loadLayout(),
      PodWatermarkLayout.classic,
    );
  });

  test('persists selected layout across service instances', () async {
    final first = PodWatermarkSettingsService();
    await first.saveLayout(PodWatermarkLayout.header);

    expect(
      await PodWatermarkSettingsService().loadLayout(),
      PodWatermarkLayout.header,
    );
  });

  test('falls back safely when stored value is unknown', () async {
    SharedPreferences.setMockInitialValues({
      PodWatermarkSettingsService.storageKey: 'future_layout',
    });

    expect(
      await PodWatermarkSettingsService().loadLayout(),
      PodWatermarkLayout.classic,
    );
  });
}
