import 'package:flutter_test/flutter_test.dart';
import 'package:termul_pod_video/services/watermark_text_layout.dart';

void main() {
  test('wraps whitespace-separated address at word boundaries', () {
    expect(
      wrapWatermarkText('Jalan Soekarno Hatta Lowokwaru Malang', 18),
      <String>['Jalan Soekarno', 'Hatta Lowokwaru…'],
    );
  });

  test('normalizes repeated whitespace', () {
    expect(
      wrapWatermarkText('  Jalan   Ijen\n\tKota Malang  ', 20),
      <String>['Jalan Ijen Kota', 'Malang'],
    );
  });

  test('splits long unbroken tokens and marks omitted text', () {
    expect(
      wrapWatermarkText('ABCDEFGHIJKLMN next', 6),
      <String>['ABCDEF', 'GHIJK…'],
    );
  });

  test('returns no lines for empty text or invalid dimensions', () {
    expect(wrapWatermarkText('   ', 10), isEmpty);
    expect(wrapWatermarkText('alamat', 0), isEmpty);
    expect(wrapWatermarkText('alamat', 10, maxLines: 0), isEmpty);
  });
}
