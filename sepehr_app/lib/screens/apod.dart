import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

/// NASA Astronomy Picture of the Day.
/// Key comes from the build: `flutter build apk --dart-define=NASA_KEY=xxx`
/// (in GitHub Actions it's read from the repository secret NASA_KEY). Falls back to DEMO_KEY.
const _envKey = String.fromEnvironment('NASA_KEY');
const nasaKey = _envKey == '' ? 'DEMO_KEY' : _envKey;

class ApodScreen extends StatefulWidget {
  const ApodScreen({super.key});
  @override
  State<ApodScreen> createState() => _ApodScreenState();
}

class _ApodScreenState extends State<ApodScreen> {
  late Future<Map<String, dynamic>> future = _load();

  Future<Map<String, dynamic>> _load() async {
    return Api.apod(nasaKey);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: TextButton(onPressed: () => setState(() => future = _load()), child: const Text('خطا در دریافت، دوباره امتحان کن')));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: C.brass));
        final d = snap.data!;
        final isImage = d['media_type'] == 'image';
        return ListView(padding: const EdgeInsets.all(20), children: [
          const Text('عکس نجومی روز', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          Text('از ناسا · ${d['date'] ?? ''}', style: const TextStyle(color: C.muted)),
          const SizedBox(height: 16),
          if (isImage) ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.network(d['url'], fit: BoxFit.cover)),
          const SizedBox(height: 16),
          Text(d['title'] ?? '', textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: C.gold)),
          const SizedBox(height: 8),
          Text(d['explanation'] ?? '', textDirection: TextDirection.ltr, style: const TextStyle(color: C.muted, height: 1.6)),
        ]);
      },
    );
  }
}
