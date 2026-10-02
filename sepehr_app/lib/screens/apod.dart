import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../core/api.dart';
import '../core/theme.dart';

/// NASA Astronomy Picture of the Day: browse dates and keep a local favorites shelf.
const _envKey = String.fromEnvironment('NASA_KEY');
const nasaKey = _envKey == '' ? 'DEMO_KEY' : _envKey;
const _favoritesKey = 'apod_favorites_v2';

class ApodScreen extends StatefulWidget {
  final bool active;
  const ApodScreen({super.key, this.active = true});

  @override
  State<ApodScreen> createState() => _ApodScreenState();
}

class _ApodScreenState extends State<ApodScreen> {
  DateTime _date = DateTime.now().toUtc();
  Map<String, dynamic>? _entry;
  List<Map<String, dynamic>> _favorites = const [];
  bool _loading = false;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    if (widget.active) _loadDate(_date);
  }

  @override
  void didUpdateWidget(covariant ApodScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active && _entry == null && !_loading) _loadDate(_date);
  }

  Future<void> _loadFavorites() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final values = preferences.getStringList(_favoritesKey) ?? const [];
      final decoded = <Map<String, dynamic>>[];
      for (final value in values) {
        try {
          final item = jsonDecode(value);
          if (item is Map) decoded.add(Map<String, dynamic>.from(item));
        } catch (_) {
          // Skip a single damaged cache entry.
        }
      }
      if (mounted) setState(() => _favorites = decoded);
    } catch (_) {
      if (mounted) setState(() => _favorites = const []);
    }
  }

  Future<void> _loadDate(DateTime date) async {
    final normalized = DateTime.utc(date.year, date.month, date.day);
    final requestId = ++_requestId;
    setState(() {
      _date = normalized;
      _entry = null;
      _loading = true;
      _error = null;
    });
    try {
      final response = await Api.apod(nasaKey, date: _isoDate(normalized));
      if (!mounted || requestId != _requestId) return;
      setState(() => _entry = response);
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() => _error = 'عکس ناسا دریافت نشد. تاریخ یا اتصال اینترنت را بررسی کن.');
      }
    } finally {
      if (mounted && requestId == _requestId) setState(() => _loading = false);
    }
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now().toUtc();
    final initial = _date.isAfter(now) ? now : _date;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1995, 6, 16),
      lastDate: now,
      helpText: 'تاریخ عکس نجومی را انتخاب کن',
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (selected != null) await _loadDate(selected);
  }

  Future<void> _toggleFavorite() async {
    final entry = _entry;
    if (entry == null) return;
    final date = entry['date']?.toString() ?? _isoDate(_date);
    final updated = [..._favorites];
    final index = updated.indexWhere((item) => item['date']?.toString() == date);
    if (index >= 0) {
      updated.removeAt(index);
    } else {
      updated.insert(0, Map<String, dynamic>.from(entry));
      if (updated.length > 50) updated.removeRange(50, updated.length);
    }
    setState(() => _favorites = updated);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(_favoritesKey, updated.map(jsonEncode).toList(growable: false));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ذخیره‌ی نشان‌ها ممکن نشد.')));
      }
    }
  }

  bool get _isFavorite {
    final date = _entry?['date']?.toString() ?? _isoDate(_date);
    return _favorites.any((item) => item['date']?.toString() == date);
  }

  Future<void> _showFavorites() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: C.plate,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Expanded(child: Text('عکس‌های نشان‌شده', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
              Expanded(
                child: _favorites.isEmpty
                    ? const Center(child: Text('هنوز عکسی نشان نشده است.', style: TextStyle(color: C.muted)))
                    : ListView.builder(
                        itemCount: _favorites.length,
                        itemBuilder: (context, index) {
                          final favorite = _favorites[index];
                          return ListTile(
                            leading: const Icon(Icons.image_outlined, color: C.gold),
                            title: Text(favorite['title']?.toString() ?? 'عکس نجومی', maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(favorite['date']?.toString() ?? '', style: const TextStyle(color: C.muted)),
                            onTap: () => Navigator.pop(context, favorite),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null) return;
    final date = DateTime.tryParse(selected['date']?.toString() ?? '');
    if (date != null) await _loadDate(date);
  }

  @override
  void dispose() {
    _requestId++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final todayUtc = DateTime.now().toUtc();
    final localDate = Jalali.fromDateTime(_date);
    return RefreshIndicator(
      onRefresh: () => _loadDate(_date),
      color: C.brass,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Row(
            children: [
              const Expanded(child: Text('عکس نجومی روز', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
              IconButton(tooltip: 'عکس‌های نشان‌شده', onPressed: _showFavorites, icon: const Icon(Icons.collections_bookmark_outlined, color: C.gold)),
              IconButton(tooltip: 'انتخاب تاریخ', onPressed: _chooseDate, icon: const Icon(Icons.calendar_month, color: C.brass)),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'روز قبل',
                onPressed: _date.isAfter(DateTime.utc(1995, 6, 16)) ? () => _loadDate(_date.subtract(const Duration(days: 1))) : null,
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: Center(
                  child: Text('${fa(localDate.day)} ${localDate.formatter.mN} ${fa(localDate.year)}',
                      style: const TextStyle(color: C.muted, fontWeight: FontWeight.bold)),
                ),
              ),
              IconButton(
                tooltip: 'روز بعد',
                onPressed: _date.isBefore(DateTime.utc(todayUtc.year, todayUtc.month, todayUtc.day))
                    ? () => _loadDate(_date.add(const Duration(days: 1)))
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
          if (_loading && entry == null)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator(color: C.brass))),
          if (_error != null)
            Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off, color: C.warning),
                title: Text(_error!),
                trailing: IconButton(onPressed: () => _loadDate(_date), icon: const Icon(Icons.refresh, color: C.brass)),
              ),
            ),
          if (entry != null) ...[
            if (_loading) const LinearProgressIndicator(color: C.brass, minHeight: 2),
            const SizedBox(height: 8),
            if (entry['media_type'] == 'image' && entry['url'] is String)
              _apodImage(entry['url'].toString(), entry['title']?.toString() ?? '')
            else if (entry['thumbnail_url'] is String)
              _apodVideo(entry['thumbnail_url'].toString(), entry['url']?.toString() ?? '')
            else
              _videoPlaceholder(entry['url']?.toString()),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(entry['title']?.toString() ?? 'بدون عنوان',
                      textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: C.gold)),
                ),
                IconButton(
                  tooltip: _isFavorite ? 'حذف از نشان‌شده‌ها' : 'نشان کردن عکس',
                  onPressed: _toggleFavorite,
                  icon: Icon(_isFavorite ? Icons.bookmark : Icons.bookmark_border, color: C.gold, size: 28),
                ),
              ],
            ),
            if (entry['copyright'] != null)
              Text('© ${entry['copyright']}', textDirection: TextDirection.ltr, style: const TextStyle(color: C.muted, fontSize: 12)),
            const SizedBox(height: 10),
            Text(
              entry['explanation']?.toString() ?? 'توضیحی برای این عکس ثبت نشده است.',
              textDirection: TextDirection.ltr,
              style: const TextStyle(color: C.muted, height: 1.7),
            ),
            if (entry['hdurl'] is String) ...[
              const SizedBox(height: 12),
              SelectableText('نسخه‌ی باکیفیت: ${entry['hdurl']}', textDirection: TextDirection.ltr,
                  style: const TextStyle(color: C.brass, fontSize: 12)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _apodImage(String url, String title) => GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => Dialog.fullscreen(
            backgroundColor: Colors.black,
            child: Stack(
              children: [
                Center(child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain, errorBuilder: _imageError))),
                Positioned(
                  top: 32,
                  right: 12,
                  child: IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'بستن تصویر',
                  ),
                ),
              ],
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              semanticLabel: title,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator(color: C.brass)),
              errorBuilder: _imageError,
            ),
          ),
        ),
      );

  Widget _apodVideo(String thumbnail, String url) => Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Image.network(thumbnail, fit: BoxFit.cover, errorBuilder: _imageError),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: const Icon(Icons.play_arrow, size: 36, color: Colors.white),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black54,
              child: Text('ویدئو در مرورگر: $url', maxLines: 2, overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      );

  Widget _videoPlaceholder(String? url) => Container(
        height: 200,
        decoration: BoxDecoration(color: C.plate, borderRadius: BorderRadius.circular(18)),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.play_circle_outline, color: C.gold, size: 52),
          const SizedBox(height: 8),
          const Text('این روز ویدئوی نجومی دارد.', style: TextStyle(color: C.muted)),
          if (url != null) Padding(padding: const EdgeInsets.all(12), child: SelectableText(url, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, color: C.brass))),
        ])),
      );

  Widget _imageError(BuildContext context, Object error, StackTrace? stackTrace) => Container(
        color: C.plate,
        child: const Center(child: Icon(Icons.broken_image_outlined, color: C.muted, size: 42)),
      );

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
