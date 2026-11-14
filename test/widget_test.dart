import 'package:flutter_test/flutter_test.dart';
import 'package:termul_pod_video/main.dart';

void main() {
  testWidgets('shows POD dashboard and navigation', (tester) async {
    await tester.pumpWidget(const TermulPodApp());

    expect(find.text('TERMUL POD'), findsOneWidget);
    expect(find.text('Dokumentasikan\nsetiap pengiriman.'), findsOneWidget);
    expect(find.text('Mulai dokumentasi'), findsOneWidget);

    await tester.tap(find.text('Riwayat'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada dokumentasi'), findsOneWidget);
  });

  testWidgets('unimplemented features are labelled and open a notice', (tester) async {
    await tester.pumpWidget(const TermulPodApp());

    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Segera'), findsWidgets);

    await tester.tap(find.text('Mulai dokumentasi'));
    await tester.pumpAndSettle();
    expect(find.text('Kamera POD'), findsOneWidget);

    await tester.tap(find.text('Mengerti'));
    await tester.pumpAndSettle();
    expect(find.text('Kamera POD'), findsNothing);
  });
}
