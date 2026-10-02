import 'dart:convert';
import 'package:http/http.dart' as http;
import 'place.dart';

/// All online services used by Sepehr. Every one is free and needs no API key
/// (except NASA, which works with DEMO_KEY but a free personal key is better).
class Api {
  static Future<dynamic> _get(String url) async {
    final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes));
  }

  /// City search worldwide (Open-Meteo geocoding), names in Persian when available.
  static Future<List<Place>> searchCities(String q) async {
    if (q.trim().length < 2) return [];
    final j = await _get('https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(q)}&count=15&language=fa&format=json');
    final list = (j['results'] as List?) ?? [];
    return list.map((r) => Place(
          name: r['name'] ?? '',
          country: [r['admin1'], r['country']].where((e) => e != null && e.toString().isNotEmpty).join('، '),
          lat: (r['latitude'] as num).toDouble(),
          lon: (r['longitude'] as num).toDouble(),
          timezone: r['timezone'] ?? 'auto',
        )).toList();
  }

  /// Turn GPS coordinates into a city name (BigDataCloud, free client endpoint).
  static Future<Place> reverse(double lat, double lon) async {
    try {
      final j = await _get('https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lon&localityLanguage=fa');
      final city = (j['city'] as String?)?.isNotEmpty == true ? j['city'] : (j['locality'] ?? 'موقعیت من');
      return Place(name: city, country: j['countryName'] ?? '', lat: lat, lon: lon);
    } catch (_) {
      return Place(name: 'موقعیت من', country: '', lat: lat, lon: lon);
    }
  }

  /// Tonight's sky conditions for a place: cloud cover by hour, sunrise/sunset, local UTC offset.
  static Future<SkyWeather> weather(Place p) async {
    final j = await _get('https://api.open-meteo.com/v1/forecast?latitude=${p.lat}&longitude=${p.lon}'
        '&hourly=cloud_cover,visibility,temperature_2m&daily=sunrise,sunset&timezone=auto&forecast_days=2');
    return SkyWeather.fromJson(j);
  }

  static Future<Map<String, dynamic>> iss() async => Map<String, dynamic>.from(await _get('https://api.wheretheiss.at/v1/satellites/25544'));

  static Future<Map<String, dynamic>> apod(String key) async => Map<String, dynamic>.from(await _get('https://api.nasa.gov/planetary/apod?api_key=$key'));
}

class SkyWeather {
  final int utcOffsetSeconds;
  final String timezone, sunset, sunrise;
  final List<DateTime> hours;
  final List<num> cloud, temp;
  SkyWeather(this.utcOffsetSeconds, this.timezone, this.sunset, this.sunrise, this.hours, this.cloud, this.temp);

  factory SkyWeather.fromJson(Map<String, dynamic> j) {
    final h = j['hourly'], d = j['daily'];
    String hm(String iso) => iso.split('T').last;
    return SkyWeather(
      j['utc_offset_seconds'] ?? 0,
      j['timezone'] ?? '',
      hm(d['sunset'][0]),
      hm(d['sunrise'][1]),
      (h['time'] as List).map((t) => DateTime.parse(t)).toList(),
      List<num>.from(h['cloud_cover'].map((v) => v ?? 0)),
      List<num>.from(h['temperature_2m'].map((v) => v ?? 0)),
    );
  }

  /// Average cloud cover between 20:00 and 04:00 local time (tonight's observing window).
  double tonightCloud(DateTime localNow) {
    final start = DateTime(localNow.year, localNow.month, localNow.day, localNow.hour < 6 ? 0 : 20);
    final end = start.add(Duration(hours: localNow.hour < 6 ? 5 : 8));
    final v = <num>[];
    for (var i = 0; i < hours.length; i++) {
      if (!hours[i].isBefore(start) && hours[i].isBefore(end)) v.add(cloud[i]);
    }
    return v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
  }
}
