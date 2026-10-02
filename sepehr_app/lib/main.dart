import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/app_settings.dart';
import 'core/place.dart';
import 'core/theme.dart';
import 'screens/apod.dart';
import 'screens/events.dart';
import 'screens/iss.dart';
import 'screens/location_picker.dart';
import 'screens/quiz.dart';
import 'screens/settings.dart';
import 'screens/sky_map.dart';
import 'screens/tonight.dart';
import 'screens/tools.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([loadSavedPlace(), loadAppSettings()]);
  runApp(const SepehrApp());
}

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
  int _tab = 0;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppSettings>(
        valueListenable: appSettings,
        builder: (context, settings, _) => MaterialApp(
          title: 'سپهر',
          debugShowCheckedModeBanner: false,
          locale: const Locale('fa'),
          supportedLocales: const [Locale('fa')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildTheme(),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            Widget content = MediaQuery(
              data: media.copyWith(textScaler: TextScaler.linear(settings.textScale)),
              child: Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox.shrink()),
            );
            if (settings.nightVision) {
              content = ColorFiltered(colorFilter: const ColorFilter.matrix(_nightMatrix), child: content);
            }
            return content;
          },
          home: ValueListenableBuilder<Place>(
            valueListenable: currentPlace,
            builder: (context, place, _) => _home(place, settings),
          ),
        ),
      );

  Widget _home(Place place, AppSettings settings) {
    final pages = <Widget>[
      TonightScreen(onOpenSky: () => setState(() => _tab = 1)),
      SkyMapScreen(key: ValueKey('sky-${place.lat}-${place.lon}')),
      IssScreen(active: _tab == 2),
      ApodScreen(active: _tab == 3),
      const EventsScreen(),
      const QuizScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('سپهر', style: TextStyle(color: C.brass, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: 'مکان رصد · ${place.label}',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LocationPicker())),
            icon: const Icon(Icons.place, color: C.gold),
          ),
          IconButton(
            tooltip: 'ابزارهای رصد',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ToolsScreen())),
            icon: const Icon(Icons.build_circle_outlined, color: C.muted),
          ),
          IconButton(
            tooltip: 'تنظیمات و دسترس‌پذیری',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.tune, color: C.muted),
          ),
          IconButton(
            tooltip: settings.nightVision ? 'خاموش کردن دید در شب' : 'روشن کردن دید در شب',
            icon: Icon(settings.nightVision ? Icons.visibility : Icons.visibility_outlined, color: settings.nightVision ? C.red : C.muted),
            onPressed: () => updateAppSettings(nightVision: !settings.nightVision),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (index) => setState(() => _tab = index),
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
  }
}
