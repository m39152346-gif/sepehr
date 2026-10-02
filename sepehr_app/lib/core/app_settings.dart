import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppSettings {
  final bool nightVision;
  final bool fahrenheit;
  final double textScale;

  const AppSettings({
    this.nightVision = false,
    this.fahrenheit = false,
    this.textScale = 1,
  });

  AppSettings copyWith({bool? nightVision, bool? fahrenheit, double? textScale}) => AppSettings(
        nightVision: nightVision ?? this.nightVision,
        fahrenheit: fahrenheit ?? this.fahrenheit,
        textScale: textScale ?? this.textScale,
      );
}

const _nightVisionKey = 'settings_night_vision_v2';
const _fahrenheitKey = 'settings_fahrenheit_v2';
const _textScaleKey = 'settings_text_scale_v2';

final ValueNotifier<AppSettings> appSettings = ValueNotifier(const AppSettings());

Future<void> loadAppSettings() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    appSettings.value = AppSettings(
      nightVision: preferences.getBool(_nightVisionKey) ?? false,
      fahrenheit: preferences.getBool(_fahrenheitKey) ?? false,
      textScale: (preferences.getDouble(_textScaleKey) ?? 1).clamp(.85, 1.4).toDouble(),
    );
  } catch (_) {
    // Defaults keep startup safe if local preferences cannot be read.
  }
}

Future<void> updateAppSettings({bool? nightVision, bool? fahrenheit, double? textScale}) async {
  final updated = appSettings.value.copyWith(
    nightVision: nightVision,
    fahrenheit: fahrenheit,
    textScale: textScale?.clamp(.85, 1.4).toDouble(),
  );
  appSettings.value = updated;
  try {
    final preferences = await SharedPreferences.getInstance();
    if (nightVision != null) await preferences.setBool(_nightVisionKey, updated.nightVision);
    if (fahrenheit != null) await preferences.setBool(_fahrenheitKey, updated.fahrenheit);
    if (textScale != null) await preferences.setDouble(_textScaleKey, updated.textScale);
  } catch (_) {
    // Settings still apply for this session even if persistence is unavailable.
  }
}

double displayTemperature(double celsius, {required bool fahrenheit}) =>
    fahrenheit ? celsius * 9 / 5 + 32 : celsius;
