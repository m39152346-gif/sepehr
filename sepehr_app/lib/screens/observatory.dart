import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../core/api.dart';
import '../core/astro.dart';
import '../core/observatory.dart';
import '../core/place.dart';
import '../core/theme.dart';

/// Version 3 field station: deep-sky planning, a session journal, personal gear,
/// and practical visual/imaging calculators.
class ObservatoryScreen extends StatefulWidget {
  final bool active;
  const ObservatoryScreen({super.key, this.active = true});

  @override
  State<ObservatoryScreen> createState() => _ObservatoryScreenState();
}

class _ObservatoryScreenState extends State<ObservatoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _apertureController = TextEditingController(text: '150');
  final TextEditingController _apparentFieldController = TextEditingController(text: '68');
  final TextEditingController _magnificationController = TextEditingController(text: '75');
  final TextEditingController _photoFocalController = TextEditingController(text: '50');
  final TextEditingController _cropController = TextEditingController(text: '1');
  final TextEditingController _sensorWidthController = TextEditingController(text: '36');
  final TextEditingController _sensorHeightController = TextEditingController(text: '24');

  final Stopwatch _sessionWatch = Stopwatch();
  Timer? _clock;
  SkyWeather? _weather;
  String? _weatherError;
  bool _loadingWeather = false;
  int _weatherRequestId = 0;
  int _bortle = 5;
  int _placeRequestId = 0;
  String _category = 'همه';
  List<String> _plan = [];
  List<ObservationLogEntry> _journal = [];
  List<String> _gearItems = List.of(defaultGearItems);
  Set<String> _checkedGear = {};
  List<TargetOpportunity> _rankedTargets = const [];
  DateTime _lastPositionRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  static const _categories = ['همه', 'کهکشان', 'سحابی', 'خوشه‌ی باز', 'خوشه‌ی کروی'];

  @override
  void initState() {
    super.initState();
    currentPlace.addListener(_placeChanged);
    _refreshTargetPositions();
    _loadLocalData();
    if (widget.active) _loadWeather();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final refreshPositions = DateTime.now().difference(_lastPositionRefresh) >= const Duration(minutes: 1);
      if (refreshPositions) _refreshTargetPositions();
      if (refreshPositions || _sessionWatch.isRunning) setState(() {});
    });
  }

  Future<void> _loadLocalData() async {
    final place = currentPlace.value;
    final plan = await loadObservingPlan();
    final journal = await loadObservationJournal();
    final gear = await loadGearChecklist();
    final bortle = await loadBortleForPlace(place.key);
    if (!mounted) return;
    setState(() {
      _plan = List.of(plan);
      _journal = List.of(journal);
      _gearItems = List.of(gear.items);
      _checkedGear = Set.of(gear.checked);
      if (currentPlace.value.key == place.key) _bortle = bortle;
      _refreshTargetPositions();
    });
  }

  @override
  void didUpdateWidget(covariant ObservatoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _loadWeather();
  }

  void _placeChanged() {
    final place = currentPlace.value;
    final request = ++_placeRequestId;
    _refreshTargetPositions();
    if (widget.active) _loadWeather();
    loadBortleForPlace(place.key).then((value) {
      if (!mounted || request != _placeRequestId) return;
      setState(() {
        _bortle = value;
        _refreshTargetPositions();
      });
    });
  }

  void _refreshTargetPositions() {
    final place = currentPlace.value;
    _rankedTargets = rankTonightTargets(
      latitude: place.lat,
      longitude: place.lon,
      fromUtc: DateTime.now().toUtc(),
      bortleClass: _bortle,
    );
    _lastPositionRefresh = DateTime.now();
  }

  Future<void> _loadWeather() async {
    final request = ++_weatherRequestId;
    if (mounted) {
      setState(() {
        _loadingWeather = true;
        _weatherError = null;
      });
    }
    try {
      final result = await Api.weather(currentPlace.value);
      if (!mounted || request != _weatherRequestId) return;
      setState(() {
        _weather = result;
        _weatherError = null;
      });
    } catch (_) {
      if (!mounted || request != _weatherRequestId) return;
      setState(() => _weatherError = 'پیش‌بینی رصدگاهی دریافت نشد؛ اتصال را بررسی و دوباره تلاش کن.');
    } finally {
      if (mounted && request == _weatherRequestId) setState(() => _loadingWeather = false);
    }
  }

  @override
  void dispose() {
    currentPlace.removeListener(_placeChanged);
    _clock?.cancel();
    _sessionWatch.stop();
    _searchController.dispose();
    _apertureController.dispose();
    _apparentFieldController.dispose();
    _magnificationController.dispose();
    _photoFocalController.dispose();
    _cropController.dispose();
    _sensorWidthController.dispose();
    _sensorHeightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
              child: Row(
                children: [
                  const Icon(Icons.explore, color: C.brass, size: 28),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('رصدگاه سپهر', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
                        Text('برنامه‌ریزی، ثبت و ابزارهای میدانی · نسخه ۳', style: TextStyle(color: C.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (_loadingWeather)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: C.brass))
                  else
                    IconButton(tooltip: 'به‌روزرسانی پیش‌بینی', onPressed: _loadWeather, icon: const Icon(Icons.refresh, color: C.muted)),
                ],
              ),
            ),
            TabBar(
              isScrollable: true,
              labelColor: C.gold,
              unselectedLabelColor: C.muted,
              indicatorColor: C.brass,
              tabs: const [
                Tab(icon: Icon(Icons.auto_awesome), text: 'هدف‌ها'),
                Tab(icon: Icon(Icons.event_note), text: 'برنامه'),
                Tab(icon: Icon(Icons.menu_book_outlined), text: 'دفترچه'),
                Tab(icon: Icon(Icons.calculate_outlined), text: 'ابزارها'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _targetsTab(),
                  _planTab(),
                  _journalTab(),
                  _calculatorsTab(),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _targetsTab() {
    final place = currentPlace.value;
    final recommended = _rankedTargets.where((item) => item.visibility.bestPosition.alt >= 20).take(3).toList(growable: false);
    final query = _searchController.text.trim().toLowerCase();
    final filtered = deepSkyTargets.where((target) {
      final categoryMatches = _category == 'همه' ||
          (_category == 'سحابی' ? target.type.contains('سحابی') : target.type == _category);
      final queryMatches = query.isEmpty ||
          '${target.catalog} ${target.name} ${target.type} ${target.constellation}'.toLowerCase().contains(query);
      return categoryMatches && queryMatches;
    }).toList(growable: false);

    return ListView(
      key: const PageStorageKey('observatory-targets'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('راهنمای آسمان ${place.label}', style: const TextStyle(color: C.muted)),
        const SizedBox(height: 8),
        _siteProfileCard(),
        if (recommended.isNotEmpty) ...[
          const SizedBox(height: 8),
          _recommendationCard(recommended.first),
        ],
        const SizedBox(height: 8),
        _atmosphereCard(),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'جست‌وجوی جرم، نام یا صورت فلکی',
            prefixIcon: const Icon(Icons.search, color: C.brass),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(tooltip: 'پاک‌کردن جست‌وجو', onPressed: () { _searchController.clear(); setState(() {}); }, icon: const Icon(Icons.close)),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final category in _categories)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: _category == category,
                    selectedColor: C.brass.withOpacity(.25),
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('${fa(filtered.length)} جرم منتخب از ${fa(deepSkyTargets.length)} هدف', style: const TextStyle(color: C.muted, fontSize: 12)),
        for (final target in filtered) _targetCard(target),
        if (filtered.isEmpty) const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('هدفی با این جست‌وجو پیدا نشد.', style: TextStyle(color: C.muted))),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('مختصات و قدر ظاهری تقریبی‌اند؛ رؤیت‌پذیری به افق واقعی، ابزار و شرایط رصد بستگی دارد.',
              style: TextStyle(color: C.muted, fontSize: 11, height: 1.4)),
        ),
      ],
    );
  }

  Widget _siteProfileCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [Icon(Icons.dark_mode_outlined, color: C.brass), SizedBox(width: 8), Expanded(child: Text('پروفایل تاریکی آسمان', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]),
              const SizedBox(height: 4),
              const Text('مقیاس Bortle را برای همین مکان ذخیره کن؛ ۱ تاریک‌ترین و ۹ روشن‌ترین آسمان است.', style: TextStyle(color: C.muted, fontSize: 12, height: 1.4)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('کلاس Bortle', style: TextStyle(color: C.muted)),
                  const Spacer(),
                  DropdownButton<int>(
                    value: _bortle,
                    dropdownColor: C.plate,
                    underline: const SizedBox.shrink(),
                    items: [for (var value = 1; value <= 9; value++) DropdownMenuItem(value: value, child: Text('Bortle ${fa(value)}'))],
                    onChanged: (value) async {
                      if (value == null) return;
                      setState(() {
                        _bortle = value;
                        _refreshTargetPositions();
                      });
                      await saveBortleForPlace(currentPlace.value.key, value);
                    },
                  ),
                ],
              ),
              Text('قدر حدیِ چشم غیرمسلح: حدود ${fa(estimatedLimitingMagnitude(_bortle), 1)} · برآورد آموزشی',
                  style: const TextStyle(color: C.gold, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _recommendationCard(TargetOpportunity opportunity) {
    final target = opportunity.target;
    final visibility = opportunity.visibility;
    return Card(
      color: C.plateLight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [Icon(Icons.auto_awesome, color: C.gold), SizedBox(width: 8), Text('پیشنهاد هوشمند این بازه', style: TextStyle(fontWeight: FontWeight.bold))]),
            const SizedBox(height: 8),
            Text('${target.catalog} · ${target.name}', style: const TextStyle(fontSize: 18, color: C.gold, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text('ارتفاع اوج ${fa(visibility.bestPosition.alt, 1)}° در ${_localClock(visibility.bestAtUtc)} · امتیاز تناسب ${fa(opportunity.score.round())}/۱۰۰',
                style: const TextStyle(color: C.muted, fontSize: 12)),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                onPressed: () => _addToPlan(target),
                icon: const Icon(Icons.playlist_add),
                label: Text(_plan.contains(target.id) ? 'در برنامه هست' : 'افزودن به برنامه'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _targetCard(DeepSkyTarget target) {
    final visibility = _visibilityFor(target);
    final current = visibility.nowPosition;
    final statusColor = current.alt >= 20 ? C.good : current.alt >= 0 ? C.warning : C.muted;
    return Card(
      child: ExpansionTile(
        key: PageStorageKey<String>('target-${target.id}'),
        leading: Icon(_targetIcon(target.type), color: C.brass),
        title: Text('${target.catalog} · ${target.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(
          'ارتفاع ${fa(current.alt, 1)}° · سمت ${fa(current.az.round())}° ${_direction(current.az)} · قدر ${fa(target.magnitude, 1)}',
          style: TextStyle(color: statusColor, fontSize: 11),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Align(alignment: AlignmentDirectional.centerStart, child: Text('${target.type} · صورت فلکی ${target.constellation}', style: const TextStyle(color: C.gold, fontWeight: FontWeight.w600))),
          const SizedBox(height: 6),
          Text(target.description, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 8),
          const Text('راهنمای پرش ستاره‌ای', style: TextStyle(color: C.brass, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(target.hopGuide, style: const TextStyle(color: C.muted, height: 1.4, fontSize: 12)),
          const SizedBox(height: 8),
          _visibilitySummary(visibility),
          const SizedBox(height: 4),
          Text('شرایط تاریکی پیشنهادی: Bortle ${fa(target.maxUsefulBortle)} یا تاریک‌تر · مختصات تقریبی J2000',
              style: const TextStyle(color: C.muted, fontSize: 11)),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonalIcon(
              onPressed: () => _addToPlan(target),
              icon: Icon(_plan.contains(target.id) ? Icons.check : Icons.playlist_add),
              label: Text(_plan.contains(target.id) ? 'در برنامه‌ی رصد' : 'افزودن به برنامه'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visibilitySummary(TargetVisibility visibility) {
    final start = visibility.firstWindowStartUtc;
    final end = visibility.firstWindowEndUtc;
    String window;
    if (start == null) {
      window = 'در ۱۲ ساعت آینده به ارتفاع پیشنهادی ۲۰° نمی‌رسد.';
    } else if (visibility.inRecommendedWindowNow && end != null) {
      window = visibility.windowContinues
          ? 'اکنون بالای ۲۰° است و دست‌کم تا ${_localClock(end)} مناسب می‌ماند.'
          : 'اکنون بالای ۲۰° است؛ تا حدود ${_localClock(end)}.';
    } else {
      window = "بازه‌ی مناسب: ${_localClock(start)} تا ${end == null ? '—' : _localClock(end)}${visibility.windowContinues ? ' (دست‌کم)' : ''}.";
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: C.night.withOpacity(.65), borderRadius: BorderRadius.circular(12)),
      child: Text('اوج ${fa(visibility.bestPosition.alt, 1)}° در ${_localClock(visibility.bestAtUtc)} · $window',
          style: const TextStyle(color: C.gold, fontSize: 12, height: 1.4)),
    );
  }

  TargetVisibility _visibilityFor(DeepSkyTarget target) {
    final found = _rankedTargets.where((item) => item.target.id == target.id);
    if (found.isNotEmpty) return found.first.visibility;
    final place = currentPlace.value;
    return targetVisibility(target, latitude: place.lat, longitude: place.lon, fromUtc: DateTime.now().toUtc());
  }

  IconData _targetIcon(String type) {
    if (type.contains('کهکشان')) return Icons.blur_on;
    if (type.contains('سحابی')) return Icons.cloud_outlined;
    return Icons.star_outline;
  }

  String _direction(double azimuth) {
    const directions = ['شمال', 'شمال‌شرق', 'شرق', 'جنوب‌شرق', 'جنوب', 'جنوب‌غرب', 'غرب', 'شمال‌غرب'];
    return directions[((azimuth + 22.5) / 45).floor() % directions.length];
  }

  String _localClock(DateTime? utc) {
    if (utc == null) return '—';
    return formatLocalClock(utc.toUtc().add(Duration(seconds: currentPlace.value.utcOffsetSeconds)));
  }

  Future<void> _addToPlan(DeepSkyTarget target) async {
    if (_plan.contains(target.id)) {
      _snack('${target.catalog} از قبل در برنامه است.');
      return;
    }
    final updated = [..._plan, target.id];
    await saveObservingPlan(updated);
    if (!mounted) return;
    setState(() => _plan = updated);
    _snack('${target.catalog} به برنامه‌ی رصد اضافه شد.');
  }

  Future<void> _removeFromPlan(String targetId) async {
    final updated = _plan.where((id) => id != targetId).toList(growable: false);
    await saveObservingPlan(updated);
    if (mounted) setState(() => _plan = updated);
  }

  Future<void> _movePlanItem(int index, int delta) async {
    final destination = index + delta;
    if (destination < 0 || destination >= _plan.length) return;
    final updated = List<String>.of(_plan);
    final value = updated.removeAt(index);
    updated.insert(destination, value);
    await saveObservingPlan(updated);
    if (mounted) setState(() => _plan = updated);
  }

  Future<void> _choosePlanTarget() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.plate,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 10), child: Text('افزودن هدف به برنامه', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            for (final target in deepSkyTargets)
              ListTile(
                leading: Icon(_targetIcon(target.type), color: C.brass),
                title: Text('${target.catalog} · ${target.name}'),
                subtitle: Text(target.type, style: const TextStyle(color: C.muted)),
                trailing: Icon(_plan.contains(target.id) ? Icons.check : Icons.add, color: C.gold),
                onTap: () {
                  Navigator.of(context).pop();
                  _addToPlan(target);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _planTab() {
    final targets = _plan.map(targetById).whereType<DeepSkyTarget>().toList(growable: false);
    final elapsed = _sessionWatch.elapsed;
    return ListView(
      key: const PageStorageKey('observatory-plan'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _atmosphereCard(),
        const SizedBox(height: 8),
        _sessionCard(elapsed),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(child: Text('برنامه‌ی رصد من', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                  IconButton(tooltip: 'افزودن هدف', onPressed: _choosePlanTarget, icon: const Icon(Icons.add_circle_outline, color: C.brass)),
                ]),
                if (targets.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('هنوز هدفی انتخاب نشده؛ از فهرست هدف‌ها اضافه کن.', style: TextStyle(color: C.muted)))
                else
                  for (var index = 0; index < targets.length; index++)
                    _plannedTargetTile(targets[index], index, targets.length),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _gearCard(),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('رتبه‌بندی و پنجره‌های رصد فقط راهنمای برنامه‌ریزی‌اند؛ افق، درختان، ساختمان‌ها و شرایط واقعی را هم بررسی کن.',
              style: TextStyle(color: C.muted, fontSize: 11, height: 1.4)),
        ),
      ],
    );
  }

  Widget _sessionCard(Duration elapsed) {
    final time = "${fa(elapsed.inHours).padLeft(2, '۰')}:${fa(elapsed.inMinutes.remainder(60)).padLeft(2, '۰')}:${fa(elapsed.inSeconds.remainder(60)).padLeft(2, '۰')}";
    return Card(
      color: C.plateLight,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            const Row(children: [Icon(Icons.timer_outlined, color: C.gold), SizedBox(width: 8), Expanded(child: Text('زمان‌سنج جلسه‌ی میدانی', style: TextStyle(fontWeight: FontWeight.bold)))]),
            const SizedBox(height: 4),
            Text(time, style: const TextStyle(fontSize: 36, color: C.gold, fontWeight: FontWeight.w900)),
            const Text('با ثبت یادداشت، مدت جلسه در دفترچه ذخیره می‌شود.', style: TextStyle(color: C.muted, fontSize: 11)),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: C.brass, foregroundColor: C.night),
                  onPressed: () {
                    setState(() {
                      if (_sessionWatch.isRunning) {
                        _sessionWatch.stop();
                      } else {
                        _sessionWatch.start();
                      }
                    });
                  },
                  icon: Icon(_sessionWatch.isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(_sessionWatch.isRunning ? 'مکث' : 'شروع جلسه'),
                ),
                OutlinedButton.icon(
                  onPressed: () => setState(() { _sessionWatch.stop(); _sessionWatch.reset(); }),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('بازنشانی'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _plannedTargetTile(DeepSkyTarget target, int index, int count) {
    final visibility = _visibilityFor(target);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: C.night, borderRadius: BorderRadius.circular(9)),
            child: Text(fa(index + 1), style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${target.catalog} · ${target.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Text("اوج ارتفاع ${fa(visibility.bestPosition.alt, 0)}° · ${visibility.hasRecommendedWindow ? 'پنجره ${_localClock(visibility.firstWindowStartUtc)}' : 'نیازمند بررسی افق'}",
                    style: const TextStyle(color: C.muted, fontSize: 11)),
              ],
            ),
          ),
          IconButton(tooltip: 'انتقال به بالا', onPressed: index == 0 ? null : () => _movePlanItem(index, -1), icon: const Icon(Icons.arrow_upward, size: 19)),
          IconButton(tooltip: 'انتقال به پایین', onPressed: index == count - 1 ? null : () => _movePlanItem(index, 1), icon: const Icon(Icons.arrow_downward, size: 19)),
          IconButton(tooltip: 'حذف از برنامه', onPressed: () => _removeFromPlan(target.id), icon: const Icon(Icons.close, size: 19, color: C.muted)),
        ],
      ),
    );
  }

  Widget _gearCard() => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: Text('چک‌لیست تجهیزات من', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                IconButton(tooltip: 'افزودن وسیله', onPressed: _addGearItem, icon: const Icon(Icons.add, color: C.brass)),
              ]),
              const Text('فهرست و وضعیت هر وسیله روی همین دستگاه ذخیره می‌شود.', style: TextStyle(color: C.muted, fontSize: 11)),
              const SizedBox(height: 4),
              for (final item in _gearItems)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _checkedGear.contains(item),
                  activeColor: C.brass,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(item, style: const TextStyle(fontSize: 13)),
                  secondary: defaultGearItems.contains(item)
                      ? null
                      : IconButton(tooltip: 'حذف وسیله‌ی شخصی', onPressed: () => _removeGearItem(item), icon: const Icon(Icons.delete_outline, size: 19, color: C.muted)),
                  onChanged: (checked) => _toggleGear(item, checked ?? false),
                ),
            ],
          ),
        ),
      );

  Future<void> _toggleGear(String item, bool checked) async {
    setState(() {
      if (checked) {
        _checkedGear.add(item);
      } else {
        _checkedGear.remove(item);
      }
    });
    await saveGearChecklist(GearChecklist(items: _gearItems, checked: _checkedGear));
  }

  Future<void> _addGearItem() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('افزودن وسیله'),
        content: TextField(controller: controller, autofocus: true, maxLength: 80, decoration: const InputDecoration(labelText: 'نام وسیله')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('افزودن')),
        ],
      ),
    );
    controller.dispose();
    final item = value?.trim() ?? '';
    if (item.isEmpty || _gearItems.contains(item)) return;
    final updated = [..._gearItems, item];
    setState(() => _gearItems = updated);
    await saveGearChecklist(GearChecklist(items: _gearItems, checked: _checkedGear));
  }

  Future<void> _removeGearItem(String item) async {
    setState(() {
      _gearItems.remove(item);
      _checkedGear.remove(item);
    });
    await saveGearChecklist(GearChecklist(items: _gearItems, checked: _checkedGear));
  }

  Widget _journalTab() {
    return ListView(
      key: const PageStorageKey('observatory-journal'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.menu_book, color: C.brass), SizedBox(width: 8), Expanded(child: Text('دفترچه‌ی رصد محلی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)))]),
                const SizedBox(height: 4),
                Text('${fa(_journal.length)} ثبت روی دستگاه · شامل هدف، زمان، مدت، امتیاز و یادداشت', style: const TextStyle(color: C.muted, fontSize: 12)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.brass, foregroundColor: C.night),
                      onPressed: _createJournalEntry,
                      icon: const Icon(Icons.add),
                      label: const Text('ثبت رصد'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _journal.isEmpty ? null : _exportJournal,
                      icon: const Icon(Icons.copy),
                      label: const Text('کپی / خروجی متن'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_journal.isEmpty)
          const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('هنوز رصدی ثبت نشده است. پس از جلسه، هدف و یادداشتت را اینجا نگه دار.', style: TextStyle(color: C.muted, height: 1.4))))
        else ...[
          const Padding(padding: EdgeInsetsDirectional.only(start: 4, top: 8, bottom: 4), child: Text('آخرین ثبت‌ها', style: TextStyle(color: C.gold, fontWeight: FontWeight.bold))),
          for (final entry in _journal) _journalEntryCard(entry),
        ],
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('دفترچه فقط روی این دستگاه نگهداری می‌شود؛ برای پشتیبان، خروجی متن را کپی کن.', style: TextStyle(color: C.muted, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _journalEntryCard(ObservationLogEntry entry) {
    final local = entry.observedAtUtc.add(Duration(seconds: entry.utcOffsetSeconds));
    final jalali = Jalali.fromDateTime(local);
    return Card(
      child: ListTile(
        isThreeLine: entry.note.trim().isNotEmpty,
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star, color: C.gold, size: 17),
            Text('${fa(entry.rating)}/۵', style: const TextStyle(color: C.gold, fontSize: 10)),
          ],
        ),
        title: Text(entry.targetName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          "${fa(jalali.day)} ${jalali.formatter.mN} ${fa(jalali.year)} · ${formatLocalClock(local)} · ${fa(entry.durationMinutes)} دقیقه"
          "${entry.note.trim().isEmpty ? '' : '\n${entry.note.trim()}'}",
          maxLines: entry.note.trim().isEmpty ? 1 : 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: C.muted, height: 1.4, fontSize: 12),
        ),
        trailing: IconButton(
          tooltip: 'حذف ثبت',
          onPressed: () => _confirmDeleteEntry(entry),
          icon: const Icon(Icons.delete_outline, color: C.muted),
        ),
      ),
    );
  }

  Future<_JournalDraft?> _journalDraft() async {
    final controller = TextEditingController();
    var targetId = _plan.isNotEmpty ? _plan.first : deepSkyTargets.first.id;
    var rating = 4;
    final draft = await showDialog<_JournalDraft>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('ثبت یک رصد'),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: targetId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'هدف رصد'),
                    items: [for (final target in deepSkyTargets) DropdownMenuItem(value: target.id, child: Text('${target.catalog} · ${target.name}', overflow: TextOverflow.ellipsis))],
                    onChanged: (value) { if (value != null) setDialogState(() => targetId = value); },
                  ),
                  const SizedBox(height: 14),
                  const Text('ارزیابی تجربه', style: TextStyle(color: C.muted)),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    children: [
                      for (var score = 1; score <= 5; score++)
                        ChoiceChip(
                          label: Text('${fa(score)} ★'),
                          selected: rating == score,
                          onSelected: (_) => setDialogState(() => rating = score),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: const InputDecoration(labelText: 'یادداشت (اختیاری)', hintText: 'شرایط آسمان، ابزار یا جزئیات دیده‌شده'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
            FilledButton(onPressed: () => Navigator.pop(context, _JournalDraft(targetId, rating, controller.text.trim())), child: const Text('ذخیره')),
          ],
        ),
      ),
    );
    controller.dispose();
    return draft;
  }

  Future<void> _createJournalEntry() async {
    final draft = await _journalDraft();
    if (draft == null || !mounted) return;
    final target = targetById(draft.targetId);
    if (target == null) return;
    final duration = _sessionWatch.elapsed.inMinutes;
    _sessionWatch.stop();
    final now = DateTime.now().toUtc();
    final entry = ObservationLogEntry(
      id: now.microsecondsSinceEpoch.toString(),
      targetId: target.id,
      targetName: target.name,
      observedAtUtc: now,
      utcOffsetSeconds: currentPlace.value.utcOffsetSeconds,
      durationMinutes: duration,
      rating: draft.rating,
      note: draft.note,
    );
    await addObservationJournalEntry(entry);
    final updated = await loadObservationJournal();
    if (!mounted) return;
    setState(() {
      _journal = List.of(updated);
      _sessionWatch.reset();
    });
    _snack('ثبت رصد در دفترچه ذخیره شد.');
  }

  Future<void> _confirmDeleteEntry(ObservationLogEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف ثبت رصد؟'),
        content: Text('«${entry.targetName}» از دفترچه پاک شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    await removeObservationJournalEntry(entry.id);
    final updated = await loadObservationJournal();
    if (mounted) setState(() => _journal = List.of(updated));
  }

  Future<void> _exportJournal() async {
    await Clipboard.setData(ClipboardData(text: formatJournalExport(_journal)));
    if (mounted) _snack('خروجی دفترچه در کلیپ‌بورد کپی شد.');
  }

  Widget _calculatorsTab() {
    final aperture = _positiveNumber(_apertureController.text);
    final dawes = aperture == null ? null : dawesLimitArcsec(aperture);
    final afov = _positiveNumber(_apparentFieldController.text);
    final magnification = _positiveNumber(_magnificationController.text);
    final trueField = afov == null || magnification == null ? null : trueFieldOfViewDegrees(afov, magnification);
    final focal = _positiveNumber(_photoFocalController.text);
    final crop = _positiveNumber(_cropController.text);
    final exposure = focal == null ? null : ruleOf500ExposureSeconds(focalLengthMm: focal, cropFactor: crop ?? 1);
    final width = _positiveNumber(_sensorWidthController.text);
    final height = _positiveNumber(_sensorHeightController.text);
    final frame = width == null || height == null || focal == null
        ? null
        : cameraFrameDegrees(sensorWidthMm: width, sensorHeightMm: height, focalLengthMm: focal);
    final polar = polarAlignmentGuide(currentPlace.value.lat);

    return ListView(
      key: const PageStorageKey('observatory-calculators'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('ابزارهای تازه‌ی نسخه‌ی ۳', style: TextStyle(color: C.muted)),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.blur_circular, color: C.brass), SizedBox(width: 8), Text('تفکیک‌پذیری داوز', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
              const SizedBox(height: 4),
              const Text('حد نظری جداسازی دو ستاره بر حسب ثانیه‌ی قوسی؛ جو و کیفیت اپتیک محدودکننده‌اند.', style: TextStyle(color: C.muted, fontSize: 12, height: 1.4)),
              const SizedBox(height: 8),
              _numberField(_apertureController, 'قطر دهانه (میلی‌متر)', Icons.circle_outlined),
              const SizedBox(height: 8),
              _resultLine('حد نظری', dawes == null ? '—' : '${fa(dawes, 2)} ثانیه‌ی قوسی'),
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.crop_free, color: C.brass), SizedBox(width: 8), Text('میدان دید چشمی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
              const SizedBox(height: 8),
              _numberField(_apparentFieldController, 'میدان ظاهری چشمی (درجه)', Icons.remove_red_eye_outlined),
              const SizedBox(height: 8),
              _numberField(_magnificationController, 'بزرگ‌نمایی', Icons.zoom_in),
              const SizedBox(height: 8),
              _resultLine('میدان واقعی تقریبی', trueField == null ? '—' : '${fa(trueField, 2)}°'),
            ]),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.camera_alt_outlined, color: C.brass), SizedBox(width: 8), Text('قاب‌بندی و نوردهی عکاسی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
              const SizedBox(height: 4),
              const Text('قانون ۵۰۰ فقط یک نقطه‌ی شروع ساده برای رد ستاره‌هاست؛ وضوح، اندازه‌ی پیکسل و ویرایش هم مؤثرند.', style: TextStyle(color: C.muted, fontSize: 12, height: 1.4)),
              const SizedBox(height: 8),
              _numberField(_photoFocalController, 'فاصله‌ی کانونی (میلی‌متر)', Icons.straighten),
              const SizedBox(height: 8),
              _numberField(_cropController, 'ضریب برش دوربین', Icons.aspect_ratio),
              const SizedBox(height: 8),
              _numberField(_sensorWidthController, 'عرض حسگر (میلی‌متر)', Icons.straighten),
              const SizedBox(height: 8),
              _numberField(_sensorHeightController, 'ارتفاع حسگر (میلی‌متر)', Icons.straighten),
              const SizedBox(height: 8),
              _resultLine('حد نوردهی قانون ۵۰۰', exposure == null ? '—' : '${fa(exposure, 1)} ثانیه'),
              if (frame != null) ...[
                const SizedBox(height: 4),
                _resultLine('میدان حسگر (افقی × عمودی)', '${fa(frame.horizontalDegrees, 2)}° × ${fa(frame.verticalDegrees, 2)}°'),
                _resultLine('قطر قاب', '${fa(frame.diagonalDegrees, 2)}°'),
              ],
            ]),
          ),
        ),
        Card(
          color: C.plateLight,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.explore_outlined, color: C.gold), SizedBox(width: 8), Text('راهنمای هم‌راستاسازی قطبی', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
              const SizedBox(height: 8),
              Text('برای ${currentPlace.value.label}: ${polar.hemisphere} · محور قطبی رو به ${polar.truePoleDirection} و با ارتفاع حدود ${fa(polar.polarAxisAltitudeDegrees, 1)}° از افق تنظیم شود.',
                  style: const TextStyle(height: 1.5)),
              const SizedBox(height: 5),
              const Text('۱) سه‌پایه را تراز کن. ۲) جهت شمال/جنوب حقیقی را بیاب. ۳) ارتفاع محور را با عرض جغرافیایی برابر کن. ۴) در صورت نیاز، با روش قطب‌نما/قطبیابی دقیق‌تر کن.',
                  style: TextStyle(color: C.muted, fontSize: 12, height: 1.5)),
              const SizedBox(height: 5),
              const Text('انحراف مغناطیسی در این راهنما اعمال نشده؛ قطب‌نما لزوماً شمال حقیقی را نشان نمی‌دهد.',
                  style: TextStyle(color: C.warning, fontSize: 11, height: 1.4)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label, IconData icon) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: C.muted)),
      );

  Widget _resultLine(String label, String value) => Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: C.muted))),
          Text(value, style: const TextStyle(color: C.gold, fontWeight: FontWeight.bold)),
        ],
      );

  Widget _atmosphereCard() {
    final weather = _weather;
    final place = currentPlace.value;
    final localNow = place.localNow();
    final hours = weather?.tonightHours(localNow) ?? const <HourlySky>[];
    final samples = hours.isEmpty ? (weather?.nextHours(localNow, count: 6) ?? const <HourlySky>[]) : hours;
    if (samples.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_outlined, color: C.brass),
          title: const Text('شفافیت جو و ریسک شبنم'),
          subtitle: Text(_weatherError ?? (_loadingWeather ? 'در حال دریافت پیش‌بینی…' : 'برای برآورد، داده‌ی هوا لازم است.'), style: const TextStyle(color: C.muted)),
          trailing: IconButton(tooltip: 'تلاش دوباره', onPressed: _loadingWeather ? null : _loadWeather, icon: const Icon(Icons.refresh)),
        ),
      );
    }
    double average(double Function(HourlySky hour) value) => samples.map(value).reduce((a, b) => a + b) / samples.length;
    final cloud = average((hour) => hour.cloudPercent);
    final visibility = average((hour) => hour.visibilityMeters);
    final humidity = average((hour) => hour.humidityPercent);
    final temperature = average((hour) => hour.temperatureC);
    final dewPoint = average((hour) => hour.dewPointC);
    final transparency = transparencyIndex(cloudPercent: cloud, visibilityMeters: visibility, humidityPercent: humidity);
    final dew = assessDewRisk(temperatureC: temperature, dewPointC: dewPoint);
    final dewLabel = switch (dew.risk) {
      DewRisk.high => 'زیاد',
      DewRisk.moderate => 'متوسط',
      DewRisk.low => 'کم',
    };
    final dewColor = switch (dew.risk) {
      DewRisk.high => C.red,
      DewRisk.moderate => C.warning,
      DewRisk.low => C.good,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.air, color: C.brass), SizedBox(width: 8), Expanded(child: Text('شفافیت جو و هشدار شبنم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))]),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 5, children: [
            Chip(label: Text('شفافیت ${fa(transparency.round())}/۱۰۰'), avatar: const Icon(Icons.visibility_outlined, size: 16, color: C.brass), visualDensity: VisualDensity.compact),
            Chip(label: Text('ریسک شبنم $dewLabel'), avatar: Icon(Icons.water_drop_outlined, size: 16, color: dewColor), visualDensity: VisualDensity.compact),
          ]),
          Text('فاصله‌ی دما تا نقطه‌ی شبنم ${fa(dew.marginC, 1)}° · میانگین ${fa(samples.length)} بازه‌ی هوا', style: TextStyle(color: dewColor, fontSize: 12)),
          const SizedBox(height: 3),
          const Text('شفافیت، برآوردی از ابر/دید/رطوبت است؛ seeing واقعی از پیش‌بینی عمومی به‌دست نمی‌آید.', style: TextStyle(color: C.muted, fontSize: 10, height: 1.4)),
        ]),
      ),
    );
  }

  double? _positiveNumber(String raw) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var value = raw.trim();
    for (var index = 0; index < 10; index++) {
      value = value.replaceAll(persian[index], '$index').replaceAll(arabic[index], '$index');
    }
    final parsed = double.tryParse(value.replaceAll(',', '.').replaceAll('٫', '.'));
    if (parsed == null || !parsed.isFinite || parsed <= 0 || parsed > 100000) return null;
    return parsed;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _JournalDraft {
  final String targetId;
  final int rating;
  final String note;

  const _JournalDraft(this.targetId, this.rating, this.note);
}
