import 'dart:math';

import 'package:flutter/material.dart';

import '../core/astro.dart';
import '../core/place.dart';
import '../core/theme.dart';

class SkyMapScreen extends StatefulWidget {
  const SkyMapScreen({super.key});

  @override
  State<SkyMapScreen> createState() => _SkyMapScreenState();
}

class _SkyMapScreenState extends State<SkyMapScreen> {
  double _offsetHours = 0;
  double _magnitudeLimit = 2.8;
  double _zoom = 1;
  bool _showConstellations = true;
  Star? _picked;

  @override
  Widget build(BuildContext context) {
    final place = currentPlace.value;
    final shift = Duration(minutes: (_offsetHours * 60).round());
    final timeUtc = DateTime.now().toUtc().add(shift);
    final localTime = place.localNow().add(shift);
    final painter = SkyPainter(
      timeUtc,
      place.lat,
      place.lon,
      magnitudeLimit: _magnitudeLimit,
      zoom: _zoom,
      showConstellations: _showConstellations,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Row(
          children: [
            const Expanded(child: Text('نقشه‌ی آسمان', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
            Container(
              decoration: BoxDecoration(color: C.plate, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(formatLocalClock(localTime), style: const TextStyle(fontSize: 20, color: C.gold, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        Text('آسمان ${place.label} · زمان محلی', style: const TextStyle(color: C.muted)),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = min(constraints.maxWidth, 380.0);
            return Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) => setState(() {
                  _offsetHours = (_offsetHours - details.delta.dx / 20).clamp(-12, 12).toDouble();
                  _picked = null;
                }),
                onTapUp: (details) => setState(() => _picked = painter.hit(details.localPosition, Size(size, size))),
                child: Semantics(
                  label: 'نقشه‌ی دایره‌ای آسمان؛ لمس یک ستاره برای جزئیات و کشیدن افقی برای تغییر زمان',
                  child: CustomPaint(size: Size(size, size), painter: painter),
                ),
              ),
            );
          },
        ),
        if (_picked != null) _starDetails(_picked!, timeUtc, place.lat, place.lon),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, color: C.brass, size: 20),
                    const SizedBox(width: 8),
                    const Text('جابجایی زمان', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${_offsetHours >= 0 ? '+' : ''}${fa(_offsetHours, 1)} ساعت', style: const TextStyle(color: C.gold)),
                    const SizedBox(width: 8),
                    TextButton(onPressed: () => setState(() => _offsetHours = 0), child: const Text('اکنون')),
                  ],
                ),
                Slider(
                  value: _offsetHours,
                  min: -12,
                  max: 12,
                  divisions: 48,
                  activeColor: C.brass,
                  onChanged: (value) => setState(() {
                    _offsetHours = value;
                    _picked = null;
                  }),
                ),
                Row(
                  children: [
                    const Icon(Icons.brightness_5_outlined, color: C.gold, size: 18),
                    const SizedBox(width: 8),
                    const Text('بزرگ‌نمایی', style: TextStyle(color: C.muted)),
                    Expanded(
                      child: Slider(
                        value: _zoom,
                        min: .8,
                        max: 1.5,
                        divisions: 14,
                        activeColor: C.brass,
                        onChanged: (value) => setState(() => _zoom = value),
                      ),
                    ),
                    IconButton(
                      tooltip: _showConstellations ? 'پنهان کردن صورت‌های فلکی' : 'نمایش صورت‌های فلکی',
                      onPressed: () => setState(() => _showConstellations = !_showConstellations),
                      icon: Icon(_showConstellations ? Icons.polyline : Icons.scatter_plot, color: C.brass),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.star_outline, color: C.gold, size: 18),
                    const SizedBox(width: 8),
                    const Text('قدر حدی', style: TextStyle(color: C.muted)),
                    Expanded(
                      child: Slider(
                        value: _magnitudeLimit,
                        min: 0,
                        max: 4,
                        divisions: 16,
                        activeColor: C.brass,
                        onChanged: (value) => setState(() => _magnitudeLimit = value),
                      ),
                    ),
                    Text(fa(_magnitudeLimit, 1), style: const TextStyle(color: C.gold)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('شمال بالای نقشه است. مدل ساده‌ی ستاره‌های پرنور؛ آلودگی نوری و افق محلی لحاظ نشده‌اند.',
              style: TextStyle(color: C.muted, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _starDetails(Star star, DateTime time, double latitude, double longitude) {
    final position = altAz(star.ra, star.dec, time, latitude, longitude);
    return Card(
      color: C.plateLight,
      child: ListTile(
        leading: const Icon(Icons.star, color: C.gold),
        title: Text(star.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'ارتفاع ${fa(position.alt, 1)}° · سمت ${fa(position.az, 1)}° · قدر ${fa(star.magnitude, 2)}',
          style: const TextStyle(color: C.muted),
        ),
        trailing: IconButton(
          tooltip: 'بستن جزئیات',
          icon: const Icon(Icons.close, color: C.muted),
          onPressed: () => setState(() => _picked = null),
        ),
      ),
    );
  }
}

class SkyPainter extends CustomPainter {
  final DateTime time;
  final double latitude;
  final double longitude;
  final double magnitudeLimit;
  final double zoom;
  final bool showConstellations;

  const SkyPainter(
    this.time,
    this.latitude,
    this.longitude, {
    required this.magnitudeLimit,
    required this.zoom,
    required this.showConstellations,
  });

  Offset? project(double ra, double dec, Size size) {
    final horizontal = altAz(ra, dec, time, latitude, longitude);
    if (horizontal.alt < 0) return null;
    final radius = size.width / 2 - 20;
    final projectedRadius = radius * (90 - horizontal.alt) / 90 * zoom;
    final angle = horizontal.az * pi / 180;
    return Offset(
      size.width / 2 - projectedRadius * sin(angle),
      size.height / 2 - projectedRadius * cos(angle),
    );
  }

  Star? hit(Offset tap, Size size) {
    Star? best;
    var bestDistance = 28.0;
    for (final star in stars) {
      if (star.magnitude > magnitudeLimit) continue;
      final point = project(star.ra, star.dec, size);
      if (point == null) continue;
      final distance = (point - tap).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        best = star;
      }
    }
    return best;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 14;
    final circle = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()..shader = const RadialGradient(colors: [Color(0xFF1B2A74), Color(0xFF080F2B)]).createShader(circle),
    );
    canvas.drawCircle(center, radius + 5, Paint()..color = C.brass..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawCircle(center, radius * .67, Paint()..color = C.muted.withOpacity(.18)..style = PaintingStyle.stroke..strokeWidth = .7);
    canvas.drawCircle(center, radius * .33, Paint()..color = C.muted.withOpacity(.18)..style = PaintingStyle.stroke..strokeWidth = .7);

    canvas.save();
    canvas.clipPath(Path()..addOval(circle));
    final positions = <String, Offset?>{
      for (final star in stars)
        if (star.magnitude <= magnitudeLimit) star.id: project(star.ra, star.dec, size),
    };
    if (showConstellations) {
      final linePaint = Paint()..color = C.brass.withOpacity(.42)..strokeWidth = 1;
      for (final line in constellationLines) {
        final start = positions[line[0]];
        final end = positions[line[1]];
        if (start != null && end != null) canvas.drawLine(start, end, linePaint);
      }
    }
    for (final star in stars) {
      if (star.magnitude > magnitudeLimit) continue;
      final point = positions[star.id];
      if (point == null) continue;
      final starRadius = (3.8 - star.magnitude * .65).clamp(1.4, 5.0).toDouble();
      canvas.drawCircle(point, starRadius, Paint()..color = const Color(0xFFFFF3C4));
      if (star.magnitude < 1.4) {
        final text = TextPainter(
          text: TextSpan(text: star.name, style: const TextStyle(color: C.gold, fontSize: 10)),
          textDirection: TextDirection.rtl,
          maxLines: 1,
        )..layout(maxWidth: 84);
        text.paint(canvas, point - Offset(text.width / 2, text.height + 5));
      }
    }
    canvas.restore();

    const directions = {'ش': 0.0, 'شر': 90.0, 'ج': 180.0, 'غ': 270.0};
    directions.forEach((label, azimuth) {
      final angle = azimuth * pi / 180;
      final point = center + Offset(-sin(angle), -cos(angle)) * (radius + 6);
      canvas.drawCircle(point, 10, Paint()..color = C.night);
      final text = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: C.brass, fontSize: 11, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.rtl,
      )..layout();
      text.paint(canvas, point - Offset(text.width / 2, text.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant SkyPainter oldDelegate) =>
      oldDelegate.time != time ||
      oldDelegate.latitude != latitude ||
      oldDelegate.longitude != longitude ||
      oldDelegate.magnitudeLimit != magnitudeLimit ||
      oldDelegate.zoom != zoom ||
      oldDelegate.showConstellations != showConstellations;
}
