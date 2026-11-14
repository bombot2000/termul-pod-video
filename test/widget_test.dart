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

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada dokumentasi'), findsOneWidget);
  });
}
