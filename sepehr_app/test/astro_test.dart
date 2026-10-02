import 'package:flutter_test/flutter_test.dart';
import 'package:sepehr/core/api.dart';
import 'package:sepehr/core/astro.dart';
import 'package:sepehr/core/place.dart';
import 'package:sepehr/core/theme.dart';

void main() {
  group('astronomy math', () {
    test('Polaris remains near the observer latitude in altitude', () {
      final result = altAz(2.53, 89.26, DateTime.utc(2026, 10, 3, 20), 35.69, 51.39);
      expect(result.alt, closeTo(35.69, 1.5));
      expect(result.az, inInclusiveRange(0, 360));
    });

    test('horizontal coordinates stay finite at the geographic poles', () {
      final result = altAz(8, 20, DateTime.utc(2026, 10, 3), 90, 0);
      expect(result.alt.isFinite, isTrue);
      expect(result.az.isFinite, isTrue);
    });

    test('Moon age and illumination are bounded', () {
      final moon = moonInfo(DateTime.utc(2026, 10, 3));
      expect(moon.age, inInclusiveRange(0, 1));
      expect(moon.illumination, inInclusiveRange(0, 1));
      expect(moon.phaseName, isNotEmpty);
    });

    test('upcoming quarter phases are sorted and include all phase types', () {
      final phases = upcomingMoonPhases(DateTime.utc(2026, 10, 3), count: 8);
      expect(phases, hasLength(8));
      for (var i = 1; i < phases.length; i++) {
        expect(phases[i].dateUtc.isAfter(phases[i - 1].dateUtc), isTrue);
      }
      expect(phases.map((phase) => phase.phase).toSet(), containsAll(MoonPhase.values));
    });

    test('rolling calendar includes future moon and meteor events', () {
      final events = upcomingEvents(DateTime.utc(2026, 10, 3), days: 180);
      expect(events, isNotEmpty);
      expect(events.every((event) => !event.dateUtc.isBefore(DateTime.utc(2026, 10, 3))), isTrue);
      expect(events.map((event) => event.kind), contains(AstroEventKind.moon));
      expect(events.map((event) => event.kind), contains(AstroEventKind.meteor));
      expect(events.map((event) => event.kind), contains(AstroEventKind.seasonal));
    });

    test('observation score rewards clear, dark, stable conditions', () {
      final excellent = observingScore(
        cloudCover: 0,
        moonIllumination: 0,
        humidity: 35,
        windSpeed: 4,
        visibilityMeters: 25000,
      );
      final poor = observingScore(
        cloudCover: 100,
        moonIllumination: 1,
        humidity: 100,
        windSpeed: 50,
        visibilityMeters: 1000,
      );
      expect(excellent, greaterThan(poor));
      expect(excellent, inInclusiveRange(0, 10));
      expect(poor, inInclusiveRange(0, 10));
      expect(observingScore(cloudCover: 50, moonIllumination: .5), closeTo(5, 1e-9));
    });

    test('ISS look geometry distinguishes overhead and far-side satellites', () {
      final overhead = satelliteLook(
        observerLatitude: 0,
        observerLongitude: 0,
        satelliteLatitude: 0,
        satelliteLongitude: 0,
        altitudeKm: 408,
      );
      expect(overhead.aboveGeometricHorizon, isTrue);
      expect(overhead.elevationDegrees, closeTo(90, .01));
      expect(overhead.groundDistanceKm, closeTo(0, .01));

      final farSide = satelliteLook(
        observerLatitude: 0,
        observerLongitude: 0,
        satelliteLatitude: 0,
        satelliteLongitude: 180,
        altitudeKm: 408,
      );
      expect(farSide.aboveGeometricHorizon, isFalse);
      expect(farSide.groundDistanceKm, greaterThan(20000));
    });
  });

  group('saved locations and forecast parsing', () {
    test('place JSON validates coordinates and preserves timezone', () {
      const place = Place(name: 'فرانکفورت', country: 'آلمان', lat: 50.11, lon: 8.68, timezone: 'Europe/Berlin', utcOffsetSeconds: 7200);
      final decoded = Place.fromJson(place.toJson());
      expect(decoded.name, place.name);
      expect(decoded.key, place.key);
      expect(decoded.timezone, 'Europe/Berlin');
      expect(() => Place.fromJson({'name': 'bad', 'lat': 93, 'lon': 0}), throwsA(isA<FormatException>()));
    });

    test('forecast times are interpreted as city wall-time, not device timezone', () {
      final weather = SkyWeather.fromJson({
        'timezone': 'Asia/Tehran',
        'utc_offset_seconds': 12600,
        'hourly': {
          'time': [
            '2026-10-03T20:00',
            '2026-10-03T21:00',
            '2026-10-03T22:00',
            '2026-10-04T03:00',
            '2026-10-04T04:00',
          ],
          'cloud_cover': [10, 20, 30, 40, 50],
          'temperature_2m': [12, 11, 10, 9, 8],
          'visibility': [20000, 18000, 16000, 14000, 12000],
          'relative_humidity_2m': [40, 42, 44, 46, 48],
          'dew_point_2m': [2, 2, 2, 2, 2],
          'wind_speed_10m': [3, 4, 5, 4, 3],
          'precipitation_probability': [0, 0, 5, 10, 10],
        },
        'daily': {
          'time': ['2026-10-03', '2026-10-04'],
          'sunrise': ['2026-10-03T06:00', '2026-10-04T06:01'],
          'sunset': ['2026-10-03T17:45', '2026-10-04T17:44'],
          'temperature_2m_max': [22, 21],
          'temperature_2m_min': [10, 9],
          'precipitation_probability_max': [5, 10],
          'weather_code': [1, 2],
        },
      });

      final local = DateTime.utc(2026, 10, 3, 22);
      expect(weather.utcOffsetSeconds, 12600);
      expect(weather.timezone, 'Asia/Tehran');
      expect(weather.tonightCloud(local), closeTo(25, 1e-9));
      expect(weather.tonightHours(local), hasLength(4));
      expect(weather.nextHours(DateTime.utc(2026, 10, 3, 21, 30), count: 2).first.localTime.hour, 21);
      expect(weather.sunset, '17:45');
      expect(weather.sunrise, '06:01');
      expect(weather.days, hasLength(2));
    });
  });

  test('Persian digits and temperature units format predictably', () {
    expect(fa(2026), '۲۰۲۶');
    expect(fa(12.5, 1), '۱۲٫۵');
    expect(formatTemperature(0, fahrenheit: true), '۳۲°F');
  });
}
