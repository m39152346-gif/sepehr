import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../core/api.dart';
import '../core/astro.dart';
import '../core/place.dart';
import '../core/theme.dart';

class TonightScreen extends StatefulWidget {
  final VoidCallback onOpenSky;
  const TonightScreen({super.key, required this.onOpenSky});
  @override
  State<TonightScreen> createState() => _TonightScreenState();
}

class _TonightScreenState extends State<TonightScreen> with SingleTickerProviderStateMixin {
  late final AnimationController ring = AnimationController(vsync: this, duration: const Duration(minutes: 4))..repeat();
  Timer? timer;
  SkyWeather? weather;
  String? weatherError;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    currentPlace.addListener(_loadWeather);
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() { weather = null; weatherError = null; });
    try {
      final w = await Api.weather(currentPlace.value);
      if (!mounted) return;
      setState(() => weather = w);
      if (w.utcOffsetSeconds != currentPlace.value.utcOffsetSeconds) {
        setPlace(currentPlace.value.copyWith(utcOffsetSeconds: w.utcOffsetSeconds, timezone: w.timezone));
      }
    } catch (_) {
      if (mounted) setState(() => weatherError = 'وضعیت هوا دریافت نشد');
    }
  }

  @override
  void dispose() { currentPlace.removeListener(_loadWeather); ring.dispose(); timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final place = currentPlace.value;
    final local = place.localNow();
    final m = moonInfo(DateTime.now());
    final j = Jalali.fromDateTime(local);
    final cloud = weather?.tonightCloud(local);
    // Observing score: dark moon + clear sky
    final score = cloud == null ? ((1 - m.illum) * 10) : ((1 - m.illum) * 4 + (1 - cloud / 100) * 6);
    final next = events.firstWhere((e) => !e.date.isBefore(DateTime(local.year, local.month, local.day)), orElse: () => events.first);
    final nj = Jalali.fromDateTime(next.date);
    return RefreshIndicator(
      onRefresh: _loadWeather,
      child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
        Text('${j.formatter.wN} ${fa(j.day)} ${j.formatter.mN} · ${place.label}', style: const TextStyle(color: C.muted)),
        const Text('آسمان امشب', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        Center(
          child: SizedBox(width: 260, height: 260, child: Stack(alignment: Alignment.center, children: [
            RotationTransition(turns: ring, child: CustomPaint(size: const Size(260, 260), painter: _BrassRing())),
            // Southern hemisphere sees the moon flipped
            Transform.rotate(angle: place.lat < 0 ? pi : 0, child: CustomPaint(size: const Size(156, 156), painter: MoonPainter(m.age))),
          ])),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(m.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: C.gold)),
            Text('${fa(m.illum * 100)}٪ روشن · روز ${fa(m.age * 29.53)} ماه قمری', style: const TextStyle(color: C.muted)),
          ])),
          Column(children: [
            Text('${fa(score.clamp(0, 10))}/۱۰', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const Text('امتیاز رصد', style: TextStyle(color: C.muted)),
          ]),
        ]),
        const SizedBox(height: 16),
        Card(color: C.plate, child: Padding(padding: const EdgeInsets.all(16), child: weather == null
            ? Text(weatherError ?? 'در حال گرفتن وضعیت آسمان...', style: const TextStyle(color: C.muted))
            : Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _info(Icons.cloud, '${fa(cloud!)}٪', 'ابر امشب'),
                _info(Icons.wb_twilight, _faTime(weather!.sunset), 'غروب'),
                _info(Icons.wb_sunny, _faTime(weather!.sunrise), 'طلوع فردا'),
              ]))),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.brass, foregroundColor: C.night, padding: const EdgeInsets.all(18)),
          onPressed: widget.onOpenSky, icon: const Icon(Icons.explore), label: const Text('ببین الان بالای سرت چیه', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 12),
        Card(color: C.plate, child: ListTile(
          title: Text('رویداد بعدی · ${fa(nj.day)} ${nj.formatter.mN}', style: const TextStyle(color: C.brass, fontSize: 14)),
          subtitle: Text(next.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: C.text)),
        )),
      ]),
    );
  }

  String _faTime(String hm) => hm.split('').map((c) => int.tryParse(c) == null ? c : fa(int.parse(c))).join();

  Widget _info(IconData i, String v, String l) => Column(children: [
        Icon(i, color: C.brass),
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(l, style: const TextStyle(color: C.muted)),
      ]);
}

class MoonPainter extends CustomPainter {
  final double age;
  MoonPainter(this.age);
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width / 2, c = Offset(r, r);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF1D2550));
    final rx = (cos(2 * pi * age)).abs() * r;
    final waxing = age < .5;
    final path = Path()..moveTo(r, 0);
    path.arcToPoint(Offset(r, 2 * r), radius: Radius.circular(r), clockwise: waxing);
    final crescent = waxing ? age < .25 : age > .75;
    path.arcToPoint(Offset(r, 0), radius: Radius.elliptical(max(rx, .01), r), clockwise: waxing ? !crescent : crescent);
    canvas.drawPath(path, Paint()..shader = const RadialGradient(colors: [Color(0xFFFFF6D6), Color(0xFFE9C96A)]).createShader(Rect.fromCircle(center: c, radius: r)));
  }
  @override
  bool shouldRepaint(MoonPainter oldDelegate) => oldDelegate.age != age;
}

class _BrassRing extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final h = s.width / 2, c = Offset(h, h);
    final p = Paint()..color = C.brass.withOpacity(.75)..style = PaintingStyle.stroke;
    canvas.drawCircle(c, h - 2, p..strokeWidth = 1.5);
    canvas.drawCircle(c, h - 18, p..strokeWidth = .7);
    for (var i = 0; i < 72; i++) {
      final a = i * 5 * pi / 180, long = i % 6 == 0;
      canvas.drawLine(c + Offset(sin(a), -cos(a)) * (h - 2), c + Offset(sin(a), -cos(a)) * (h - (long ? 14 : 8)), p..strokeWidth = long ? 1.4 : .7);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
