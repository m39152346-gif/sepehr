import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../core/api.dart';
import '../core/app_settings.dart';
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
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(minutes: 4),
  )..repeat();
  Timer? _clock;
  SkyWeather? _weather;
  String? _weatherError;
  bool _loadingWeather = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    currentPlace.addListener(_loadWeather);
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final place = currentPlace.value;
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _loadingWeather = true;
        _weatherError = null;
      });
    }
    try {
      final result = await Api.weather(place);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _weather = result;
        _weatherError = null;
      });
      if (result.utcOffsetSeconds != currentPlace.value.utcOffsetSeconds ||
          (result.timezone != 'auto' && result.timezone != currentPlace.value.timezone)) {
        unawaited(setPlace(currentPlace.value.copyWith(
          utcOffsetSeconds: result.utcOffsetSeconds,
          timezone: result.timezone,
        )));
      }
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() => _weatherError = 'وضعیت آسمان دریافت نشد؛ اتصال را بررسی و دوباره تلاش کن.');
      }
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loadingWeather = false);
    }
  }

  @override
  void dispose() {
    currentPlace.removeListener(_loadWeather);
    _ring.dispose();
    _clock?.cancel();
    super.dispose();
  }

  double? _average(List<HourlySky> entries, double Function(HourlySky) value) {
    if (entries.isEmpty) return null;
    return entries.map(value).reduce((a, b) => a + b) / entries.length;
  }

  @override
  Widget build(BuildContext context) {
    final place = currentPlace.value;
    final local = place.localNow();
    final moon = moonInfo(DateTime.now().toUtc());
    final jalali = Jalali.fromDateTime(local);
    final nightHours = _weather?.tonightHours(local) ?? const <HourlySky>[];
    final cloud = _weather?.tonightCloud(local);
    final humidity = _average(nightHours, (hour) => hour.humidityPercent);
    final wind = _average(nightHours, (hour) => hour.windKph);
    final visibility = _average(nightHours, (hour) => hour.visibilityMeters);
    final score = cloud == null
        ? null
        : observingScore(
            cloudCover: cloud,
            moonIllumination: moon.illumination,
            humidity: humidity,
            windSpeed: wind,
            visibilityMeters: visibility,
          );
    final eventsSoon = upcomingEvents(DateTime.now().toUtc(), days: 120);
    final nextEvent = eventsSoon.isEmpty ? null : eventsSoon.first;
    final moonPhases = upcomingMoonPhases(DateTime.now().toUtc(), count: 1);
    final nextMoon = moonPhases.isEmpty ? null : moonPhases.first;
    final settings = appSettings.value;

    return RefreshIndicator(
      onRefresh: _loadWeather,
      color: C.brass,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            '${jalali.formatter.wN} ${fa(jalali.day)} ${jalali.formatter.mN} · ${place.label}',
            style: const TextStyle(color: C.muted),
          ),
          const SizedBox(height: 4),
          const Text('آسمان امشب', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          _moonCard(moon, nextMoon, place.lat < 0),
          const SizedBox(height: 12),
          _observingCard(score, cloud, humidity, wind, visibility),
          const SizedBox(height: 12),
          _conditionsCard(settings.fahrenheit),
          if (_weatherError != null) ...[
            const SizedBox(height: 8),
            Card(
              color: C.plate,
              child: ListTile(
                leading: const Icon(Icons.wifi_off, color: C.warning),
                title: Text(_weatherError!, style: const TextStyle(fontSize: 14)),
                trailing: IconButton(
                  tooltip: 'تلاش دوباره',
                  onPressed: _loadingWeather ? null : _loadWeather,
                  icon: const Icon(Icons.refresh, color: C.brass),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _hourlyForecast(local, settings.fahrenheit),
          const SizedBox(height: 12),
          _weekForecast(settings.fahrenheit),
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: C.brass,
              foregroundColor: C.night,
              padding: const EdgeInsets.all(17),
            ),
            onPressed: widget.onOpenSky,
            icon: const Icon(Icons.explore),
            label: const Text('نقشه‌ی آسمان را باز کن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          if (nextEvent != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event, color: C.brass),
                title: Text(_eventDate(nextEvent.dateUtc, place.utcOffsetSeconds), style: const TextStyle(color: C.brass)),
                subtitle: Text(nextEvent.title, style: const TextStyle(fontWeight: FontWeight.bold, color: C.text)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _moonCard(MoonInfo moon, MoonPhaseMoment? next, bool southernHemisphere) {
    final nextLabel = next == null ? '' : _eventDate(next.dateUtc, currentPlace.value.utcOffsetSeconds);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _ring,
                    child: CustomPaint(size: const Size(118, 118), painter: _BrassRing()),
                  ),
                  Transform.rotate(
                    angle: southernHemisphere ? pi : 0,
                    child: CustomPaint(size: const Size(72, 72), painter: MoonPainter(moon.age)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(moon.phaseName, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: C.gold)),
                  const SizedBox(height: 4),
                  Text('${fa(moon.illumination * 100)}٪ روشن', style: const TextStyle(color: C.muted)),
                  Text('روز ${fa(moon.age * 29.5306, 1)} از چرخه‌ی ماه', style: const TextStyle(color: C.muted)),
                  if (next != null) ...[
                    const SizedBox(height: 8),
                    Text('فاز بعدی: ${next.phase.label}', style: const TextStyle(color: C.brass, fontSize: 13)),
                    Text('$nextLabel · زمان تقریبی', style: const TextStyle(color: C.muted, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _observingCard(double? score, double? cloud, double? humidity, double? wind, double? visibility) {
    final scoreColor = score == null
        ? C.muted
        : score >= 7
            ? C.good
            : score >= 4
                ? C.warning
                : C.red;
    final description = score == null
        ? 'برای امتیاز دقیق، پیش‌بینی هوا لازم است.'
        : score >= 7
            ? 'شرایط مناسب رصد است؛ از آسمان تاریک لذت ببر.'
            : score >= 4
                ? 'شرایط متوسط است؛ بازه‌های کم‌ابر را بررسی کن.'
                : 'امشب شرایط رصد ایده‌آل نیست.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.stars, color: C.brass),
                const SizedBox(width: 8),
                const Expanded(child: Text('امتیاز رصد امشب', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                if (_loadingWeather) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.brass)),
                const SizedBox(width: 8),
                Text(score == null ? '—' : '${fa(score, 1)} / ۱۰', style: TextStyle(fontSize: 20, color: scoreColor, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(color: C.muted)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _metricChip(Icons.cloud_outlined, cloud == null ? 'ابر: —' : 'ابر ${fa(cloud)}٪'),
                _metricChip(Icons.water_drop_outlined, humidity == null ? 'رطوبت: —' : 'رطوبت ${fa(humidity)}٪'),
                _metricChip(Icons.air, wind == null ? 'باد: —' : 'باد ${fa(wind)} کیلومتر/ساعت'),
                _metricChip(Icons.visibility_outlined, visibility == null ? 'دید: —' : 'دید ${fa(visibility / 1000, 1)} کیلومتر'),
              ],
            ),
            const SizedBox(height: 8),
            const Text('برآورد آموزشی؛ به‌جای اندازه‌گیری رصدگاهی است.', style: TextStyle(color: C.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _conditionsCard(bool fahrenheit) {
    final weather = _weather;
    if (weather == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_loadingWeather ? 'در حال دریافت طلوع، غروب و وضعیت آسمان…' : 'اطلاعات هوا فعلاً در دسترس نیست.', style: const TextStyle(color: C.muted)),
        ),
      );
    }
    final local = currentPlace.value.localNow();
    final currentHours = weather.nextHours(local, count: 1);
    final currentHour = currentHours.isEmpty ? null : currentHours.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          runSpacing: 12,
          spacing: 20,
          children: [
            _info(Icons.wb_twilight, _faTime(weather.sunset), 'غروب'),
            _info(Icons.wb_sunny_outlined, _faTime(weather.sunrise), 'طلوع فردا'),
            if (currentHour != null) _info(Icons.thermostat, formatTemperature(currentHour.temperatureC, fahrenheit: fahrenheit), 'دما'),
          ],
        ),
      ),
    );
  }

  Widget _hourlyForecast(DateTime local, bool fahrenheit) {
    final weather = _weather;
    final hours = weather?.nextHours(local, count: 12) ?? const <HourlySky>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('پیش‌بینی ساعتی', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('ابر، دما و احتمال بارش در ۱۲ ساعت آینده', style: TextStyle(color: C.muted, fontSize: 12)),
            const SizedBox(height: 8),
            if (hours.isEmpty)
              const Padding(padding: EdgeInsets.all(12), child: Text('اطلاعات ساعتی موجود نیست.', style: TextStyle(color: C.muted)))
            else
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: hours.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final hour = hours[index];
                    return Container(
                      width: 68,
                      decoration: BoxDecoration(color: C.night.withOpacity(.55), borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(fa(hour.localTime.hour).padLeft(2, '۰'), style: const TextStyle(color: C.muted, fontSize: 12)),
                          Icon(_weatherIcon(hour.cloudPercent, hour.precipitationChance), color: C.gold, size: 20),
                          Text('${fa(hour.cloudPercent)}٪', style: const TextStyle(fontSize: 12)),
                          Text(formatTemperature(hour.temperatureC, fahrenheit: fahrenheit), style: const TextStyle(fontSize: 11)),
                          Text('${fa(hour.precipitationChance)}٪ بارش', style: const TextStyle(color: C.muted, fontSize: 9)),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _weekForecast(bool fahrenheit) {
    final days = _weather?.days ?? const <DailySky>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('چشم‌انداز هفت‌روزه', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (days.isEmpty)
              const Text('پیش‌بینی روزانه دریافت نشده است.', style: TextStyle(color: C.muted))
            else
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final date = Jalali.fromDateTime(day.localDate);
                    return Container(
                      width: 76,
                      decoration: BoxDecoration(color: C.night.withOpacity(.55), borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(index == 0 ? 'امروز' : fa(date.formatter.wN), style: const TextStyle(color: C.muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Icon(_weatherCodeIcon(day.weatherCode), color: C.brass, size: 19),
                          Text('↑${formatTemperature(day.highC, fahrenheit: fahrenheit)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          Text('↓${formatTemperature(day.lowC, fahrenheit: fahrenheit)}', style: const TextStyle(color: C.muted, fontSize: 10)),
                          Text('${fa(day.precipitationChance)}٪ بارش', style: const TextStyle(color: C.muted, fontSize: 9)),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(IconData icon, String label) => Chip(
        avatar: Icon(icon, color: C.brass, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        backgroundColor: C.night,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      );

  Widget _info(IconData icon, String value, String label) => SizedBox(
        width: 86,
        child: Column(
          children: [
            Icon(icon, color: C.brass),
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(color: C.muted, fontSize: 12)),
          ],
        ),
      );

  IconData _weatherIcon(double cloud, double rain) {
    if (rain >= 45) return Icons.water_drop_outlined;
    if (cloud >= 70) return Icons.cloud;
    if (cloud >= 30) return Icons.cloud_queue;
    return Icons.nights_stay_outlined;
  }

  IconData _weatherCodeIcon(int code) {
    if (code >= 95) return Icons.thunderstorm_outlined;
    if (code >= 71) return Icons.ac_unit;
    if (code >= 51) return Icons.grain;
    if (code >= 45) return Icons.cloud_outlined;
    if (code >= 2) return Icons.cloud_queue;
    return Icons.wb_sunny_outlined;
  }

  String _faTime(String time) => faText(time);

  String _eventDate(DateTime utc, int offsetSeconds) {
    final local = utc.add(Duration(seconds: offsetSeconds));
    final date = Jalali.fromDateTime(local);
    return '${fa(date.day)} ${date.formatter.mN} · ${formatLocalClock(local)}';
  }
}

class MoonPainter extends CustomPainter {
  final double age;
  const MoonPainter(this.age);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFF202A53));
    final rx = cos(2 * pi * age).abs() * radius;
    final waxing = age < .5;
    final path = Path()..moveTo(radius, 0);
    path.arcToPoint(Offset(radius, 2 * radius), radius: Radius.circular(radius), clockwise: waxing);
    final crescent = waxing ? age < .25 : age > .75;
    path.arcToPoint(
      Offset(radius, 0),
      radius: Radius.elliptical(max(rx, .01), radius),
      clockwise: waxing ? !crescent : crescent,
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = const RadialGradient(colors: [Color(0xFFFFF6D6), Color(0xFFE9C96A)])
            .createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(MoonPainter oldDelegate) => oldDelegate.age != age;
}

class _BrassRing extends CustomPainter {
  const _BrassRing();

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.width / 2;
    final center = Offset(half, half);
    final paint = Paint()..color = C.brass.withOpacity(.75)..style = PaintingStyle.stroke;
    canvas.drawCircle(center, half - 2, paint..strokeWidth = 1.5);
    canvas.drawCircle(center, half - 13, paint..strokeWidth = .7);
    for (var index = 0; index < 48; index++) {
      final angle = index * 7.5 * pi / 180;
      final long = index % 4 == 0;
      final outer = half - 2;
      final inner = half - (long ? 10 : 6);
      canvas.drawLine(
        center + Offset(sin(angle), -cos(angle)) * outer,
        center + Offset(sin(angle), -cos(angle)) * inner,
        paint..strokeWidth = long ? 1.2 : .7,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
