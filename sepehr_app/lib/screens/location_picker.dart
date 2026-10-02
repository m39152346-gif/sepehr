import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/api.dart';
import '../core/place.dart';
import '../core/theme.dart';

/// Pick any city in the world (search) or use the phone's GPS.
class LocationPicker extends StatefulWidget {
  const LocationPicker({super.key});
  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final ctrl = TextEditingController();
  List<Place> results = [];
  bool loading = false;
  String? error;
  Timer? debounce;

  void _search(String q) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() { loading = true; error = null; });
      try {
        final r = await Api.searchCities(q);
        if (mounted) setState(() => results = r);
      } catch (_) {
        if (mounted) setState(() => error = 'جستجو انجام نشد، اینترنت رو چک کن');
      } finally {
        if (mounted) setState(() => loading = false);
      }
    });
  }

  Future<void> _gps() async {
    setState(() { loading = true; error = null; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'لوکیشن گوشی خاموشه';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw 'اجازه‌ی دسترسی به موقعیت داده نشد';
      final pos = await Geolocator.getCurrentPosition();
      final place = await Api.reverse(pos.latitude, pos.longitude);
      await _choose(place);
    } catch (e) {
      if (mounted) setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> _choose(Place p) async {
    var place = p;
    try {
      final w = await Api.weather(p); // fetch the real UTC offset (with DST) for the city
      place = p.copyWith(utcOffsetSeconds: w.utcOffsetSeconds, timezone: w.timezone);
    } catch (_) {}
    await setPlace(place);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() { debounce?.cancel(); ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: C.night, title: const Text('انتخاب شهر')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: ctrl, autofocus: true, onChanged: _search,
            decoration: InputDecoration(
              hintText: 'اسم شهر رو بنویس (فارسی یا انگلیسی)', prefixIcon: const Icon(Icons.search),
              filled: true, fillColor: C.plate, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.my_location, color: C.brass),
          title: const Text('استفاده از موقعیت فعلی من (GPS)', style: TextStyle(color: C.brass, fontWeight: FontWeight.bold)),
          onTap: loading ? null : _gps,
        ),
        if (loading) const LinearProgressIndicator(color: C.brass),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: C.red))),
        Expanded(
          child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (_, i) {
              final p = results[i];
              return ListTile(
                leading: const Icon(Icons.location_city, color: C.muted),
                title: Text(p.name),
                subtitle: Text('${p.country} · ${fa(p.lat, 2)}°، ${fa(p.lon, 2)}°', style: const TextStyle(color: C.muted)),
                onTap: () => _choose(p),
              );
            },
          ),
        ),
      ]),
    );
  }
}
