import 'dart:async';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/astro.dart';
import '../core/place.dart';
import '../core/theme.dart';

/// Live ISS telemetry with local topocentric elevation and bearing estimates.
class IssScreen extends StatefulWidget {
  final bool active;
  const IssScreen({super.key, this.active = true});

  @override
  State<IssScreen> createState() => _IssScreenState();
}

class _IssScreenState extends State<IssScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  DateTime? _updatedAt;
  Timer? _timer;
  bool _loading = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    currentPlace.addListener(_onPlaceChanged);
    if (widget.active) _activate();
  }

  @override
  void didUpdateWidget(covariant IssScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _activate();
    } else if (!widget.active && oldWidget.active) {
      _deactivate();
    }
  }

  void _activate() {
    _load();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  void _deactivate() {
    _timer?.cancel();
    _timer = null;
    _requestId++;
    if (mounted) setState(() => _loading = false);
  }

  void _onPlaceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    currentPlace.removeListener(_onPlaceChanged);
    _timer?.cancel();
    _requestId++;
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Api.iss();
      final latitude = _number(response['latitude']);
      final longitude = _number(response['longitude']);
      if (latitude == null || longitude == null) throw const ApiException('مختصات ایستگاه در پاسخ وجود ندارد.');
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _data = response;
        _updatedAt = DateTime.now();
        _error = null;
      });
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = 'موقعیت زنده در دسترس نیست؛ اتصال را بررسی کن.');
      }
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final place = currentPlace.value;
    final data = _data;
    final latitude = _number(data?['latitude']);
    final longitude = _number(data?['longitude']);
    final altitude = _number(data?['altitude']) ?? 408;
    final look = latitude == null || longitude == null
        ? null
        : satelliteLook(
            observerLatitude: place.lat,
            observerLongitude: place.lon,
            satelliteLatitude: latitude,
            satelliteLongitude: longitude,
            altitudeKm: altitude,
          );

    return RefreshIndicator(
      onRefresh: _load,
      color: C.brass,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        children: [
          Row(
            children: [
              const Expanded(child: Text('ایستگاه فضایی', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900))),
              IconButton(
                tooltip: 'به‌روزرسانی',
                onPressed: _loading ? null : _load,
                icon: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: C.brass))
                    : const Icon(Icons.refresh, color: C.brass),
              ),
            ],
          ),
          Text('موقعیت زنده‌ی ISS · به‌روزرسانی هر ۱۵ ثانیه', style: const TextStyle(color: C.muted)),
          const SizedBox(height: 12),
          if (_error != null && data == null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.satellite_alt, color: C.warning),
                title: Text(_error!),
                trailing: TextButton(onPressed: _load, child: const Text('تلاش دوباره')),
              ),
            ),
          if (_loading && data == null)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(color: C.brass))),
          if (data != null && look != null) ...[
            _positionCard(data, look, altitude),
            const SizedBox(height: 10),
            _passCard(look, place.name, data['visibility']?.toString()),
            const SizedBox(height: 10),
            Row(
              children: [
                _stat('ارتفاع مداری', fa(altitude), 'کیلومتر'),
                _stat('سرعت', fa(_number(data['velocity']) ?? 0), 'کیلومتر/ساعت'),
                _stat('مدار زمین', '۹۲', 'دقیقه'),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: C.warning, fontSize: 12)),
            ],
            if (_updatedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('آخرین دریافت: ${formatLocalClock(_updatedAt!)} · مکان تو: ${place.label}',
                    style: const TextStyle(color: C.muted, fontSize: 12)),
              ),
            const SizedBox(height: 12),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  '«بالای افق» فقط هندسه‌ی دید را نشان می‌دهد؛ روشنایی آسمان، ابر، ساختمان‌ها و زمان عبور تعیین می‌کنند که ایستگاه واقعاً دیده شود یا نه.',
                  style: TextStyle(color: C.muted, height: 1.5),
                ),
              ),
            ),
          ],
          if (data == null && _error == null && !_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('برای دریافت موقعیت، صفحه را تازه کن.', style: TextStyle(color: C.muted)))),
        ],
      ),
    );
  }

  Widget _positionCard(Map<String, dynamic> data, SatelliteLook look, double altitude) => Card(
        color: C.teal,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.public, color: Color(0xFFD6F6FB)),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('نقطه‌ی زیر ایستگاه روی زمین', style: TextStyle(color: Color(0xFFD6F6FB)))),
                  if (data['visibility'] != null)
                    Text(
                      data['visibility'].toString() == 'daylight' ? 'روشن‌شده با خورشید' : data['visibility'].toString(),
                      style: const TextStyle(color: Color(0xFFD6F6FB), fontSize: 11),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${fa(_number(data['latitude']) ?? 0, 2)}° عرض · ${fa(_number(data['longitude']) ?? 0, 2)}° طول',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'فاصله‌ی سطحی ${fa(look.groundDistanceKm)} کیلومتر · ارتفاع مداری ${fa(altitude)} کیلومتر',
                style: const TextStyle(color: Color(0xFFD6F6FB), fontSize: 12),
              ),
            ],
          ),
        ),
      );

  Widget _passCard(SatelliteLook look, String city, String? illumination) {
    final aboveHorizon = look.aboveGeometricHorizon;
    final bearingName = _bearingName(look.bearingDegrees);
    final statusColor = aboveHorizon ? C.good : C.muted;
    return Card(
      child: ListTile(
        leading: Icon(aboveHorizon ? Icons.visibility : Icons.visibility_off, color: statusColor, size: 30),
        title: Text(
          aboveHorizon ? 'بالای افق هندسی شماست' : 'فعلاً زیر افق هندسی است',
          style: TextStyle(fontWeight: FontWeight.bold, color: statusColor),
        ),
        subtitle: Text(
          'از $city رو به $bearingName · ارتفاع ${fa(look.elevationDegrees, 1)}° · سمت ${fa(look.bearingDegrees, 0)}°'
          '${illumination == null ? '' : '\nوضع خورشید برای خود ایستگاه: ${illumination == 'daylight' ? 'روشن' : 'در سایه'}'}',
          style: const TextStyle(color: C.muted, height: 1.5),
        ),
        isThreeLine: illumination != null,
      ),
    );
  }

  Widget _stat(String label, String value, String unit) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Column(
              children: [
                Text(label, style: const TextStyle(color: C.muted, fontSize: 11), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                Text(unit, style: const TextStyle(color: C.muted, fontSize: 11)),
              ],
            ),
          ),
        ),
      );

  String _bearingName(double degrees) {
    const directions = ['شمال', 'شمال‌شرق', 'شرق', 'جنوب‌شرق', 'جنوب', 'جنوب‌غرب', 'غرب', 'شمال‌غرب'];
    return directions[((degrees + 22.5) / 45).floor() % directions.length];
  }
}
