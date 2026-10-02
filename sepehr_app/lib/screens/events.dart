import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/astro.dart';
import '../core/theme.dart';

/// Astro calendar. Reminders are saved locally.
/// TODO(phase 2): schedule real notifications with flutter_local_notifications.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  Set<String> on = {};

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) => setState(() => on = (p.getStringList('reminders') ?? []).toSet()));
  }

  Future<void> _toggle(String key) async {
    setState(() => on.contains(key) ? on.remove(key) : on.add(key));
    (await SharedPreferences.getInstance()).setStringList('reminders', on.toList());
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('تقویم نجومی', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const Text('برای هرکدوم یادآور بذار', style: TextStyle(color: C.muted)),
      const SizedBox(height: 16),
      for (final e in events)
        Builder(builder: (_) {
          final j = Jalali.fromDateTime(e.date), key = e.date.toIso8601String();
          final active = on.contains(key);
          return Card(color: C.plate, child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            title: Text('${fa(j.day)} ${j.formatter.mN}', style: const TextStyle(color: C.brass, fontSize: 14)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.title, style: const TextStyle(color: C.text, fontSize: 17, fontWeight: FontWeight.bold)),
              Text(e.note, style: const TextStyle(color: C.muted)),
            ]),
            trailing: IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: active ? C.brass : Colors.transparent),
              icon: Icon(active ? Icons.notifications_active : Icons.notifications_none, color: active ? C.night : C.muted),
              onPressed: () => _toggle(key),
            ),
          ));
        }),
    ]);
  }
}
