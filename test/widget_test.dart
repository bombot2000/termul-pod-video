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
    expect(find.textContaining('penyimpanan internal aplikasi'), findsOneWidget);
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
}
