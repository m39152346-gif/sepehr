import 'dart:math';

const double _rad = pi / 180;
const double _deg = 180 / pi;
const double _synodicMonth = 29.530588853;
const double _newMoonEpochJd = 2451550.1; // 2000-01-06, approximate new moon

double julianDay(DateTime time) =>
    time.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;

DateTime _dateFromJulianDay(double day) => DateTime.fromMillisecondsSinceEpoch(
      ((day - 2440587.5) * 86400000).round(),
      isUtc: true,
    );

class AltAz {
  final double alt;
  final double az;
  const AltAz(this.alt, this.az);
}

/// Convert right ascension (hours) and declination (degrees) to local
/// altitude/azimuth for an absolute moment and a WGS84 observer latitude/longitude.
AltAz altAz(double raHours, double decDegrees, DateTime time, double latitude, double longitude) {
  final days = julianDay(time) - 2451545.0;
  final gmst = (18.697374558 + 24.06570982441908 * days) % 24;
  final localSidereal = ((gmst + longitude / 15) % 24 + 24) % 24;
  final hourAngle = ((localSidereal - raHours) % 24) * 15 * _rad;
  final declination = decDegrees.clamp(-90.0, 90.0) * _rad;
  final observerLatitude = latitude.clamp(-90.0, 90.0) * _rad;

  final sinAltitude = (sin(declination) * sin(observerLatitude) +
          cos(declination) * cos(observerLatitude) * cos(hourAngle))
      .clamp(-1.0, 1.0);
  final altitude = asin(sinAltitude);
  final cosAltitude = cos(altitude);

  // Azimuth is undefined at the zenith/nadir. Returning north there avoids
  // a divide-by-zero while keeping the horizon transform stable at the poles.
  if (cosAltitude.abs() < 1e-10) return AltAz(altitude * _deg, 0);
  final sinAzimuth = -cos(declination) * sin(hourAngle) / cosAltitude;
  final cosAzimuth =
      (sin(declination) - sinAltitude * sin(observerLatitude)) /
          (cosAltitude * cos(observerLatitude)).abs().clamp(1e-10, 1.0) *
          (cosAltitude * cos(observerLatitude) < 0 ? -1 : 1);
  final azimuth = (atan2(sinAzimuth, cosAzimuth) * _deg + 360) % 360;
  return AltAz(altitude * _deg, azimuth);
}

class MoonInfo {
  final double age;
  final double illumination;
  final String phaseName;
  const MoonInfo(this.age, this.illumination, this.phaseName);
}

MoonInfo moonInfo(DateTime time) {
  final age = ((julianDay(time) - _newMoonEpochJd) / _synodicMonth % 1 + 1) % 1;
  final illumination = (1 - cos(2 * pi * age)) / 2;
  const names = [
    'ماه نو',
    'هلال افزاینده',
    'تربیع اول',
    'کوژ افزاینده',
    'بدر کامل',
    'کوژ کاهنده',
    'تربیع آخر',
    'هلال کاهنده',
  ];
  return MoonInfo(age, illumination, names[((age * 8 + .5).floor()) % 8]);
}

enum MoonPhase {
  newMoon('ماه نو', 0),
  firstQuarter('تربیع اول', .25),
  fullMoon('ماه کامل', .5),
  lastQuarter('تربیع آخر', .75);

  final String label;
  final double fraction;
  const MoonPhase(this.label, this.fraction);
}

class MoonPhaseMoment {
  final DateTime dateUtc;
  final MoonPhase phase;
  const MoonPhaseMoment(this.dateUtc, this.phase);
}

/// Approximate upcoming quarter/new/full-moon times using the mean synodic month.
/// The error is normally several hours; this is for planning, not an ephemeris.
List<MoonPhaseMoment> upcomingMoonPhases(DateTime from, {int count = 12}) {
  if (count <= 0) return const [];
  final nowJd = julianDay(from);
  final candidates = <MoonPhaseMoment>[];
  final cyclesToGenerate = (count / MoonPhase.values.length).ceil() + 2;
  for (final phase in MoonPhase.values) {
    var cycle = ((nowJd - _newMoonEpochJd) / _synodicMonth - phase.fraction).floor() + 1;
    for (var guard = 0; guard < cyclesToGenerate; guard++, cycle++) {
      final jd = _newMoonEpochJd + (cycle + phase.fraction) * _synodicMonth;
      if (jd < nowJd - 1e-9) continue;
      candidates.add(MoonPhaseMoment(_dateFromJulianDay(jd), phase));
    }
  }
  candidates.sort((a, b) => a.dateUtc.compareTo(b.dateUtc));
  return candidates.take(count).toList(growable: false);
}

enum AstroEventKind { moon, meteor, seasonal }

class AstroEvent {
  final DateTime dateUtc;
  final String title;
  final String note;
  final AstroEventKind kind;
  final String id;

  const AstroEvent({
    required this.dateUtc,
    required this.title,
    required this.note,
    required this.kind,
    required this.id,
  });
}

/// Build a rolling event list so the calendar never goes stale after a year.
/// Meteor-shower peak dates are approximate annual dates; moon phases use a
/// mean-lunation model, and are clearly labelled as estimates in the UI.
List<AstroEvent> upcomingEvents(DateTime from, {int days = 180}) {
  final start = from.toUtc();
  final end = start.add(Duration(days: days < 1 ? 1 : days));
  final out = <AstroEvent>[];
  for (final phase in upcomingMoonPhases(start, count: days ~/ 7 + 8)) {
    if (phase.dateUtc.isAfter(end)) continue;
    final key = phase.dateUtc.toIso8601String().substring(0, 10);
    out.add(AstroEvent(
      dateUtc: phase.dateUtc,
      title: phase.phase.label,
      note: 'زمان تقریبی بر پایه‌ی چرخه‌ی ماه؛ برای برنامه‌ریزی رصد',
      kind: AstroEventKind.moon,
      id: 'moon-${phase.phase.name}-$key',
    ));
  }

  const showers = <(int, int, String, String)>[
    (1, 3, 'شلیاقی', 'اوج تقریبی بارش شهابی شلیاقی؛ بهترین رصد پس از نیمه‌شب'),
    (5, 6, 'اتا-دلوی', 'اوج تقریبی بارش اتا-دلوی؛ آسمان پیش از سپیده‌دم را بررسی کن'),
    (8, 12, 'برساوشی', 'اوج تقریبی بارش برساوشی؛ از نور شهر دور شو'),
    (10, 21, 'جباری', 'اوج تقریبی بارش جباری؛ صورت فلکی جبار را پیدا کن'),
    (11, 17, 'اسدی', 'اوج تقریبی بارش اسدی؛ شرایط ماه و ابر را بررسی کن'),
    (12, 14, 'جوزایی', 'اوج تقریبی بارش جوزایی؛ یکی از پربارترین بارش‌های سال'),
  ];
  for (var year = start.year; year <= end.year; year++) {
    for (final shower in showers) {
      final date = DateTime.utc(year, shower.$1, shower.$2, 20);
      if (date.isBefore(start) || date.isAfter(end)) continue;
      out.add(AstroEvent(
        dateUtc: date,
        title: 'بارش شهابی ${shower.$3}',
        note: shower.$4,
        kind: AstroEventKind.meteor,
        id: 'meteor-${shower.$3}-$year',
      ));
    }
    const seasons = <(int, int, String, String)>[
      (3, 20, 'اعتدال بهاری', 'شب و روز تقریباً هم‌طول می‌شوند؛ تاریخ دقیق می‌تواند یک روز جابه‌جا شود.'),
      (6, 21, 'انقلاب تابستانی', 'بلندترین روز سال در نیم‌کره‌ی شمالی؛ زمان تقریبی.'),
      (9, 22, 'اعتدال پاییزی', 'شب و روز تقریباً هم‌طول می‌شوند؛ تاریخ تقریبی.'),
      (12, 21, 'انقلاب زمستانی', 'کوتاه‌ترین روز سال در نیم‌کره‌ی شمالی؛ زمان تقریبی.'),
    ];
    for (final season in seasons) {
      final date = DateTime.utc(year, season.$1, season.$2, 12);
      if (date.isBefore(start) || date.isAfter(end)) continue;
      out.add(AstroEvent(
        dateUtc: date,
        title: season.$3,
        note: season.$4,
        kind: AstroEventKind.seasonal,
        id: 'season-${season.$3}-$year',
      ));
    }
  }
  out.sort((a, b) => a.dateUtc.compareTo(b.dateUtc));
  return out;
}

class Star {
  final String id;
  final String name;
  final double ra;
  final double dec;
  final double magnitude;
  const Star(this.id, this.name, this.ra, this.dec, this.magnitude);
}

const stars = <Star>[
  Star('betelgeuse', 'ابط‌الجوزا', 5.919, 7.41, .5),
  Star('rigel', 'رجل‌الجبار', 5.242, -8.2, .13),
  Star('bellatrix', 'بلاتریکس', 5.418, 6.35, 1.6),
  Star('saiph', 'سیف', 5.796, -9.67, 2.1),
  Star('alnitak', 'نطاق', 5.679, -1.94, 1.7),
  Star('alnilam', 'نظام', 5.604, -1.2, 1.7),
  Star('mintaka', 'منطقه', 5.533, -.3, 2.2),
  Star('dubhe', 'دبه', 11.062, 61.75, 1.8),
  Star('merak', 'مراق', 11.031, 56.38, 2.4),
  Star('phecda', 'فخذ', 11.897, 53.69, 2.4),
  Star('megrez', 'مغرز', 12.257, 57.03, 3.3),
  Star('alioth', 'عناق', 12.9, 55.96, 1.8),
  Star('mizar', 'مئزر', 13.399, 54.93, 2.2),
  Star('alkaid', 'قائد بنات نعش', 13.792, 49.31, 1.9),
  Star('caph', 'کف', .153, 59.15, 2.3),
  Star('schedar', 'صدر', .675, 56.54, 2.2),
  Star('gcas', 'گاما ذات‌الکرسی', .945, 60.72, 2.4),
  Star('ruchbah', 'رکبه', 1.43, 60.24, 2.7),
  Star('segin', 'سگین', 1.907, 63.67, 3.4),
  Star('deneb', 'ذنب‌الدجاجه', 20.69, 45.28, 1.25),
  Star('sadr', 'صدرالدجاجه', 20.37, 40.26, 2.2),
  Star('gienah', 'جناح', 20.77, 33.97, 2.5),
  Star('dcyg', 'دلتا دجاجه', 19.75, 45.13, 2.9),
  Star('albireo', 'اُلبیرو', 19.512, 27.96, 3.1),
  Star('vega', 'نسر واقع', 18.616, 38.78, .03),
  Star('altair', 'نسر طائر', 19.846, 8.87, .77),
  Star('polaris', 'ستاره قطبی', 2.53, 89.26, 2),
  Star('antares', 'قلب‌العقرب', 16.49, -26.43, 1),
  Star('aldebaran', 'دبران', 4.599, 16.51, .85),
  Star('pleiades', 'پروین', 3.79, 24.1, 1.6),
  Star('sirius', 'شباهنگ', 6.752, -16.72, -1.46),
  Star('procyon', 'شعرای شامی', 7.655, 5.22, .34),
  Star('capella', 'عیوق', 5.278, 46, .08),
  Star('arcturus', 'سماک رامح', 14.261, 19.18, -.05),
  Star('spica', 'سماک اعزل', 13.42, -11.16, 1),
  Star('regulus', 'قلب‌الاسد', 10.14, 11.97, 1.4),
  Star('pollux', 'رأس‌التوأم', 7.755, 28.03, 1.14),
  Star('castor', 'کاستور', 7.577, 31.89, 1.6),
  Star('fomalhaut', 'فم‌الحوت', 22.961, -29.62, 1.16),
  Star('markab', 'مرکب', 23.079, 15.21, 2.5),
  Star('scheat', 'سعد', 23.063, 28.08, 2.4),
  Star('algenib', 'جنب', .221, 15.18, 2.8),
  Star('alpheratz', 'سُرّه‌الفرس', .14, 29.09, 2.1),
  Star('procyon_b', 'مرزم', 7.139, 5.2, 2.7),
  Star('canopus', 'سهیل', 6.399, -52.7, -.74),
  Star('achernar', 'آخرالنهر', 1.629, -57.2, .46),
  Star('miaplacidus', 'میاپلاسیدوس', 9.22, -69.7, 1.67),
  Star('denebola', 'ذنب‌الاسد', 11.818, 14.57, 2.14),
  Star('kochab', 'کوکب', 14.845, 74.16, 2.08),
  Star('rasalhague', 'رأس‌الحواء', 17.582, 12.56, 2.08),
  Star('enif', 'انف', 21.736, 9.88, 2.4),
];

const constellationLines = <List<String>>[
  ['betelgeuse', 'bellatrix'], ['betelgeuse', 'alnitak'], ['bellatrix', 'mintaka'],
  ['alnitak', 'alnilam'], ['alnilam', 'mintaka'], ['alnitak', 'saiph'], ['mintaka', 'rigel'],
  ['dubhe', 'merak'], ['merak', 'phecda'], ['phecda', 'megrez'], ['megrez', 'dubhe'],
  ['megrez', 'alioth'], ['alioth', 'mizar'], ['mizar', 'alkaid'],
  ['caph', 'schedar'], ['schedar', 'gcas'], ['gcas', 'ruchbah'], ['ruchbah', 'segin'],
  ['deneb', 'sadr'], ['sadr', 'albireo'], ['dcyg', 'sadr'], ['sadr', 'gienah'],
  ['markab', 'scheat'], ['scheat', 'alpheratz'], ['alpheratz', 'algenib'], ['algenib', 'markab'],
  ['vega', 'deneb'], ['deneb', 'altair'], ['altair', 'vega'],
];

class SatelliteLook {
  final double groundDistanceKm;
  final double elevationDegrees;
  final double centralAngleDegrees;
  final double bearingDegrees;
  const SatelliteLook(this.groundDistanceKm, this.elevationDegrees, this.centralAngleDegrees, this.bearingDegrees);

  bool get aboveGeometricHorizon => elevationDegrees > 0;
}

/// Topocentric look angle for a satellite's subpoint and orbital altitude.
/// It only estimates geometric visibility; weather, sunlight and obstructions matter too.
SatelliteLook satelliteLook({
  required double observerLatitude,
  required double observerLongitude,
  required double satelliteLatitude,
  required double satelliteLongitude,
  required double altitudeKm,
}) {
  const earthRadiusKm = 6371.0;
  final lat1 = observerLatitude * _rad;
  final lat2 = satelliteLatitude * _rad;
  final deltaLat = (satelliteLatitude - observerLatitude) * _rad;
  final deltaLon = (satelliteLongitude - observerLongitude) * _rad;
  final haversine = (pow(sin(deltaLat / 2), 2) +
          cos(lat1) * cos(lat2) * pow(sin(deltaLon / 2), 2))
      .clamp(0.0, 1.0);
  final centralAngle = 2 * asin(sqrt(haversine));
  final orbitalRadius = earthRadiusKm + altitudeKm.clamp(0.0, 100000.0);
  final elevation = atan2(
    orbitalRadius * cos(centralAngle) - earthRadiusKm,
    orbitalRadius * sin(centralAngle),
  );
  final y = sin(deltaLon) * cos(lat2);
  final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon);
  final bearing = (atan2(y, x) * _deg + 360) % 360;
  return SatelliteLook(
    earthRadiusKm * centralAngle,
    elevation * _deg,
    centralAngle * _deg,
    bearing,
  );
}

/// A transparent, weighted 0–10 observing score. Missing optional weather
/// measurements are omitted from the denominator rather than guessed.
double observingScore({
  required double cloudCover,
  required double moonIllumination,
  double? humidity,
  double? windSpeed,
  double? visibilityMeters,
}) {
  final clouds = cloudCover.clamp(0.0, 100.0).toDouble();
  final illumination = moonIllumination.clamp(0.0, 1.0).toDouble();
  final measurements = <(double, double)>[
    (1 - clouds / 100, .45),
    (1 - illumination, .25),
  ];
  if (humidity != null) {
    measurements.add((1 - ((humidity - 55) / 45).clamp(0.0, 1.0).toDouble(), .12));
  }
  if (windSpeed != null) {
    measurements.add((1 - (windSpeed / 40).clamp(0.0, 1.0).toDouble(), .10));
  }
  if (visibilityMeters != null) {
    measurements.add(((visibilityMeters / 20000).clamp(0.0, 1.0).toDouble(), .08));
  }
  final weight = measurements.fold<double>(0, (sum, item) => sum + item.$2);
  final value = measurements.fold<double>(0, (sum, item) => sum + item.$1 * item.$2);
  return (value / weight * 10).clamp(0.0, 10.0).toDouble();
}

class QuizQ {
  final String question;
  final List<String> answers;
  final int correctIndex;
  final String explanation;
  final String category;

  const QuizQ(this.question, this.answers, this.correctIndex,
      {required this.explanation, required this.category});
}

const quiz = <QuizQ>[
  QuizQ('پرنورترین ستاره‌ی آسمان شب کدام است؟', ['ستاره قطبی', 'شباهنگ', 'نسر واقع', 'دبران'], 1,
      explanation: 'شباهنگ با قدر ظاهری حدود ۱٫۴۶- پرنورترین ستاره‌ی شب است.', category: 'ستاره‌ها'),
  QuizQ('ایستگاه فضایی بین‌المللی تقریباً هر چند دقیقه یک دور زمین می‌زند؟', ['۹۲ دقیقه', '۲۴۰ دقیقه', '۱۲ دقیقه', '۶۰۰ دقیقه'], 0,
      explanation: 'ISS در ارتفاع حدود ۴۰۰ کیلومتری، تقریباً هر ۹۲ دقیقه یک دور کامل می‌زند.', category: 'فضانوردی'),
  QuizQ('«صورالکواکب» اثر کدام منجم ایرانی است؟', ['خیام', 'بیرونی', 'عبدالرحمن صوفی', 'خواجه نصیر'], 2,
      explanation: 'عبدالرحمن صوفی رازی کتاب صورالکواکب را در سده‌ی چهارم هجری نوشت.', category: 'تاریخ نجوم'),
  QuizQ('نور خورشید تقریباً چقدر طول می‌کشد تا به زمین برسد؟', ['۸ ثانیه', '۸ دقیقه', '۸ ساعت', '۸ روز'], 1,
      explanation: 'فاصله‌ی متوسط خورشید تا زمین حدود ۸ دقیقه و ۲۰ ثانیه نوری است.', category: 'منظومه شمسی'),
  QuizQ('کدام سیاره حلقه‌های برجسته‌تری دارد؟', ['مشتری', 'زحل', 'نپتون', 'مریخ'], 1,
      explanation: 'هر چهار سیاره‌ی غول‌پیکر حلقه دارند، اما حلقه‌های زحل روشن‌تر و گسترده‌ترند.', category: 'منظومه شمسی'),
  QuizQ('ستاره‌ی قطبی تقریباً در کدام جهت جغرافیایی قرار دارد؟', ['شمال', 'جنوب', 'شرق', 'غرب'], 0,
      explanation: 'در نیم‌کره‌ی شمالی، ستاره‌ی قطبی نزدیک راستای قطب شمال سماوی است.', category: 'آسمان'),
  QuizQ('یک سال نوری واحد چیست؟', ['زمان', 'فاصله', 'روشنایی', 'جرم'], 1,
      explanation: 'سال نوری مسافتی است که نور در یک سال طی می‌کند؛ حدود ۹٫۴۶ تریلیون کیلومتر.', category: 'مبانی'),
  QuizQ('ماه نور خودش را چگونه تولید می‌کند؟', ['همجوشی هسته‌ای', 'بازتاب نور خورشید', 'الکتریسیته', 'آتشفشان‌ها'], 1,
      explanation: 'ماه عمدتاً نور خورشید را بازتاب می‌دهد و خودش ستاره نیست.', category: 'ماه'),
  QuizQ('کدام صورت فلکی سه ستاره‌ی کمربندش معروف است؟', ['شکارچی', 'دب اکبر', 'ذات‌الکرسی', 'دجاجه'], 0,
      explanation: 'سه ستاره‌ی نطاق، نظام و منطقه کمربند صورت فلکی شکارچی را می‌سازند.', category: 'صورت‌های فلکی'),
  QuizQ('یک واحد نجومی تقریباً چند میلیون کیلومتر است؟', ['۱۵', '۱۵۰', '۱۵۰۰', '۱۵۰۰۰'], 1,
      explanation: 'یک واحد نجومی میانگین فاصله‌ی زمین تا خورشید است؛ حدود ۱۴۹٫۶ میلیون کیلومتر.', category: 'منظومه شمسی'),
  QuizQ('حد روشنگری چشم انسان در آسمان تاریک تقریباً چه قدر ستاره‌ای است؟', ['قدر ۱', 'قدر ۳', 'قدر ۶', 'قدر ۱۲'], 2,
      explanation: 'در آسمان تاریک و بدون آلودگی نوری، چشم انسان معمولاً تا قدر حدود ۶ را می‌بیند.', category: 'رصد'),
  QuizQ('کدام سیاره به «سیاره‌ی سرخ» معروف است؟', ['زهره', 'مریخ', 'اورانوس', 'عطارد'], 1,
      explanation: 'اکسید آهن در خاک مریخ رنگ سرخ‌گون آن را ایجاد می‌کند.', category: 'منظومه شمسی'),
];
