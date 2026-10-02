import 'dart:convert';
import 'package:http/http.dart' as http;

import 'place.dart';

/// Public data services used by Sepehr. Network requests have finite timeouts,
/// responses are validated before being exposed to screens, and no key is
/// required except NASA APOD (which can use its public DEMO_KEY fallback).
class Api {
  static const Duration _timeout = Duration(seconds: 15);

  static Future<dynamic> _get(Uri uri) async {
    final response = await http.get(uri).timeout(_timeout);
    if (response.statusCode != 200) {
      throw ApiException('درخواست اینترنتی با خطای ${response.statusCode} روبه‌رو شد');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const ApiException('پاسخ سرویس قابل خواندن نبود');
    }
  }

  /// Worldwide city search, with Persian names when the geocoder provides them.
  static Future<List<Place>> searchCities(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final json = await _get(Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q,
      'count': '15',
      'language': 'fa',
      'format': 'json',
    }));
    if (json is! Map<String, dynamic>) return const [];
    final results = json['results'];
    if (results is! List) return const [];
    return results.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final latitude = _number(item['latitude']);
      final longitude = _number(item['longitude']);
      if (latitude == null || longitude == null) return null;
      final administrativeArea = item['admin1']?.toString().trim() ?? '';
      final country = item['country']?.toString().trim() ?? '';
      final parts = [administrativeArea, country]
          .where((part) => part.isNotEmpty)
          .toSet()
          .toList(growable: false);
      return Place(
        name: item['name']?.toString() ?? 'شهر بدون نام',
        country: parts.join('، '),
        lat: latitude,
        lon: longitude,
        timezone: item['timezone']?.toString() ?? 'auto',
      );
    }).whereType<Place>().toList(growable: false);
  }

  /// Turn GPS coordinates into a city name. Coordinates are retained if the
  /// reverse-geocoder is down, so using GPS still succeeds offline-ish.
  static Future<Place> reverse(double latitude, double longitude) async {
    try {
      final json = await _get(Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client', {
        'latitude': latitude.toStringAsFixed(6),
        'longitude': longitude.toStringAsFixed(6),
        'localityLanguage': 'fa',
      }));
      if (json is Map<String, dynamic>) {
        final city = [json['city'], json['locality'], json['principalSubdivision']]
            .whereType<String>()
            .map((value) => value.trim())
            .firstWhere((value) => value.isNotEmpty, orElse: () => 'موقعیت من');
        return Place(
          name: city,
          country: json['countryName']?.toString() ?? '',
          lat: latitude,
          lon: longitude,
        );
      }
    } catch (_) {
      // GPS coordinates remain useful when the reverse lookup is unavailable.
    }
    return Place(name: 'موقعیت من', country: '', lat: latitude, lon: longitude);
  }

  /// Current conditions and a seven-day outlook for a location.
  static Future<SkyWeather> weather(Place place) async {
    final json = await _get(Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': place.latitude.toStringAsFixed(5),
      'longitude': place.longitude.toStringAsFixed(5),
      'hourly': 'cloud_cover,visibility,temperature_2m,relative_humidity_2m,dew_point_2m,wind_speed_10m,precipitation_probability',
      'daily': 'sunrise,sunset,temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code',
      'timezone': 'auto',
      'forecast_days': '7',
    }));
    if (json is! Map<String, dynamic>) {
      throw const ApiException('پیش‌بینی هوا در قالب مورد انتظار نبود');
    }
    return SkyWeather.fromJson(json);
  }

  static Future<Map<String, dynamic>> iss() async {
    final json = await _get(Uri.https('api.wheretheiss.at', '/v1/satellites/25544'));
    if (json is! Map<String, dynamic>) throw const ApiException('موقعیت ایستگاه در دسترس نیست');
    return json;
  }

  static Future<Map<String, dynamic>> apod(String key, {String? date}) async {
    final json = await _get(Uri.https('api.nasa.gov', '/planetary/apod', {
      'api_key': key,
      if (date != null) 'date': date,
    }));
    if (json is! Map<String, dynamic>) throw const ApiException('پاسخ ناسا در قالب مورد انتظار نبود');
    return json;
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class HourlySky {
  final DateTime localTime;
  final double cloudPercent;
  final double temperatureC;
  final double visibilityMeters;
  final double humidityPercent;
  final double dewPointC;
  final double windKph;
  final double precipitationChance;

  const HourlySky({
    required this.localTime,
    required this.cloudPercent,
    required this.temperatureC,
    required this.visibilityMeters,
    required this.humidityPercent,
    required this.dewPointC,
    required this.windKph,
    required this.precipitationChance,
  });
}

class DailySky {
  final DateTime localDate;
  final String sunrise;
  final String sunset;
  final double highC;
  final double lowC;
  final double precipitationChance;
  final int weatherCode;

  const DailySky({
    required this.localDate,
    required this.sunrise,
    required this.sunset,
    required this.highC,
    required this.lowC,
    required this.precipitationChance,
    required this.weatherCode,
  });
}

class SkyWeather {
  final int utcOffsetSeconds;
  final String timezone;
  final List<HourlySky> hours;
  final List<DailySky> days;

  const SkyWeather({
    required this.utcOffsetSeconds,
    required this.timezone,
    required this.hours,
    required this.days,
  });

  /// Open-Meteo returns local wall times without an offset. Store those wall
  /// times as UTC-shaped values so comparisons work consistently regardless
  /// of the Android device's own timezone.
  static DateTime _parseWallTime(dynamic value) {
    if (value is! String) throw const FormatException('زمان پیش‌بینی نامعتبر است');
    final parsed = DateTime.parse(value);
    return DateTime.utc(parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute, parsed.second);
  }

  static List<dynamic> _list(Map<String, dynamic> source, String key) {
    final value = source[key];
    return value is List ? value : const [];
  }

  static double _value(List<dynamic> values, int index, [double fallback = 0]) {
    if (index >= values.length) return fallback;
    return _number(values[index]) ?? fallback;
  }

  factory SkyWeather.fromJson(Map<String, dynamic> json) {
    final hourly = json['hourly'] is Map ? Map<String, dynamic>.from(json['hourly'] as Map) : <String, dynamic>{};
    final daily = json['daily'] is Map ? Map<String, dynamic>.from(json['daily'] as Map) : <String, dynamic>{};
    final rawTimes = _list(hourly, 'time');
    final times = rawTimes.map(_parseWallTime).toList(growable: false);
    final cloud = _list(hourly, 'cloud_cover');
    final temp = _list(hourly, 'temperature_2m');
    final visibility = _list(hourly, 'visibility');
    final humidity = _list(hourly, 'relative_humidity_2m');
    final dewPoint = _list(hourly, 'dew_point_2m');
    final wind = _list(hourly, 'wind_speed_10m');
    final precipitation = _list(hourly, 'precipitation_probability');
    final hourlyForecast = <HourlySky>[
      for (var i = 0; i < times.length; i++)
        HourlySky(
          localTime: times[i],
          cloudPercent: _value(cloud, i).clamp(0, 100).toDouble(),
          temperatureC: _value(temp, i),
          visibilityMeters: _value(visibility, i, 20000).clamp(0, 100000).toDouble(),
          humidityPercent: _value(humidity, i, 50).clamp(0, 100).toDouble(),
          dewPointC: _value(dewPoint, i),
          windKph: _value(wind, i).clamp(0, 300).toDouble(),
          precipitationChance: _value(precipitation, i).clamp(0, 100).toDouble(),
        ),
    ];

    final dates = _list(daily, 'time');
    final sunrises = _list(daily, 'sunrise');
    final sunsets = _list(daily, 'sunset');
    final highs = _list(daily, 'temperature_2m_max');
    final lows = _list(daily, 'temperature_2m_min');
    final rain = _list(daily, 'precipitation_probability_max');
    final weatherCodes = _list(daily, 'weather_code');
    final dailyForecast = <DailySky>[];
    for (var i = 0; i < dates.length; i++) {
      final date = dates[i];
      if (date is! String) continue;
      dailyForecast.add(DailySky(
        localDate: _parseWallTime(date),
        sunrise: i < sunrises.length ? _clockPart(sunrises[i]) : '--:--',
        sunset: i < sunsets.length ? _clockPart(sunsets[i]) : '--:--',
        highC: _value(highs, i),
        lowC: _value(lows, i),
        precipitationChance: _value(rain, i).clamp(0, 100).toDouble(),
        weatherCode: _value(weatherCodes, i).round(),
      ));
    }

    return SkyWeather(
      utcOffsetSeconds: _number(json['utc_offset_seconds'])?.round() ?? 0,
      timezone: json['timezone']?.toString() ?? 'auto',
      hours: List<HourlySky>.unmodifiable(hourlyForecast),
      days: List<DailySky>.unmodifiable(dailyForecast),
    );
  }

  static String _clockPart(dynamic value) {
    if (value is! String) return '--:--';
    final separator = value.indexOf('T');
    if (separator < 0) return '--:--';
    final end = separator + 6 < value.length ? separator + 6 : value.length;
    return value.substring(separator + 1, end);
  }

  String get sunset => days.isNotEmpty ? days.first.sunset : '--:--';
  String get sunrise => days.length > 1 ? days[1].sunrise : (days.isNotEmpty ? days.first.sunrise : '--:--');

  /// Forecast samples in the active local observing window (20:00–04:00).
  List<HourlySky> tonightHours(DateTime localNow) {
    final day = DateTime.utc(localNow.year, localNow.month, localNow.day);
    final overnight = localNow.hour < 4;
    final start = overnight ? day.subtract(const Duration(hours: 4)) : day.add(const Duration(hours: 20));
    final end = start.add(const Duration(hours: 8));
    return hours
        .where((hour) => !hour.localTime.isBefore(start) && hour.localTime.isBefore(end))
        .toList(growable: false);
  }

  /// Mean cloud cover over the local observing window (20:00–04:00).
  double? tonightCloud(DateTime localNow) {
    final values = tonightHours(localNow).map((hour) => hour.cloudPercent).toList(growable: false);
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  List<HourlySky> nextHours(DateTime localNow, {int count = 12}) {
    if (count <= 0) return const [];
    final now = DateTime.utc(localNow.year, localNow.month, localNow.day, localNow.hour);
    final first = hours.indexWhere((hour) => !hour.localTime.isBefore(now));
    if (first < 0) return const [];
    return hours.skip(first).take(count).toList(growable: false);
  }
}

double? _number(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}
