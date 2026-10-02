import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/place.dart';
import '../core/theme.dart';

/// Live ISS position from the free wheretheiss.at API (no key needed), refreshed every 5s.
class IssScreen extends StatefulWidget {
  const IssScreen({super.key});
  @override
  State<IssScreen> createState() => _IssScreenState();
}

class _IssScreenState extends State<IssScreen> {
  Map<String, dynamic>? data;
  String? error;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() { timer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    try {
      final r = await Api.iss();
      if (!mounted) return;
      setState(() { data = r; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = 'اتصال به اینترنت رو چک کن');
    }
  }

  Widget _stat(String label, String value, String unit) => Expanded(
    child: Card(color: C.plate, child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Column(children: [
      Text(label, style: const TextStyle(color: C.muted)),
      Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      Text(unit, style: const TextStyle(color: C.muted, fontSize: 12)),
    ]))),
  );

  /// Great-circle distance (km) between the selected city and the point under the ISS.
  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0, k = pi / 180;
    final a = pow(sin((lat2 - lat1) * k / 2), 2) + cos(lat1 * k) * cos(lat2 * k) * pow(sin((lon2 - lon1) * k / 2), 2);
    return 2 * r * asin(sqrt(a));
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final place = currentPlace.value;
    final dist = d == null ? null : _distanceKm(place.lat, place.lon, (d['latitude'] as num).toDouble(), (d['longitude'] as num).toDouble());
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('ایستگاه فضایی', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const Text('موقعیت زنده‌ی ISS، هر ۵ ثانیه', style: TextStyle(color: C.muted)),
      const SizedBox(height: 24),
      if (error != null) Text(error!, style: const TextStyle(color: C.red)),
      if (d == null && error == null) const Center(child: CircularProgressIndicator(color: C.brass)),
      if (d != null) ...[
        Card(color: C.teal, child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('الان بالای این نقطه‌ست', style: TextStyle(color: Color(0xFFD6F6FB))),
          const SizedBox(height: 6),
          Text('${fa(d['latitude'], 2)}° عرض · ${fa(d['longitude'], 2)}° طول', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(d['visibility'] == 'daylight' ? 'در روشنایی روز' : 'در سایه‌ی زمین', style: const TextStyle(color: Color(0xFFD6F6FB))),
        ]))),
        Card(color: C.plate, child: ListTile(
          leading: Icon((dist ?? 1e9) < 2000 ? Icons.visibility : Icons.public, color: (dist ?? 1e9) < 2000 ? C.gold : C.muted),
          title: Text('${fa(dist ?? 0)} کیلومتر تا ${place.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text((dist ?? 1e9) < 2000 ? 'الان بالای افق شماست! به آسمان نگاه کن' : 'فعلاً از ${place.name} دیده نمیشه', style: const TextStyle(color: C.muted)),
        )),
        Row(children: [
          _stat('ارتفاع', fa(d['altitude']), 'کیلومتر'),
          _stat('سرعت', fa(d['velocity']), 'کیلومتر/ساعت'),
          _stat('هر دور', fa(92), 'دقیقه'),
        ]),
      ],
    ]);
  }
}
