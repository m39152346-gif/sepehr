import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A saved observing location anywhere on Earth.
@immutable
class Place {
  final String name;
  final String country;
  final double lat;
  final double lon;
  final String timezone;
  final int utcOffsetSeconds;

  const Place({
    required this.name,
    required this.country,
    required this.lat,
    required this.lon,
    this.timezone = 'auto',
    this.utcOffsetSeconds = 0,
  });

  double get latitude => lat;
  double get longitude => lon;
  String get label => country.isEmpty ? name : '$name، $country';
  String get key => '${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}';

  /// The selected city's wall-clock time represented as a UTC-shaped value;
  /// this avoids accidentally applying the phone's timezone a second time.
  DateTime localNow() => DateTime.now().toUtc().add(Duration(seconds: utcOffsetSeconds));

  Place copyWith({int? utcOffsetSeconds, String? timezone}) => Place(
        name: name,
        country: country,
        lat: lat,
        lon: lon,
        timezone: timezone ?? this.timezone,
        utcOffsetSeconds: utcOffsetSeconds ?? this.utcOffsetSeconds,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'country': country,
        'lat': lat,
        'lon': lon,
        'tz': timezone,
        'off': utcOffsetSeconds,
      };

  factory Place.fromJson(Map<String, dynamic> json) {
    double number(dynamic value, String key) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
      throw FormatException('Invalid location field: $key');
    }

    final latitude = number(json['lat'] ?? json['latitude'], 'latitude');
    final longitude = number(json['lon'] ?? json['longitude'], 'longitude');
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      throw const FormatException('Location coordinates are outside the globe');
    }
    return Place(
      name: json['name']?.toString() ?? 'مکان ذخیره‌شده',
      country: json['country']?.toString() ?? '',
      lat: latitude,
      lon: longitude,
      timezone: json['tz']?.toString() ?? json['timezone']?.toString() ?? 'auto',
      utcOffsetSeconds: (json['off'] is num ? (json['off'] as num).round() : 0),
    );
  }
}

const defaultPlace = Place(
  name: 'تهران',
  country: 'ایران',
  lat: 35.69,
  lon: 51.39,
  timezone: 'Asia/Tehran',
  utcOffsetSeconds: 12600,
);

const _selectedPlaceKey = 'place';
const _favoritePlacesKey = 'favorite_places_v2';
const _recentPlacesKey = 'recent_places_v2';
const _maxRecentPlaces = 8;

/// Global selected place. Screens that depend on coordinates subscribe to it.
final ValueNotifier<Place> currentPlace = ValueNotifier(defaultPlace);

Future<void> loadSavedPlace() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_selectedPlaceKey);
    if (raw == null) return;
    final decoded = jsonDecode(raw);
    if (decoded is Map) currentPlace.value = Place.fromJson(Map<String, dynamic>.from(decoded));
  } catch (_) {
    // A stale or malformed saved preference should never block app startup.
  }
}

Future<void> setPlace(Place place) async {
  currentPlace.value = place;
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedPlaceKey, jsonEncode(place.toJson()));
    await _savePlaceList(preferences, _recentPlacesKey, [
      place,
      ...(await _readPlaceList(preferences, _recentPlacesKey)).where((saved) => saved.key != place.key),
    ].take(_maxRecentPlaces).toList(growable: false));
  } catch (_) {
    // Keep the current in-memory selection even if local storage is unavailable.
  }
}

Future<List<Place>> loadFavoritePlaces() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    return _readPlaceList(preferences, _favoritePlacesKey);
  } catch (_) {
    return const [];
  }
}

Future<List<Place>> loadRecentPlaces() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    return _readPlaceList(preferences, _recentPlacesKey);
  } catch (_) {
    return const [];
  }
}

Future<bool> toggleFavoritePlace(Place place) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final saved = await _readPlaceList(preferences, _favoritePlacesKey);
    final isSaved = saved.any((item) => item.key == place.key);
    final updated = isSaved
        ? saved.where((item) => item.key != place.key).toList(growable: false)
        : [place, ...saved].take(20).toList(growable: false);
    await _savePlaceList(preferences, _favoritePlacesKey, updated);
    return !isSaved;
  } catch (_) {
    return false;
  }
}

Future<bool> isFavoritePlace(Place place) async =>
    (await loadFavoritePlaces()).any((item) => item.key == place.key);

Future<List<Place>> _readPlaceList(SharedPreferences preferences, String key) async {
  final values = preferences.getStringList(key) ?? const [];
  final places = <Place>[];
  for (final value in values) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final place = Place.fromJson(Map<String, dynamic>.from(decoded));
        if (!places.any((saved) => saved.key == place.key)) places.add(place);
      }
    } catch (_) {
      // Ignore a single corrupt saved item and preserve all other locations.
    }
  }
  return places;
}

Future<void> _savePlaceList(SharedPreferences preferences, String key, List<Place> places) async {
  await preferences.setStringList(key, places.map((place) => jsonEncode(place.toJson())).toList(growable: false));
}
