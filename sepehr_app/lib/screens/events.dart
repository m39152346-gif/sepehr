import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../core/astro.dart';
import '../core/place.dart';
import '../core/theme.dart';

const _savedEventsKey = 'saved_astronomy_events_v2';

/// Rolling six-month event calendar, with filters and persisted in-app reminders.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  Set<String> _savedIds = <String>{};
  AstroEventKind? _filter;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((preferences) {
      if (!mounted) return;
      setState(() {
        _savedIds = (preferences.getStringList(_savedEventsKey) ?? const []).toSet();
        _loaded = true;
      });
    }).catchError((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  Future<void> _toggle(AstroEvent event) async {
    final wasSaved = _savedIds.contains(event.id);
    final previous = Set<String>.from(_savedIds);
    final updated = Set<String>.from(_savedIds);
    wasSaved ? updated.remove(event.id) : updated.add(event.id);
    setState(() => _savedIds = updated);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_savedEventsKey, updated.toList()..sort());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(wasSaved ? 'نشان رویداد برداشته شد.' : 'رویداد برای یادآوری درون‌برنامه‌ای نشان شد.'),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _savedIds = previous);
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = upcomingEvents(DateTime.now().toUtc(), days: 180);
    final filtered = _filter == null ? events : events.where((event) => event.kind == _filter).toList(growable: false);
    final savedCount = events.where((event) => _savedIds.contains(event.id)).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        const Text('تقویم نجومی', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        Text('رویدادهای تقریبی شش ماه آینده · $savedCount نشان‌شده', style: const TextStyle(color: C.muted)),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('همه', null),
              _filterChip('فازهای ماه', AstroEventKind.moon),
              _filterChip('بارش شهابی', AstroEventKind.meteor),
              _filterChip('فصل‌ها', AstroEventKind.seasonal),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (!_loaded) const LinearProgressIndicator(color: C.brass),
        if (filtered.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('در این دسته رویدادی پیدا نشد.', style: TextStyle(color: C.muted))))
        else
          for (final event in filtered) _eventCard(event),
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('زمان فازهای ماه و اوج بارش‌ها تقریبی است؛ برای رصد نهایی، پیش‌بینی محلی را هم بررسی کن.',
              style: TextStyle(color: C.muted, fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }

  Widget _filterChip(String label, AstroEventKind? value) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
          selectedColor: C.brass.withOpacity(.26),
          labelStyle: TextStyle(color: _filter == value ? C.gold : C.muted),
          side: BorderSide(color: _filter == value ? C.brass : C.plateLight),
        ),
      );

  Widget _eventCard(AstroEvent event) {
    final offset = currentPlace.value.utcOffsetSeconds;
    final localTime = event.dateUtc.add(Duration(seconds: offset));
    final jalali = Jalali.fromDateTime(localTime);
    final nowLocal = currentPlace.value.localNow();
    final daysUntil = DateTime.utc(localTime.year, localTime.month, localTime.day)
        .difference(DateTime.utc(nowLocal.year, nowLocal.month, nowLocal.day))
        .inDays;
    final saved = _savedIds.contains(event.id);
    final icon = switch (event.kind) {
      AstroEventKind.moon => Icons.nightlight_round,
      AstroEventKind.meteor => Icons.auto_awesome,
      AstroEventKind.seasonal => Icons.wb_twilight,
    };
    final kindLabel = switch (event.kind) {
      AstroEventKind.moon => 'ماه',
      AstroEventKind.meteor => 'بارش شهابی',
      AstroEventKind.seasonal => 'فصلی',
    };
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
        leading: CircleAvatar(
          backgroundColor: C.night,
          child: Icon(icon, color: event.kind == AstroEventKind.meteor ? C.gold : C.brass),
        ),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${fa(jalali.day)} ${jalali.formatter.mN} ${fa(jalali.year)} · ${formatLocalClock(localTime)}',
                  style: const TextStyle(color: C.brass, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(event.note, style: const TextStyle(color: C.muted, height: 1.4)),
              const SizedBox(height: 5),
              Text('$kindLabel · ${daysUntil <= 0 ? 'امروز' : '${fa(daysUntil)} روز دیگر'}',
                  style: const TextStyle(color: C.muted, fontSize: 11)),
            ],
          ),
        ),
        trailing: IconButton(
          tooltip: saved ? 'برداشتن نشان' : 'یادآوری درون‌برنامه‌ای',
          onPressed: () => _toggle(event),
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? C.gold : C.muted),
        ),
        isThreeLine: true,
      ),
    );
  }
}
