import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A place anywhere on Earth. All astronomy is computed for the selected place.
class Place {
  final String name, country;
  final double lat, lon;
  final String timezone; // IANA, e.g. Europe/Paris
  final int utcOffsetSeconds; // refreshed from the forecast API (handles DST)
  const Place({required this.name, required this.country, required this.lat, required this.lon, this.timezone = 'auto', this.utcOffsetSeconds = 0});

  String get label => country.isEmpty ? name : '$name، $country';

  /// "Now" on the wall clock of this place.
  DateTime localNow() => DateTime.now().toUtc().add(Duration(seconds: utcOffsetSeconds));

  Place copyWith({int? utcOffsetSeconds, String? timezone}) => Place(
      name: name, country: country, lat: lat, lon: lon,
      timezone: timezone ?? this.timezone, utcOffsetSeconds: utcOffsetSeconds ?? this.utcOffsetSeconds);

  Map<String, dynamic> toJson() => {'name': name, 'country': country, 'lat': lat, 'lon': lon, 'tz': timezone, 'off': utcOffsetSeconds};
  factory Place.fromJson(Map<String, dynamic> j) => Place(
      name: j['name'], country: j['country'] ?? '', lat: (j['lat'] as num).toDouble(), lon: (j['lon'] as num).toDouble(),
      timezone: j['tz'] ?? 'auto', utcOffsetSeconds: j['off'] ?? 0);
}

const defaultPlace = Place(name: 'تهران', country: 'ایران', lat: 35.69, lon: 51.39, timezone: 'Asia/Tehran', utcOffsetSeconds: 12600);

/// Global selected place. Screens listen to it and recompute everything when it changes.
final ValueNotifier<Place> currentPlace = ValueNotifier(defaultPlace);

Future<void> loadSavedPlace() async {
  final raw = (await SharedPreferences.getInstance()).getString('place');
  if (raw != null) currentPlace.value = Place.fromJson(jsonDecode(raw));
}

Future<void> setPlace(Place p) async {
  currentPlace.value = p;
  (await SharedPreferences.getInstance()).setString('place', jsonEncode(p.toJson()));
}
