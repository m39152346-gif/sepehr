import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../core/api.dart';
import '../core/place.dart';
import '../core/theme.dart';

/// Choose a city by search or GPS, then manage a small offline favorite/recent list.
class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key});

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Place> _results = const [];
  List<Place> _favorites = const [];
  List<Place> _recent = const [];
  String? _error;
  Timer? _debounce;
  bool _searching = false;
  bool _locating = false;
  bool _selecting = false;
  int _searchRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadSavedPlaces();
  }

  Future<void> _loadSavedPlaces() async {
    final values = await Future.wait([loadFavoritePlaces(), loadRecentPlaces()]);
    if (!mounted) return;
    setState(() {
      _favorites = values[0];
      _recent = values[1];
    });
  }

  void _search(String query) {
    _debounce?.cancel();
    final clean = query.trim();
    final request = ++_searchRequest;
    if (clean.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() {
        _searching = true;
        _error = null;
      });
      try {
        final matches = await Api.searchCities(clean);
        if (!mounted || request != _searchRequest) return;
        setState(() => _results = matches);
      } catch (_) {
        if (mounted && request == _searchRequest) {
          setState(() {
            _results = const [];
            _error = 'جستجو انجام نشد؛ اتصال اینترنت را بررسی کن.';
          });
        }
      } finally {
        if (mounted && request == _searchRequest) setState(() => _searching = false);
      }
    });
  }

  Future<void> _useGps() async {
    if (_locating || _selecting) return;
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationMessage('سرویس موقعیت گوشی خاموش است.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const _LocationMessage('اجازه‌ی دسترسی به موقعیت داده نشد.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationMessage('اجازه‌ی موقعیت برای برنامه مسدود شده؛ آن را از تنظیمات گوشی فعال کن.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final place = await Api.reverse(position.latitude, position.longitude);
      if (mounted) await _choose(place);
    } on _LocationMessage catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'موقعیت دریافت نشد؛ GPS و دسترسی برنامه را بررسی کن.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _choose(Place place) async {
    if (_selecting) return;
    setState(() {
      _selecting = true;
      _error = null;
    });
    var selected = place;
    try {
      final forecast = await Api.weather(place);
      selected = place.copyWith(utcOffsetSeconds: forecast.utcOffsetSeconds, timezone: forecast.timezone);
    } catch (_) {
      // Keep the city usable if weather is unavailable; the dashboard will
      // explain that local-time/forecast information could not be refreshed.
    }
    await setPlace(selected);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _toggleFavorite(Place place) async {
    await toggleFavoritePlace(place);
    await _loadSavedPlaces();
  }

  bool _isFavorite(Place place) => _favorites.any((saved) => saved.key == place.key);

  @override
  void dispose() {
    _searchRequest++;
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchingForText = _controller.text.trim().length >= 2;
    return Scaffold(
      appBar: AppBar(title: const Text('مکان رصد')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'نام شهر را فارسی یا انگلیسی بنویس',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'پاک کردن جستجو',
                        onPressed: () {
                          _controller.clear();
                          _search('');
                          _focusNode.requestFocus();
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: _locating
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: C.brass))
                  : const Icon(Icons.my_location, color: C.brass),
              title: const Text('استفاده از موقعیت فعلی (GPS)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('برای محاسبه‌ی آسمان اطراف تو', style: TextStyle(color: C.muted)),
              onTap: _locating || _selecting ? null : _useGps,
            ),
          ),
          if (_searching || _selecting)
            const LinearProgressIndicator(color: C.brass, minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: C.red), textAlign: TextAlign.center),
            ),
          Expanded(child: _buildPlaces(searchingForText)),
        ],
      ),
    );
  }

  Widget _buildPlaces(bool searchingForText) {
    if (searchingForText && _results.isEmpty && !_searching && _error == null) {
      return const Center(child: Text('شهری پیدا نشد؛ املای نام را بررسی کن.', style: TextStyle(color: C.muted)));
    }
    if (searchingForText) {
      return ListView.builder(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        itemCount: _results.length,
        itemBuilder: (context, index) => _placeTile(_results[index]),
      );
    }
    final recentKeys = _recent.map((place) => place.key).toSet();
    final visibleRecent = _recent.where((place) => !_favorites.any((favorite) => favorite.key == place.key)).toList();
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _sectionHeading(Icons.star, 'مکان‌های نشان‌شده'),
        if (_favorites.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text('برای دسترسی سریع، کنار هر شهر روی ستاره بزن.', style: TextStyle(color: C.muted)),
          ),
        for (final place in _favorites) _placeTile(place),
        _sectionHeading(Icons.history, 'مکان‌های اخیر'),
        if (visibleRecent.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text('شهرهای انتخاب‌شده اینجا می‌مانند.', style: TextStyle(color: C.muted)),
          ),
        for (final place in visibleRecent) _placeTile(place),
        if (!recentKeys.contains(currentPlace.value.key)) ...[
          _sectionHeading(Icons.my_location, 'مکان فعلی'),
          _placeTile(currentPlace.value),
        ],
      ],
    );
  }

  Widget _sectionHeading(IconData icon, String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Row(children: [Icon(icon, color: C.brass, size: 18), const SizedBox(width: 8), Text(label, style: const TextStyle(color: C.brass, fontWeight: FontWeight.bold))]),
      );

  Widget _placeTile(Place place) => ListTile(
        leading: Icon(place.key == currentPlace.value.key ? Icons.location_on : Icons.location_city,
            color: place.key == currentPlace.value.key ? C.gold : C.muted),
        title: Text(place.name),
        subtitle: Text(
          '${place.country.isEmpty ? 'مکان ذخیره‌شده' : place.country} · ${fa(place.lat, 2)}°، ${fa(place.lon, 2)}°',
          style: const TextStyle(color: C.muted, fontSize: 12),
        ),
        trailing: IconButton(
          tooltip: _isFavorite(place) ? 'حذف از نشان‌شده‌ها' : 'افزودن به نشان‌شده‌ها',
          icon: Icon(_isFavorite(place) ? Icons.star : Icons.star_border, color: C.gold),
          onPressed: () => _toggleFavorite(place),
        ),
        onTap: _selecting ? null : () => _choose(place),
      );
}

class _LocationMessage implements Exception {
  final String message;
  const _LocationMessage(this.message);
}
