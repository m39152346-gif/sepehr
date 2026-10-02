import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme.dart';

const _checklistKey = 'observing_checklist_v2';
const _checklistItems = [
  'چراغ‌قوه‌ی قرمز و باتری اضافه',
  'لباس گرم و آب آشامیدنی',
  'سه‌پایه یا دوربین دوچشمی',
  'نقشه‌ی آسمان و مقصد رصد',
  'بررسی ابر، باد و فاز ماه',
];

/// Telescope quick calculator, dark-adaptation timer, and a saved field checklist.
class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  final TextEditingController _aperture = TextEditingController(text: '150');
  final TextEditingController _focalLength = TextEditingController(text: '750');
  final TextEditingController _eyepiece = TextEditingController(text: '10');
  final Map<String, bool> _checked = {for (final item in _checklistItems) item: false};
  Timer? _timer;
  Duration _remaining = const Duration(minutes: 20);
  bool _timerRunning = false;

  double? get _apertureMm => _positiveNumber(_aperture.text);
  double? get _focalMm => _positiveNumber(_focalLength.text);
  double? get _eyepieceMm => _positiveNumber(_eyepiece.text);
  double? get _magnification {
    final focal = _focalMm;
    final eyepiece = _eyepieceMm;
    return focal == null || eyepiece == null ? null : focal / eyepiece;
  }
  double? get _exitPupil {
    final aperture = _apertureMm;
    final magnification = _magnification;
    return aperture == null || magnification == null || magnification == 0 ? null : aperture / magnification;
  }
  double? get _fRatio {
    final aperture = _apertureMm;
    final focal = _focalMm;
    return aperture == null || focal == null || aperture == 0 ? null : focal / aperture;
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((preferences) {
      final saved = preferences.getStringList(_checklistKey) ?? const [];
      if (!mounted) return;
      setState(() {
        for (final item in _checklistItems) {
          _checked[item] = saved.contains(item);
        }
      });
    }).catchError((_) {});
  }

  double? _positiveNumber(String value) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var normalized = value.trim();
    for (var index = 0; index < 10; index++) {
      normalized = normalized.replaceAll(persian[index], '$index').replaceAll(arabic[index], '$index');
    }
    final number = double.tryParse(normalized.replaceAll(',', '.').replaceAll('٫', '.'));
    if (number == null || !number.isFinite || number <= 0 || number > 100000) return null;
    return number;
  }

  void _startTimer() {
    if (_timerRunning) return;
    if (_remaining == Duration.zero) _remaining = const Duration(minutes: 20);
    setState(() => _timerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remaining.inSeconds <= 1) {
        timer.cancel();
        setState(() {
          _remaining = Duration.zero;
          _timerRunning = false;
        });
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _timerRunning = false);
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _timerRunning = false;
      _remaining = const Duration(minutes: 20);
    });
  }

  Future<void> _toggleChecklist(String item, bool checked) async {
    setState(() => _checked[item] = checked);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        _checklistKey,
        _checked.entries.where((entry) => entry.value).map((entry) => entry.key).toList(growable: false),
      );
    } catch (_) {
      // The checklist remains interactive during this session if storage fails.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _aperture.dispose();
    _focalLength.dispose();
    _eyepiece.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final magnification = _magnification;
    final exitPupil = _exitPupil;
    final aperture = _apertureMm;
    final maxUseful = aperture == null ? null : aperture * 2;
    final timerText = '${fa(_remaining.inMinutes).padLeft(2, '۰')}:${fa(_remaining.inSeconds % 60).padLeft(2, '۰')}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        const Text('ابزارهای رصد', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const Text('محاسبه‌گر، سازگاری چشم با تاریکی و چک‌لیست میدانی', style: TextStyle(color: C.muted)),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.zoom_in, color: C.brass), SizedBox(width: 8), Text('محاسبه‌گر تلسکوپ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 6),
                const Text('اعداد را بر حسب میلی‌متر وارد کن.', style: TextStyle(color: C.muted, fontSize: 12)),
                const SizedBox(height: 12),
                _numberField(_aperture, 'قطر دهانه', 'مثلاً ۱۵۰', Icons.circle_outlined),
                const SizedBox(height: 8),
                _numberField(_focalLength, 'فاصله‌ی کانونی تلسکوپ', 'مثلاً ۷۵۰', Icons.straighten),
                const SizedBox(height: 8),
                _numberField(_eyepiece, 'فاصله‌ی کانونی چشمی', 'مثلاً ۱۰', Icons.remove_red_eye_outlined),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _resultChip('بزرگ‌نمایی', magnification == null ? '—' : '${fa(magnification, 1)}×'),
                    _resultChip('مردمک خروجی', exitPupil == null ? '—' : '${fa(exitPupil, 2)} میلی‌متر'),
                    _resultChip('نسبت کانونی', _fRatio == null ? '—' : 'f/${fa(_fRatio!, 1)}'),
                  ],
                ),
                if (magnification != null && maxUseful != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    magnification > maxUseful
                        ? 'این بزرگ‌نمایی از حد تقریبی ${fa(maxUseful)}× برای دهانه‌ی فعلی بیشتر است؛ تصویر احتمالاً تاریک‌تر می‌شود.'
                        : 'حد بزرگ‌نمایی مفید تقریبی: ${fa(maxUseful)}×؛ seeing و کیفیت اپتیک هم مهم‌اند.',
                    style: TextStyle(color: magnification > maxUseful ? C.warning : C.muted, height: 1.4, fontSize: 12),
                  ),
                ],
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
                const Row(children: [Icon(Icons.timer_outlined, color: C.brass), SizedBox(width: 8), Text('تایمر سازگاری چشم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 6),
                const Text('برای حفظ دید شب، ۲۰ دقیقه به چشم فرصت بده و از نور سفید دوری کن.', style: TextStyle(color: C.muted, height: 1.4)),
                const SizedBox(height: 12),
                Center(child: Text(timerText, style: const TextStyle(fontSize: 42, color: C.gold, fontWeight: FontWeight.w900))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: C.brass, foregroundColor: C.night),
                      onPressed: _timerRunning ? _pauseTimer : _startTimer,
                      icon: Icon(_timerRunning ? Icons.pause : Icons.play_arrow),
                      label: Text(_timerRunning ? 'مکث' : _remaining == Duration.zero ? 'شروع دوباره' : 'شروع'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(tooltip: 'شروع از ۲۰ دقیقه', onPressed: _resetTimer, icon: const Icon(Icons.restart_alt, color: C.muted)),
                  ],
                ),
                if (_remaining == Duration.zero) const Center(child: Text('آماده‌ای؛ فقط با نور قرمز از اینجا به بعد.', style: TextStyle(color: C.good))),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [Icon(Icons.checklist, color: C.brass), SizedBox(width: 8), Text('چک‌لیست کیف رصد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]),
                const SizedBox(height: 4),
                for (final item in _checklistItems)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _checked[item] ?? false,
                    activeColor: C.brass,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(item, style: const TextStyle(fontSize: 14)),
                    onChanged: (value) => _toggleChecklist(item, value ?? false),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label, String hint, IconData icon) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon, color: C.muted)),
      );

  Widget _resultChip(String label, String value) => Chip(
        label: Text('$label: $value'),
        backgroundColor: C.night,
        side: BorderSide.none,
      );
}
