import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<AppSettings>(
        valueListenable: appSettings,
        builder: (context, settings, _) => Scaffold(
          appBar: AppBar(title: const Text('تنظیمات و دسترس‌پذیری')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              const Text('تجربه‌ی خودت را تنظیم کن', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('تنظیم‌ها روی همین دستگاه ذخیره می‌شوند.', style: TextStyle(color: C.muted)),
              const SizedBox(height: 14),
              Card(
                child: SwitchListTile.adaptive(
                  secondary: Icon(settings.nightVision ? Icons.visibility : Icons.visibility_outlined, color: C.red),
                  title: const Text('حالت دید در شب', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('صفحه را به نور قرمز کم‌اختلال تبدیل می‌کند.', style: TextStyle(color: C.muted)),
                  value: settings.nightVision,
                  activeThumbColor: C.red,
                  onChanged: (value) => updateAppSettings(nightVision: value),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [Icon(Icons.text_fields, color: C.brass), SizedBox(width: 10), Text('اندازه‌ی نوشته', style: TextStyle(fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 6),
                      Text('نمونه‌ی نوشته · ${fa(settings.textScale * 100)}٪', style: const TextStyle(color: C.muted)),
                      Slider(
                        value: settings.textScale,
                        min: .85,
                        max: 1.4,
                        divisions: 11,
                        label: '${fa(settings.textScale * 100)}٪',
                        activeColor: C.brass,
                        onChanged: (value) => updateAppSettings(textScale: value),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [Icon(Icons.thermostat, color: C.brass), SizedBox(width: 10), Text('واحد دما', style: TextStyle(fontWeight: FontWeight.bold))]),
                      const SizedBox(height: 10),
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: false, label: Text('سلسیوس  °C')),
                          ButtonSegment(value: true, label: Text('فارِنهایت  °F')),
                        ],
                        selected: {settings.fahrenheit},
                        onSelectionChanged: (selection) => updateAppSettings(fahrenheit: selection.first),
                      ),
                    ],
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline, color: C.brass),
                  title: const Text('سپهر · نسخهٔ ۲٫۰'),
                  subtitle: const Text('ابزار رصد فارسی · پیش‌بینی‌های نجومی تقریبی هستند.', style: TextStyle(color: C.muted)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: () => updateAppSettings(nightVision: false, fahrenheit: false, textScale: 1),
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('بازگردانی تنظیم‌های پیش‌فرض'),
                ),
              ),
            ],
          ),
        ),
      );
}
