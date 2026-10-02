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
  double offsetH = 0;
  Star? picked;

  @override
  Widget build(BuildContext context) {
    final place = currentPlace.value;
    final shift = Duration(minutes: (offsetH * 60).round());
    final t = DateTime.now().add(shift); // absolute moment for the math
    final local = place.localNow().add(shift); // wall clock of the selected city
    final hh = '${fa(local.hour).padLeft(2, '۰')}:${fa(local.minute).padLeft(2, '۰')}';
    return ListView(padding: const EdgeInsets.all(20), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('نقشه‌ی آسمان', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        Text(hh, style: const TextStyle(fontSize: 22, color: C.gold, fontWeight: FontWeight.bold)),
      ]),
      Text('آسمان ${place.label} · روی نقشه بکش تا زمان جابه‌جا بشه', style: const TextStyle(color: C.muted)),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, box) {
        final size = min(box.maxWidth, 360.0);
        final painter = SkyPainter(t, place.lat, place.lon);
        return Center(
          child: GestureDetector(
            onHorizontalDragUpdate: (d) => setState(() => offsetH = (offsetH - d.delta.dx / 18).clamp(-12, 12)),
            onTapUp: (d) => setState(() => picked = painter.hit(d.localPosition, Size(size, size))),
            child: CustomPaint(size: Size(size, size), painter: painter),
          ),
        );
      }),
      Row(children: [
        Expanded(child: Slider(value: offsetH, min: -12, max: 12, activeColor: C.brass, onChanged: (v) => setState(() => offsetH = v))),
        OutlinedButton(onPressed: () => setState(() => offsetH = 0), child: const Text('الان')),
      ]),
      if (picked != null) Card(color: C.plate, child: ListTile(
        title: Text(picked!.name.isEmpty ? picked!.id : picked!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Builder(builder: (_) {
          final p = altAz(picked!.ra, picked!.dec, t, place.lat, place.lon);
          return Text('ارتفاع ${fa(p.alt)}° · سمت ${fa(p.az)}° · قدر ${fa(picked!.mag, 1)}', style: const TextStyle(color: C.muted));
        }),
        trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => picked = null)),
      )),
    ]);
  }
}

class SkyPainter extends CustomPainter {
  final DateTime t;
  final double lat, lon;
  SkyPainter(this.t, this.lat, this.lon);

  Offset? project(double ra, double dec, Size s) {
    final p = altAz(ra, dec, t, lat, lon);
    if (p.alt < 0) return null;
    final rr = s.width / 2 - 10, r = rr * (90 - p.alt) / 90, a = p.az * pi / 180;
    // north up, east left (looking up at the sky)
    return Offset(s.width / 2 - r * sin(a), s.height / 2 - r * cos(a));
  }

  Star? hit(Offset tap, Size s) {
    Star? best; double bestD = 24;
    for (final st in stars) {
      final p = project(st.ra, st.dec, s);
      if (p == null) continue;
      final d = (p - tap).distance;
      if (d < bestD) { bestD = d; best = st; }
    }
    return best;
  }

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero), R = s.width / 2 - 10;
    canvas.drawCircle(c, R, Paint()..shader = const RadialGradient(colors: [Color(0xFF1B2A74), Color(0xFF0B1033)]).createShader(Rect.fromCircle(center: c, radius: R)));
    canvas.drawCircle(c, R + 6, Paint()..color = C.brass..style = PaintingStyle.stroke..strokeWidth = 1.5);
    final pos = <String, Offset?>{for (final st in stars) st.id: project(st.ra, st.dec, s)};
    final line = Paint()..color = C.brass.withOpacity(.55)..strokeWidth = 1;
    for (final l in constellationLines) {
      final a = pos[l[0]], b = pos[l[1]];
      if (a != null && b != null) canvas.drawLine(a, b, line);
    }
    for (final st in stars) {
      final p = pos[st.id];
      if (p == null) continue;
      canvas.drawCircle(p, max(1.4, 3.6 - st.mag * .9), Paint()..color = const Color(0xFFFFF3C4));
      if (st.name.isNotEmpty && st.mag < 1.3) {
        final tp = TextPainter(text: TextSpan(text: st.name, style: const TextStyle(color: C.gold, fontSize: 12)), textDirection: TextDirection.rtl)..layout();
        tp.paint(canvas, p - Offset(tp.width / 2, 20));
      }
    }
    const dirs = {'ش': 0.0, 'شر': 90.0, 'ج': 180.0, 'غ': 270.0};
    dirs.forEach((label, az) {
      final a = az * pi / 180, p = c + Offset(-sin(a), -cos(a)) * (R + 6);
      canvas.drawCircle(p, 11, Paint()..color = C.night);
      final tp = TextPainter(text: TextSpan(text: label, style: const TextStyle(color: C.brass, fontSize: 11)), textDirection: TextDirection.rtl)..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    });
  }

  @override
  bool shouldRepaint(SkyPainter o) => o.t != t || o.lat != lat || o.lon != lon;
}
