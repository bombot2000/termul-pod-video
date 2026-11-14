import 'package:shared_preferences/shared_preferences.dart';

/// Layouts are deliberately structural variants, not color-only themes.
enum PodWatermarkLayout {
  classic,
  compact,
  header;

  String get label => switch (this) {
        PodWatermarkLayout.classic => 'Classic — panel bawah penuh',
        PodWatermarkLayout.compact => 'Compact — kartu ringkas',
        PodWatermarkLayout.header => 'Header — identitas di bagian atas',
      };

  String get description => switch (this) {
        PodWatermarkLayout.classic =>
          'Informasi waktu dan lokasi tersusun dalam panel lebar di bawah foto/video.',
        PodWatermarkLayout.compact =>
          'Panel kecil di sudut bawah dengan informasi inti yang lebih padat.',
        PodWatermarkLayout.header =>
          'Judul dokumentasi dan waktu berada di bagian atas, detail lokasi di bawahnya.',
      };
}

class PodWatermarkSettingsService {
  PodWatermarkSettingsService({Future<SharedPreferences> Function()? preferences})
      : _preferences = preferences ?? SharedPreferences.getInstance;

  static const storageKey = 'termul_pod_watermark_layout_v1';
  final Future<SharedPreferences> Function() _preferences;

  Future<PodWatermarkLayout> loadLayout() async {
    final preferences = await _preferences();
    final stored = preferences.getString(storageKey);
    return PodWatermarkLayout.values.firstWhere(
      (layout) => layout.name == stored,
      orElse: () => PodWatermarkLayout.classic,
    );
  }

  Future<void> saveLayout(PodWatermarkLayout layout) async {
    final preferences = await _preferences();
    await preferences.setString(storageKey, layout.name);
  }
}
