import 'package:flutter_test/flutter_test.dart';
import 'package:sepehr/core/astro.dart';
import 'package:sepehr/core/theme.dart';

void main() {
  test('Polaris stays near the observer latitude in altitude', () {
    final p = altAz(2.53, 89.26, DateTime.utc(2026, 10, 3, 20), 35.69, 51.39);
    expect(p.alt, closeTo(35.69, 1.5));
  });

  test('Moon illumination is between 0 and 1', () {
    final m = moonInfo(DateTime.utc(2026, 10, 3));
    expect(m.illum, inInclusiveRange(0, 1));
    expect(m.name, isNotEmpty);
  });

  test('Persian digits', () {
    expect(fa(2026), '۲۰۲۶');
  });
}
