import 'dart:convert';

import 'package:material_ui/material_ui.dart' show ListView;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:termul_pod_video/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows POD dashboard and navigation', (tester) async {
    await tester.pumpWidget(const TermulPodApp());

    expect(find.text('TERMUL POD'), findsOneWidget);
    expect(find.text('Dokumentasikan\nsetiap pengiriman.'), findsOneWidget);
    expect(find.text('Mulai dokumentasi'), findsOneWidget);
    expect(find.text('Foto POD'), findsOneWidget);
    expect(find.text('Video POD'), findsOneWidget);

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada dokumentasi'), findsOneWidget);

    await tester.tap(find.text('Pengaturan'));
    await tester.pumpAndSettle();
    expect(find.text('Template watermark'), findsOneWidget);
  });

  testWidgets('shows truthful offline and feature status labels', (tester) async {
    await tester.pumpWidget(const TermulPodApp());

    await tester.tap(find.byTooltip('Status penyimpanan'));
    await tester.pumpAndSettle();
    expect(find.text('Penyimpanan offline'), findsOneWidget);
    expect(find.textContaining('album Galeri Termul POD'), findsOneWidget);
    await tester.tap(find.text('Tutup'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('AKTIF'), findsOneWidget);
    expect(find.text('OPSIONAL'), findsOneWidget);
    expect(find.text('FOTO + VIDEO'), findsOneWidget);
    expect(find.text('AKTIF OFFLINE'), findsOneWidget);
    expect(
      find.textContaining('Watermark waktu dan lokasi tertanam pada foto serta video'),
      findsOneWidget,
    );
    expect(find.textContaining('tersimpan di perangkat'), findsOneWidget);
  });

  testWidgets('history tolerates a record with only one GPS coordinate',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'termul_pod_media_records_v1': [
        jsonEncode({
          'path': '/missing/pod_photo.jpg',
          'type': 'photo',
          'createdAt': DateTime.utc(2026, 11, 15).toIso8601String(),
          'latitude': -7.9826,
          'longitude': null,
        }),
      ],
    });

    await tester.pumpWidget(const TermulPodApp());
    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();

    expect(find.text('Foto POD'), findsOneWidget);
    expect(find.text('Koordinat GPS tidak tersedia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
