import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'astro.dart';

/// A small, curated deep-sky catalog. Coordinates are approximate J2000 values;
/// use the app's sky map or a detailed atlas for precise pointing.
class DeepSkyTarget {
  final String id;
  final String catalog;
  final String name;
  final String type;
  final String constellation;
  final double raHours;
  final double decDegrees;
  final double magnitude;
  final int maxUsefulBortle;
  final String description;
  final String hopGuide;

  const DeepSkyTarget({
    required this.id,
    required this.catalog,
    required this.name,
    required this.type,
    required this.constellation,
    required this.raHours,
    required this.decDegrees,
    required this.magnitude,
    required this.maxUsefulBortle,
    required this.description,
    required this.hopGuide,
  });
}

const deepSkyTargets = <DeepSkyTarget>[
  DeepSkyTarget(
    id: 'm31', catalog: 'M31', name: 'کهکشان آندرومدا', type: 'کهکشان',
    constellation: 'آندرومدا', raHours: .712, decDegrees: 41.27, magnitude: 3.4,
    maxUsefulBortle: 6, description: 'کهکشانی مارپیچی و نزدیک‌ترین همسایه‌ی بزرگ راه شیری؛ در آسمان تاریک لکه‌ای کشیده دیده می‌شود.',
    hopGuide: 'از ذات‌الکرسی یا مربع بزرگ اسب بالدار به ستاره‌های زنجیره‌ی آندرومدا برو؛ دوربین دوچشمی میدان بازی نشان می‌دهد.',
  ),
  DeepSkyTarget(
    id: 'm42', catalog: 'M42', name: 'سحابی جبار', type: 'سحابی',
    constellation: 'جبار', raHours: 5.588, decDegrees: -5.39, magnitude: 4.0,
    maxUsefulBortle: 8, description: 'ناحیه‌ی زایش ستاره در شمشیر جبار؛ هدفی روشن برای دوربین دوچشمی و تلسکوپ کوچک.',
    hopGuide: 'سه ستاره‌ی کمربند جبار را پیدا کن و به سمت شمشیر، پایین‌تر از کمربند، نگاه کن.',
  ),
  DeepSkyTarget(
    id: 'm45', catalog: 'M45', name: 'خوشه‌ی پروین', type: 'خوشه‌ی باز',
    constellation: 'ثور', raHours: 3.79, decDegrees: 24.1, magnitude: 1.6,
    maxUsefulBortle: 8, description: 'خوشه‌ای باز و درخشان که با چشم غیرمسلح هم دیده می‌شود؛ میدان دید باز مناسب‌تر است.',
    hopGuide: 'در ثور، به دنبال گروه فشرده‌ی ستاره‌های آبی‌رنگ باشید؛ با بزرگ‌نمایی کم، همه‌ی خوشه را قاب بگیر.',
  ),
  DeepSkyTarget(
    id: 'm13', catalog: 'M13', name: 'خوشه‌ی کروی هرکول', type: 'خوشه‌ی کروی',
    constellation: 'هرکول', raHours: 16.695, decDegrees: 36.46, magnitude: 5.8,
    maxUsefulBortle: 6, description: 'انبوهی کروی از ستارگان؛ در تلسکوپ کوچک لکه‌ای مه‌آلود و در دهانه‌ی بزرگ‌تر دانه‌دانه است.',
    hopGuide: 'در ضلع غربی چهارضلعی هرکول، تقریباً یک‌سوم مسیر میان اتا و زتا هرکول را جست‌وجو کن.',
  ),
  DeepSkyTarget(
    id: 'm57', catalog: 'M57', name: 'سحابی حلقه', type: 'سحابی سیاره‌نما',
    constellation: 'شلیاق', raHours: 18.893, decDegrees: 33.03, magnitude: 8.8,
    maxUsefulBortle: 7, description: 'سحابی کوچک و حلقه‌مانند؛ در بزرگ‌نمایی متوسط بهتر از دوربین دوچشمی دیده می‌شود.',
    hopGuide: 'در صورت فلکی شلیاق، ناحیه‌ی میان ستاره‌های بتا و گاما را با یافت‌گر و بزرگ‌نمایی کم پیدا کن.',
  ),
  DeepSkyTarget(
    id: 'm27', catalog: 'M27', name: 'سحابی دمبل', type: 'سحابی سیاره‌نما',
    constellation: 'روباهک', raHours: 19.993, decDegrees: 22.72, magnitude: 7.5,
    maxUsefulBortle: 7, description: 'سحابی سیاره‌نمای بزرگ و نسبتاً پرنور؛ فیلتر سحابی می‌تواند جزئیات را بهتر کند.',
    hopGuide: 'از پیکان، چند درجه به سمت روباهک حرکت کن؛ در دوربین دوچشمی لکه‌ای کوچک و بی‌ستاره است.',
  ),
  DeepSkyTarget(
    id: 'm81', catalog: 'M81', name: 'کهکشان بود', type: 'کهکشان',
    constellation: 'دب اکبر', raHours: 9.926, decDegrees: 69.07, magnitude: 6.9,
    maxUsefulBortle: 5, description: 'کهکشانی مارپیچی نسبتاً روشن در دب اکبر؛ هسته از بازوها آسان‌تر دیده می‌شود.',
    hopGuide: 'از فک دب اکبر به سمت شمال‌غرب برو؛ دوربین دوچشمی کمک می‌کند جفت M81 و M82 را پیدا کنی.',
  ),
  DeepSkyTarget(
    id: 'm82', catalog: 'M82', name: 'کهکشان سیگار', type: 'کهکشان',
    constellation: 'دب اکبر', raHours: 9.926, decDegrees: 69.68, magnitude: 8.4,
    maxUsefulBortle: 5, description: 'کهکشانی لبه‌نما و کشیده نزدیک M81؛ آسمان تاریک کنتراست آن را بهتر می‌کند.',
    hopGuide: 'همان میدان M81 را جست‌وجو کن؛ M82 لکه‌ای باریک‌تر و کشیده‌تر در کنار آن است.',
  ),
  DeepSkyTarget(
    id: 'm44', catalog: 'M44', name: 'خوشه‌ی کندوی عسل', type: 'خوشه‌ی باز',
    constellation: 'سرطان', raHours: 8.67, decDegrees: 19.67, magnitude: 3.1,
    maxUsefulBortle: 8, description: 'خوشه‌ی باز گسترده؛ دوربین دوچشمی یا چشم غیرمسلح در آسمان تاریک بهترین قاب را می‌دهد.',
    hopGuide: 'از خط میان قلب‌الاسد و کاستور به ناحیه‌ی میانی سرطان برو؛ میدان دید باز استفاده کن.',
  ),
  DeepSkyTarget(
    id: 'm11', catalog: 'M11', name: 'خوشه‌ی اردک وحشی', type: 'خوشه‌ی باز',
    constellation: 'سپر', raHours: 18.851, decDegrees: -6.27, magnitude: 6.3,
    maxUsefulBortle: 6, description: 'خوشه‌ی باز متراکم و غنی؛ در بزرگ‌نمایی متوسط شکل فشرده‌اش آشکار می‌شود.',
    hopGuide: 'صورت فلکی کوچک سپر را میان عقاب و قوس پیدا کن؛ M11 نزدیک ستاره‌ی لامبدا سپر است.',
  ),
  DeepSkyTarget(
    id: 'm8', catalog: 'M8', name: 'سحابی مرداب', type: 'سحابی',
    constellation: 'قوس', raHours: 18.063, decDegrees: -24.38, magnitude: 6.0,
    maxUsefulBortle: 6, description: 'سحابی و خوشه‌ی ستاره‌ای در ناحیه‌ی مرکزی راه شیری؛ در عرض‌های جنوبی‌تر بهتر قرار می‌گیرد.',
    hopGuide: 'از قوری قوس و ناحیه‌ی پرستاره‌ی راه شیری به سمت شمال‌غرب قوس نگاه کن.',
  ),
  DeepSkyTarget(
    id: 'm20', catalog: 'M20', name: 'سحابی سه‌تکه', type: 'سحابی',
    constellation: 'قوس', raHours: 18.043, decDegrees: -23.03, magnitude: 6.3,
    maxUsefulBortle: 5, description: 'سحابی بازتابی و گسیلی کنار M8؛ برای دیدن نوارهای تاریک به آسمان تاریک نیاز دارد.',
    hopGuide: 'در نزدیکی M8 و قوری قوس جست‌وجو کن؛ میدان کم‌نور را با چشم غیرمسلح مستقیم نگاه نکن.',
  ),
  DeepSkyTarget(
    id: 'm51', catalog: 'M51', name: 'کهکشان گرداب', type: 'کهکشان',
    constellation: 'تازی‌ها', raHours: 13.497, decDegrees: 47.2, magnitude: 8.4,
    maxUsefulBortle: 4, description: 'جفت کهکشانی برهم‌کنش‌گر؛ بازوهای مارپیچی فقط زیر آسمان تاریک و با دهانه‌ی مناسب آشکار می‌شوند.',
    hopGuide: 'از انتهای دسته‌ی دب اکبر به سمت جنوب‌غرب برو؛ ابتدا هسته‌ی روشن‌تر را پیدا کن.',
  ),
  DeepSkyTarget(
    id: 'm101', catalog: 'M101', name: 'کهکشان فرفره', type: 'کهکشان',
    constellation: 'دب اکبر', raHours: 14.054, decDegrees: 54.35, magnitude: 7.9,
    maxUsefulBortle: 3, description: 'کهکشانی بزرگ با روشنایی سطحی کم؛ آسمان تاریک از بزرگ‌نمایی زیاد مهم‌تر است.',
    hopGuide: 'از انتهای دسته‌ی دب اکبر چند درجه به سمت شمال‌شرق حرکت کن و میدان را با بزرگ‌نمایی کم بررسی کن.',
  ),
  DeepSkyTarget(
    id: 'ngc869', catalog: 'NGC 869/884', name: 'خوشه‌ی دوتایی برساوش', type: 'خوشه‌ی باز',
    constellation: 'برساوش', raHours: 2.332, decDegrees: 57.13, magnitude: 4.3,
    maxUsefulBortle: 7, description: 'دو خوشه‌ی باز کنار هم؛ منظره‌ی چشمگیری در دوربین دوچشمی و میدان دید عریض.',
    hopGuide: 'بین ذات‌الکرسی و ستاره‌های برساوش، بخش متراکم راه شیری را با دوربین دوچشمی جارو کن.',
  ),
  DeepSkyTarget(
    id: 'm35', catalog: 'M35', name: 'خوشه‌ی باز جوزا', type: 'خوشه‌ی باز',
    constellation: 'جوزا', raHours: 6.148, decDegrees: 24.33, magnitude: 5.3,
    maxUsefulBortle: 7, description: 'خوشه‌ای بزرگ نزدیک پای جوزا؛ خوشه‌ی فشرده‌ی NGC 2158 در همان میدان تلسکوپی دیده می‌شود.',
    hopGuide: 'از کاستور به سمت پای جوزا حرکت کن؛ با میدان کم‌یاب و بزرگ‌نمایی کم شروع کن.',
  ),
  DeepSkyTarget(
    id: 'm104', catalog: 'M104', name: 'کهکشان کلاه مکزیکی', type: 'کهکشان',
    constellation: 'سنبله', raHours: 12.667, decDegrees: -11.62, magnitude: 8.0,
    maxUsefulBortle: 5, description: 'کهکشانی لبه‌نما؛ نوار غبار در دهانه‌ی بزرگ و آسمان آرام آسان‌تر دیده می‌شود.',
    hopGuide: 'در آسمان بهاری، از ستاره‌های روشن کلاغ به سوی مرز سنبله جست‌وجو کن.',
  ),
  DeepSkyTarget(
    id: 'm46', catalog: 'M46', name: 'خوشه‌ی باز کشتی‌دم', type: 'خوشه‌ی باز',
    constellation: 'کشتی‌دم', raHours: 7.697, decDegrees: -14.81, magnitude: 6.1,
    maxUsefulBortle: 6, description: 'خوشه‌ای ستاره‌ای با سحابی سیاره‌نمای NGC 2438 در پیش‌زمینه‌ی ظاهری آن.',
    hopGuide: 'در میدان شمال‌شرق ستاره‌ی سیریوس و صورت فلکی سگ بزرگ، ناحیه‌ی کشتی‌دم را جست‌وجو کن.',
  ),
];

DeepSkyTarget? targetById(String id) {
  for (final target in deepSkyTargets) {
    if (target.id == id) return target;
  }
  return null;
}

class TargetVisibility {
  final AltAz nowPosition;
  final AltAz bestPosition;
  final DateTime bestAtUtc;
  final DateTime? firstWindowStartUtc;
  final DateTime? firstWindowEndUtc;
  final bool windowContinues;

  const TargetVisibility({
    required this.nowPosition,
    required this.bestPosition,
    required this.bestAtUtc,
    required this.firstWindowStartUtc,
    required this.firstWindowEndUtc,
    required this.windowContinues,
  });

  bool get aboveHorizonNow => nowPosition.alt > 0;
  bool get inRecommendedWindowNow => nowPosition.alt >= 20;
  bool get hasRecommendedWindow => firstWindowStartUtc != null;
}

/// Samples a target's horizontal position and its first window above the
/// recommended 20-degree horizon during the requested planning interval.
TargetVisibility targetVisibility(
  DeepSkyTarget target, {
  required double latitude,
  required double longitude,
  required DateTime fromUtc,
  Duration lookAhead = const Duration(hours: 12),
  double minimumAltitude = 20,
  Duration step = const Duration(minutes: 15),
}) {
  final start = fromUtc.toUtc();
  final totalMinutes = lookAhead.inMinutes.clamp(1, 1440).toInt();
  final stepMinutes = step.inMinutes.clamp(1, 180).toInt();
  AltAz positionAt(int minute) => altAz(
        target.raHours,
        target.decDegrees,
        start.add(Duration(minutes: minute)),
        latitude,
        longitude,
      );

  final nowPosition = positionAt(0);
  var bestPosition = nowPosition;
  var bestAt = start;
  var previousPosition = nowPosition;
  var previousMinute = 0;
  DateTime? windowStart = nowPosition.alt >= minimumAltitude ? start : null;
  DateTime? windowEnd;
  var windowContinues = false;

  for (var minute = math.min(stepMinutes, totalMinutes).toInt(); minute <= totalMinutes;) {
    final position = positionAt(minute);
    if (position.alt > bestPosition.alt) {
      bestPosition = position;
      bestAt = start.add(Duration(minutes: minute));
    }
    if (windowStart == null && previousPosition.alt < minimumAltitude && position.alt >= minimumAltitude) {
      windowStart = start.add(Duration(minutes: minute));
    } else if (windowStart != null && windowEnd == null &&
        previousPosition.alt >= minimumAltitude && position.alt < minimumAltitude) {
      windowEnd = start.add(Duration(minutes: previousMinute));
      windowContinues = false;
    }
    previousPosition = position;
    previousMinute = minute;
    if (minute == totalMinutes) break;
    minute = math.min(minute + stepMinutes, totalMinutes).toInt();
  }

  if (windowStart != null && windowEnd == null) {
    windowEnd = start.add(Duration(minutes: totalMinutes));
    windowContinues = true;
  }

  return TargetVisibility(
    nowPosition: nowPosition,
    bestPosition: bestPosition,
    bestAtUtc: bestAt,
    firstWindowStartUtc: windowStart,
    firstWindowEndUtc: windowEnd,
    windowContinues: windowContinues,
  );
}

class TargetOpportunity {
  final DeepSkyTarget target;
  final TargetVisibility visibility;
  final double score;

  const TargetOpportunity(this.target, this.visibility, this.score);
}

/// Sorts targets by horizon, approximate brightness, and suitability for the
/// selected Bortle class. A planning aid, not a guarantee of visibility.
List<TargetOpportunity> rankTonightTargets({
  required double latitude,
  required double longitude,
  required DateTime fromUtc,
  int bortleClass = 5,
  Iterable<DeepSkyTarget> targets = deepSkyTargets,
}) {
  final bortle = bortleClass.clamp(1, 9).toInt();
  final ranked = targets.map((target) {
    final visibility = targetVisibility(
      target,
      latitude: latitude,
      longitude: longitude,
      fromUtc: fromUtc,
    );
    final altitudeScore = ((visibility.bestPosition.alt - 5) / 70).clamp(0.0, 1.0).toDouble();
    final brightnessScore = (1 - target.magnitude / 11).clamp(0.0, 1.0).toDouble();
    final skyPenalty = math.max(0, bortle - target.maxUsefulBortle);
    final skyScore = (1 - skyPenalty * .22).clamp(0.0, 1.0).toDouble();
    final score = (altitudeScore * .62 + brightnessScore * .16 + skyScore * .22) * 100;
    return TargetOpportunity(target, visibility, score);
  }).toList(growable: false);
  ranked.sort((a, b) => b.score.compareTo(a.score));
  return ranked;
}

double estimatedLimitingMagnitude(int bortleClass) {
  final bortle = bortleClass.clamp(1, 9).toInt();
  return (7.6 - (bortle - 1) * .48).clamp(2.5, 7.6).toDouble();
}

double transparencyIndex({
  required double cloudPercent,
  required double visibilityMeters,
  required double humidityPercent,
}) {
  final cloudScore = 1 - cloudPercent.clamp(0.0, 100.0) / 100;
  final visibilityScore = (visibilityMeters / 25000).clamp(0.0, 1.0);
  final humidityScore = 1 - humidityPercent.clamp(0.0, 100.0) / 100;
  return ((cloudScore * .55 + visibilityScore * .30 + humidityScore * .15) * 100)
      .clamp(0.0, 100.0)
      .toDouble();
}

enum DewRisk { low, moderate, high }

class DewAssessment {
  final double marginC;
  final DewRisk risk;
  final bool frostPossible;

  const DewAssessment(this.marginC, this.risk, this.frostPossible);
}

DewAssessment assessDewRisk({required double temperatureC, required double dewPointC}) {
  final margin = temperatureC - dewPointC;
  final risk = margin <= 1.5
      ? DewRisk.high
      : margin <= 3.5
          ? DewRisk.moderate
          : DewRisk.low;
  return DewAssessment(margin, risk, temperatureC <= 0);
}

double? dawesLimitArcsec(double apertureMm) =>
    apertureMm.isFinite && apertureMm > 0 ? 116 / apertureMm : null;

double? trueFieldOfViewDegrees(double apparentFieldDegrees, double magnification) {
  if (!apparentFieldDegrees.isFinite || !magnification.isFinite || apparentFieldDegrees <= 0 || magnification <= 0) return null;
  return apparentFieldDegrees / magnification;
}

class CameraFrame {
  final double horizontalDegrees;
  final double verticalDegrees;
  final double diagonalDegrees;

  const CameraFrame(this.horizontalDegrees, this.verticalDegrees, this.diagonalDegrees);
}

CameraFrame? cameraFrameDegrees({
  required double sensorWidthMm,
  required double sensorHeightMm,
  required double focalLengthMm,
}) {
  if (![sensorWidthMm, sensorHeightMm, focalLengthMm].every((value) => value.isFinite && value > 0)) return null;
  double angle(double sensor) => 2 * math.atan(sensor / (2 * focalLengthMm)) * 180 / math.pi;
  final horizontal = angle(sensorWidthMm);
  final vertical = angle(sensorHeightMm);
  final diagonal = angle(math.sqrt(sensorWidthMm * sensorWidthMm + sensorHeightMm * sensorHeightMm));
  return CameraFrame(horizontal, vertical, diagonal);
}

double? ruleOf500ExposureSeconds({required double focalLengthMm, double cropFactor = 1}) {
  if (!focalLengthMm.isFinite || !cropFactor.isFinite || focalLengthMm <= 0 || cropFactor <= 0) return null;
  return 500 / (focalLengthMm * cropFactor);
}

class PolarAlignmentGuide {
  final String hemisphere;
  final String truePoleDirection;
  final double polarAxisAltitudeDegrees;

  const PolarAlignmentGuide(this.hemisphere, this.truePoleDirection, this.polarAxisAltitudeDegrees);
}

PolarAlignmentGuide polarAlignmentGuide(double latitude) {
  final safeLatitude = latitude.clamp(-90.0, 90.0).toDouble();
  final north = safeLatitude >= 0;
  return PolarAlignmentGuide(
    north ? 'نیم‌کره‌ی شمالی' : 'نیم‌کره‌ی جنوبی',
    north ? 'شمال حقیقی' : 'جنوب حقیقی',
    safeLatitude.abs(),
  );
}

const defaultGearItems = <String>[
  'تلسکوپ یا دوربین دوچشمی',
  'سه‌پایه و هد',
  'چشمی‌ها و بارلو',
  'چراغ قرمز و باتری اضافه',
  'پاوربانک و کابل شارژ',
  'دفترچه و مداد',
  'لباس گرم و آب آشامیدنی',
  'دوربین، ریموت و کارت حافظه',
];

class GearChecklist {
  final List<String> items;
  final Set<String> checked;

  GearChecklist({required List<String> items, required Set<String> checked})
      : items = List.unmodifiable(items),
        checked = Set.unmodifiable(checked);

  factory GearChecklist.defaults() => GearChecklist(items: defaultGearItems, checked: const {});
}

const _bortleByPlaceKey = 'observatory_bortle_by_place_v3';
const _planKey = 'observatory_plan_v3';
const _gearKey = 'observatory_gear_v3';
const _journalKey = 'observatory_journal_v3';

Future<int> loadBortleForPlace(String placeKey) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_bortleByPlaceKey);
    if (raw == null) return 5;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return 5;
    final value = decoded[placeKey];
    return value is num ? value.round().clamp(1, 9).toInt() : 5;
  } catch (_) {
    return 5;
  }
}

Future<void> saveBortleForPlace(String placeKey, int bortleClass) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_bortleByPlaceKey);
    final decoded = raw == null ? <String, dynamic>{} : jsonDecode(raw);
    final values = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    values[placeKey] = bortleClass.clamp(1, 9);
    await preferences.setString(_bortleByPlaceKey, jsonEncode(values));
  } catch (_) {
    // The selected sky class still works for the current screen session.
  }
}

Future<List<String>> loadObservingPlan() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final allowedIds = deepSkyTargets.map((target) => target.id).toSet();
    final stored = preferences.getStringList(_planKey) ?? const [];
    return List.unmodifiable(stored.where(allowedIds.contains).toSet());
  } catch (_) {
    return const [];
  }
}

Future<void> saveObservingPlan(List<String> targetIds) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final allowedIds = deepSkyTargets.map((target) => target.id).toSet();
    final cleaned = targetIds.where(allowedIds.contains).toSet().toList(growable: false);
    await preferences.setStringList(_planKey, cleaned);
  } catch (_) {
    // Keep planning available even if preferences are temporarily unavailable.
  }
}

Future<GearChecklist> loadGearChecklist() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_gearKey);
    if (raw == null) return GearChecklist.defaults();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return GearChecklist.defaults();
    final storedItems = decoded['items'];
    final storedChecked = decoded['checked'];
    final items = <String>{
      ...defaultGearItems,
      if (storedItems is List) ...storedItems.whereType<String>().map((item) => item.trim()).where((item) => item.isNotEmpty && item.length <= 80),
    }.toList(growable: false);
    final checked = storedChecked is List
        ? storedChecked.whereType<String>().where(items.contains).toSet()
        : <String>{};
    return GearChecklist(items: items, checked: checked);
  } catch (_) {
    return GearChecklist.defaults();
  }
}

Future<void> saveGearChecklist(GearChecklist checklist) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final checked = checklist.checked.where(checklist.items.contains).toList(growable: false);
    await preferences.setString(_gearKey, jsonEncode({'items': checklist.items, 'checked': checked}));
  } catch (_) {
    // Equipment choices remain usable for the current session.
  }
}

class ObservationLogEntry {
  final String id;
  final String targetId;
  final String targetName;
  final DateTime observedAtUtc;
  final int utcOffsetSeconds;
  final int durationMinutes;
  final int rating;
  final String note;

  const ObservationLogEntry({
    required this.id,
    required this.targetId,
    required this.targetName,
    required this.observedAtUtc,
    this.utcOffsetSeconds = 0,
    required this.durationMinutes,
    required this.rating,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'targetId': targetId,
        'targetName': targetName,
        'observedAtUtc': observedAtUtc.toUtc().toIso8601String(),
        'utcOffsetSeconds': utcOffsetSeconds,
        'durationMinutes': durationMinutes,
        'rating': rating,
        'note': note,
      };

  factory ObservationLogEntry.fromJson(Map<String, dynamic> json) {
    final observedAt = DateTime.tryParse(json['observedAtUtc']?.toString() ?? '');
    final targetName = json['targetName']?.toString().trim() ?? '';
    if (observedAt == null || targetName.isEmpty) throw const FormatException('ثبت رصد ناقص است');
    return ObservationLogEntry(
      id: json['id']?.toString() ?? observedAt.microsecondsSinceEpoch.toString(),
      targetId: json['targetId']?.toString() ?? '',
      targetName: targetName,
      observedAtUtc: observedAt.toUtc(),
      utcOffsetSeconds: (json['utcOffsetSeconds'] is num ? (json['utcOffsetSeconds'] as num).round() : 0).clamp(-43200, 50400).toInt(),
      durationMinutes: (json['durationMinutes'] is num ? (json['durationMinutes'] as num).round() : 0).clamp(0, 1440).toInt(),
      rating: (json['rating'] is num ? (json['rating'] as num).round() : 3).clamp(1, 5).toInt(),
      note: json['note']?.toString() ?? '',
    );
  }
}

Future<List<ObservationLogEntry>> loadObservationJournal() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final values = preferences.getStringList(_journalKey) ?? const [];
    final entries = <ObservationLogEntry>[];
    for (final value in values) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) entries.add(ObservationLogEntry.fromJson(Map<String, dynamic>.from(decoded)));
      } catch (_) {
        // Ignore a damaged row without losing the rest of the journal.
      }
    }
    entries.sort((a, b) => b.observedAtUtc.compareTo(a.observedAtUtc));
    return List.unmodifiable(entries);
  } catch (_) {
    return const [];
  }
}

Future<void> addObservationJournalEntry(ObservationLogEntry entry) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final current = await loadObservationJournal();
    final updated = [entry, ...current.where((item) => item.id != entry.id)].take(200);
    await preferences.setStringList(_journalKey, updated.map((item) => jsonEncode(item.toJson())).toList(growable: false));
  } catch (_) {
    // Preserve the in-memory entry in the UI if local storage is unavailable.
  }
}

Future<void> removeObservationJournalEntry(String id) async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final current = await loadObservationJournal();
    final updated = current.where((item) => item.id != id).map((item) => jsonEncode(item.toJson())).toList(growable: false);
    await preferences.setStringList(_journalKey, updated);
  } catch (_) {
    // Deletion can be retried if preferences are unavailable.
  }
}

String formatJournalExport(List<ObservationLogEntry> entries, {int? utcOffsetSeconds}) {
  const digits = '۰۱۲۳۴۵۶۷۸۹';
  String persianDigits(String value) => value.replaceAllMapped(RegExp(r'\d'), (match) => digits[int.parse(match.group(0)!)]);
  if (entries.isEmpty) return 'دفترچه‌ی رصد سپهر ۳\nهنوز رصدی ثبت نشده است.';
  final lines = <String>['دفترچه‌ی رصد سپهر ۳', ''];
  for (final entry in entries) {
    final local = entry.observedAtUtc.toUtc().add(Duration(seconds: utcOffsetSeconds ?? entry.utcOffsetSeconds));
    final date = "${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}";
    final time = "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
    lines.add('• ${entry.targetName} · ${persianDigits(date)} ${persianDigits(time)}');
    lines.add('  مدت: ${persianDigits(entry.durationMinutes.toString())} دقیقه · امتیاز: ${persianDigits(entry.rating.toString())}/۵');
    if (entry.note.trim().isNotEmpty) lines.add('  یادداشت: ${entry.note.trim()}');
    lines.add('');
  }
  return lines.join('\n').trimRight();
}
