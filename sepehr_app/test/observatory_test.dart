import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sepehr/core/observatory.dart';
import 'package:sepehr/screens/observatory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('version 3 target planning', () {
    test('curated deep-sky catalog has unique searchable targets', () {
      expect(deepSkyTargets.length, greaterThanOrEqualTo(16));
      expect(deepSkyTargets.map((target) => target.id).toSet().length, deepSkyTargets.length);
      expect(targetById('m31')?.catalog, 'M31');
      expect(targetById('unknown'), isNull);
      expect(deepSkyTargets.every((target) => target.hopGuide.isNotEmpty), isTrue);
    });

    test('target visibility and recommendations stay within useful bounds', () {
      final from = DateTime.utc(2026, 10, 3, 19);
      final m31 = targetById('m31')!;
      final visibility = targetVisibility(
        m31,
        latitude: 50.11,
        longitude: 8.68,
        fromUtc: from,
      );
      expect(visibility.nowPosition.alt.isFinite, isTrue);
      expect(visibility.nowPosition.az, inInclusiveRange(0, 360));
      expect(visibility.bestPosition.alt, greaterThanOrEqualTo(visibility.nowPosition.alt));
      expect(visibility.bestAtUtc.isAfter(from) || visibility.bestAtUtc.isAtSameMomentAs(from), isTrue);

      final darkSky = rankTonightTargets(
        latitude: 50.11,
        longitude: 8.68,
        fromUtc: from,
        bortleClass: 2,
        targets: [targetById('m101')!],
      ).single;
      final brightSky = rankTonightTargets(
        latitude: 50.11,
        longitude: 8.68,
        fromUtc: from,
        bortleClass: 9,
        targets: [targetById('m101')!],
      ).single;
      expect(darkSky.score, greaterThan(brightSky.score));
      expect(darkSky.score, inInclusiveRange(0, 100));
    });

    test('Bortle class yields bounded limiting-magnitude estimate', () {
      expect(estimatedLimitingMagnitude(1), closeTo(7.6, 1e-9));
      expect(estimatedLimitingMagnitude(9), lessThan(estimatedLimitingMagnitude(1)));
      expect(estimatedLimitingMagnitude(100), closeTo(estimatedLimitingMagnitude(9), 1e-9));
    });
  });

  group('field conditions and calculators', () {
    test('transparency improves with clearer, drier air and longer visibility', () {
      final clear = transparencyIndex(cloudPercent: 0, visibilityMeters: 25000, humidityPercent: 30);
      final poor = transparencyIndex(cloudPercent: 90, visibilityMeters: 1000, humidityPercent: 95);
      expect(clear, greaterThan(poor));
      expect(clear, inInclusiveRange(0, 100));
      expect(poor, inInclusiveRange(0, 100));
    });

    test('dew alert classifies close dew points and frost conditions', () {
      expect(assessDewRisk(temperatureC: 4, dewPointC: 3).risk, DewRisk.high);
      expect(assessDewRisk(temperatureC: 8, dewPointC: 5).risk, DewRisk.moderate);
      final frost = assessDewRisk(temperatureC: -2, dewPointC: -8);
      expect(frost.risk, DewRisk.low);
      expect(frost.frostPossible, isTrue);
    });

    test('optics and astrophotography calculators reject invalid inputs', () {
      expect(dawesLimitArcsec(150), closeTo(116 / 150, 1e-9));
      expect(dawesLimitArcsec(0), isNull);
      expect(trueFieldOfViewDegrees(68, 100), closeTo(.68, 1e-9));
      expect(trueFieldOfViewDegrees(0, 100), isNull);
      expect(ruleOf500ExposureSeconds(focalLengthMm: 50, cropFactor: 1.5), closeTo(500 / 75, 1e-9));
      expect(ruleOf500ExposureSeconds(focalLengthMm: 0), isNull);

      final frame = cameraFrameDegrees(sensorWidthMm: 36, sensorHeightMm: 24, focalLengthMm: 50)!;
      expect(frame.horizontalDegrees, closeTo(39.6, .2));
      expect(frame.verticalDegrees, closeTo(27.0, .2));
      expect(frame.diagonalDegrees, greaterThan(frame.horizontalDegrees));
      expect(cameraFrameDegrees(sensorWidthMm: 0, sensorHeightMm: 24, focalLengthMm: 50), isNull);
    });

    test('polar helper respects both hemispheres and local latitude', () {
      final north = polarAlignmentGuide(50.11);
      expect(north.truePoleDirection, 'شمال حقیقی');
      expect(north.polarAxisAltitudeDegrees, closeTo(50.11, 1e-9));
      final south = polarAlignmentGuide(-33.9);
      expect(south.truePoleDirection, 'جنوب حقیقی');
      expect(south.polarAxisAltitudeDegrees, closeTo(33.9, 1e-9));
    });
  });

  group('version 3 offline data', () {
    test('Bortle profiles persist independently for observing locations', () async {
      await saveBortleForPlace('frankfurt', 7);
      await saveBortleForPlace('tehran', 3);
      expect(await loadBortleForPlace('frankfurt'), 7);
      expect(await loadBortleForPlace('tehran'), 3);
      expect(await loadBortleForPlace('unknown'), 5);
    });

    test('plan filters unknown and duplicate targets while preserving order', () async {
      await saveObservingPlan(['m31', 'm42', 'm31', 'missing']);
      expect(await loadObservingPlan(), ['m31', 'm42']);
    });

    test('personal gear checklist retains checked defaults and custom items', () async {
      final defaults = await loadGearChecklist();
      expect(defaults.items, containsAll(defaultGearItems));
      final updated = GearChecklist(
        items: [...defaults.items, 'فیلتر باریک‌باند'],
        checked: {'چراغ قرمز و باتری اضافه', 'فیلتر باریک‌باند'},
      );
      await saveGearChecklist(updated);
      final loaded = await loadGearChecklist();
      expect(loaded.items, contains('فیلتر باریک‌باند'));
      expect(loaded.checked, containsAll(['چراغ قرمز و باتری اضافه', 'فیلتر باریک‌باند']));
    });

    test('journal entries round-trip, sort newest first, export, and delete', () async {
      final older = ObservationLogEntry(
        id: 'older',
        targetId: 'm31',
        targetName: 'کهکشان آندرومدا',
        observedAtUtc: DateTime.utc(2026, 1, 1, 20),
        durationMinutes: 32,
        rating: 4,
        note: 'آسمان تاریک بود',
      );
      final newer = ObservationLogEntry(
        id: 'newer',
        targetId: 'm42',
        targetName: 'سحابی جبار',
        observedAtUtc: DateTime.utc(2026, 1, 2, 21),
        utcOffsetSeconds: 3600,
        durationMinutes: 18,
        rating: 5,
        note: 'جزئیات خوبی دیده شد',
      );
      await addObservationJournalEntry(older);
      await addObservationJournalEntry(newer);
      final loaded = await loadObservationJournal();
      expect(loaded.map((entry) => entry.id), ['newer', 'older']);
      expect(loaded.first.durationMinutes, 18);
      expect(loaded.first.utcOffsetSeconds, 3600);
      final export = formatJournalExport(loaded);
      expect(export, contains('دفترچه‌ی رصد سپهر ۳'));
      expect(export, contains('سحابی جبار'));
      expect(export, contains('جزئیات خوبی دیده شد'));
      expect(export, contains('۲۲:۰۰'));
      await removeObservationJournalEntry('newer');
      expect((await loadObservationJournal()).map((entry) => entry.id), ['older']);
    });

    test('malformed journal rows are ignored and numeric fields are bounded', () async {
      final sanitized = ObservationLogEntry.fromJson({
        'id': 'safe',
        'targetName': 'هدف',
        'observedAtUtc': '2026-04-01T21:00:00Z',
        'durationMinutes': 9000,
        'rating': -4,
      });
      expect(sanitized.durationMinutes, 1440);
      expect(sanitized.rating, 1);
      expect(() => ObservationLogEntry.fromJson({'targetName': 'نامعتبر'}), throwsA(isA<FormatException>()));
    });
  });

  testWidgets('field station opens its new calculator section without network access', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: ObservatoryScreen(active: false)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('رصدگاه سپهر'), findsOneWidget);
    expect(find.text('هدف‌ها'), findsOneWidget);

    await tester.tap(find.text('ابزارها'));
    await tester.pumpAndSettle();
    expect(find.text('تفکیک‌پذیری داوز'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('راهنمای هم‌راستاسازی قطبی'),
      find.byKey(const PageStorageKey<String>('observatory-calculators')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('راهنمای هم‌راستاسازی قطبی'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
