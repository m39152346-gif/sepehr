import 'package:flutter/material.dart';
import 'core/place.dart';
import 'core/theme.dart';
import 'screens/location_picker.dart';
import 'screens/tonight.dart';
import 'screens/sky_map.dart';
import 'screens/iss.dart';
import 'screens/apod.dart';
import 'screens/events.dart';
import 'screens/quiz.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSavedPlace();
  runApp(const SepehrApp());
}

// Grayscale then multiply red: real "night vision" mode astronomers use.
const _nightMatrix = <double>[
  .30, .59, .11, 0, 0,
  0, 0, 0, 0, 0,
  0, 0, 0, 0, 0,
  0, 0, 0, 1, 0,
];

class SepehrApp extends StatefulWidget {
  const SepehrApp({super.key});
  @override
  State<SepehrApp> createState() => _SepehrAppState();
}

class _SepehrAppState extends State<SepehrApp> {
  int tab = 0;
  bool night = false;

  @override
  Widget build(BuildContext context) {
    // Rebuild everything when the user picks another city.
    return ValueListenableBuilder<Place>(valueListenable: currentPlace, builder: (context, place, _) => _build(place));
  }

  Widget _build(Place place) {
    final pages = [TonightScreen(onOpenSky: () => setState(() => tab = 1)), SkyMapScreen(key: ValueKey('sky-${place.lat}-${place.lon}')), const IssScreen(), const ApodScreen(), const EventsScreen(), const QuizScreen()];
    final app = Scaffold(
      appBar: AppBar(
        backgroundColor: C.night,
        title: const Text('سپهر', style: TextStyle(color: C.brass, fontWeight: FontWeight.w900)),
        actions: [
          Builder(builder: (ctx) => TextButton.icon(
            onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const LocationPicker())),
            icon: const Icon(Icons.place, color: C.gold, size: 18),
            label: Text(place.name, style: const TextStyle(color: C.gold)),
          )),
          IconButton(
            tooltip: 'دید در شب',
            icon: Icon(night ? Icons.visibility : Icons.visibility_outlined, color: night ? C.red : C.muted),
            onPressed: () => setState(() => night = !night),
          ),
        ],
      ),
      body: IndexedStack(index: tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.nightlight_round), label: 'امشب'),
          NavigationDestination(icon: Icon(Icons.explore), label: 'آسمان'),
          NavigationDestination(icon: Icon(Icons.satellite_alt), label: 'ISS'),
          NavigationDestination(icon: Icon(Icons.image), label: 'عکس روز'),
          NavigationDestination(icon: Icon(Icons.event), label: 'رویدادها'),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'کوییز'),
        ],
      ),
    );
    return MaterialApp(
      title: 'سپهر',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: night ? ColorFiltered(colorFilter: const ColorFilter.matrix(_nightMatrix), child: app) : app,
    );
  }
}
