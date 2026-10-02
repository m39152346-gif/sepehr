import 'dart:math';

const _rad = pi / 180;

double julianDay(DateTime t) => t.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;

class AltAz { final double alt, az; const AltAz(this.alt, this.az); }

/// [t] is any absolute moment; [lat]/[lon] = observer anywhere on Earth.
AltAz altAz(double raH, double decD, DateTime t, double lat, double lon) {
  final d = julianDay(t) - 2451545.0;
  final gmst = (18.697374558 + 24.06570982441908 * d) % 24;
  final lst = ((gmst + lon / 15) % 24 + 24) % 24;
  final ha = (lst - raH) * 15 * _rad, dec = decD * _rad, la = lat * _rad;
  final alt = asin(sin(dec) * sin(la) + cos(dec) * cos(la) * cos(ha));
  final cosAz = (sin(dec) - sin(alt) * sin(la)) / (cos(alt) * cos(la));
  var az = acos(cosAz.clamp(-1.0, 1.0));
  if (sin(ha) > 0) az = 2 * pi - az;
  return AltAz(alt / _rad, az / _rad);
}

class MoonInfo { final double age, illum; final String name; const MoonInfo(this.age, this.illum, this.name); }

MoonInfo moonInfo(DateTime t) {
  final age = (((julianDay(t) - 2451550.1) / 29.530588853) % 1 + 1) % 1;
  final illum = (1 - cos(2 * pi * age)) / 2;
  const names = ['ماه نو', 'هلال افزاینده', 'تربیع اول', 'کوژ افزاینده', 'بدر کامل', 'کوژ کاهنده', 'تربیع آخر', 'هلال کاهنده'];
  return MoonInfo(age, illum, names[((age * 8 + .5) % 8).floor()]);
}

class Star { final String id, name; final double ra, dec, mag; const Star(this.id, this.name, this.ra, this.dec, this.mag); }

const stars = <Star>[
  Star('betelgeuse', 'ابط‌الجوزا', 5.919, 7.41, .5), Star('rigel', 'رجل‌الجبار', 5.242, -8.2, .13), Star('bellatrix', '', 5.418, 6.35, 1.6),
  Star('saiph', '', 5.796, -9.67, 2.1), Star('alnitak', '', 5.679, -1.94, 1.7), Star('alnilam', '', 5.604, -1.2, 1.7), Star('mintaka', '', 5.533, -.3, 2.2),
  Star('dubhe', '', 11.062, 61.75, 1.8), Star('merak', '', 11.031, 56.38, 2.4), Star('phecda', '', 11.897, 53.69, 2.4), Star('megrez', '', 12.257, 57.03, 3.3),
  Star('alioth', '', 12.9, 55.96, 1.8), Star('mizar', '', 13.399, 54.93, 2.2), Star('alkaid', '', 13.792, 49.31, 1.9),
  Star('caph', '', .153, 59.15, 2.3), Star('schedar', '', .675, 56.54, 2.2), Star('gcas', '', .945, 60.72, 2.4), Star('ruchbah', '', 1.43, 60.24, 2.7), Star('segin', '', 1.907, 63.67, 3.4),
  Star('deneb', 'ذنب‌الدجاجه', 20.69, 45.28, 1.25), Star('sadr', '', 20.37, 40.26, 2.2), Star('gienah', '', 20.77, 33.97, 2.5), Star('dcyg', '', 19.75, 45.13, 2.9), Star('albireo', '', 19.512, 27.96, 3.1),
  Star('vega', 'نسر واقع', 18.616, 38.78, .03), Star('altair', 'نسر طائر', 19.846, 8.87, .77), Star('polaris', 'ستاره قطبی', 2.53, 89.26, 2),
  Star('antares', 'قلب‌العقرب', 16.49, -26.43, 1), Star('aldebaran', 'دبران', 4.599, 16.51, .85), Star('pleiades', 'پروین', 3.79, 24.1, 1.6),
  Star('sirius', 'شباهنگ', 6.752, -16.72, -1.46), Star('procyon', 'شعرای شامی', 7.655, 5.22, .34), Star('capella', 'عیّوق', 5.278, 46, .08),
  Star('arcturus', 'سماک رامح', 14.261, 19.18, -.05), Star('spica', 'سماک اعزل', 13.42, -11.16, 1), Star('regulus', 'قلب‌الاسد', 10.14, 11.97, 1.4),
  Star('pollux', 'رأس‌التوأم', 7.755, 28.03, 1.14), Star('castor', '', 7.577, 31.89, 1.6), Star('fomalhaut', 'فم‌الحوت', 22.961, -29.62, 1.16),
  Star('markab', '', 23.079, 15.21, 2.5), Star('scheat', '', 23.063, 28.08, 2.4), Star('algenib', '', .221, 15.18, 2.8), Star('alpheratz', '', .14, 29.09, 2.1),
];

const constellationLines = <List<String>>[
  ['betelgeuse', 'bellatrix'], ['betelgeuse', 'alnitak'], ['bellatrix', 'mintaka'], ['alnitak', 'alnilam'], ['alnilam', 'mintaka'], ['alnitak', 'saiph'], ['mintaka', 'rigel'],
  ['dubhe', 'merak'], ['merak', 'phecda'], ['phecda', 'megrez'], ['megrez', 'dubhe'], ['megrez', 'alioth'], ['alioth', 'mizar'], ['mizar', 'alkaid'],
  ['caph', 'schedar'], ['schedar', 'gcas'], ['gcas', 'ruchbah'], ['ruchbah', 'segin'],
  ['deneb', 'sadr'], ['sadr', 'albireo'], ['dcyg', 'sadr'], ['sadr', 'gienah'],
  ['markab', 'scheat'], ['scheat', 'alpheratz'], ['alpheratz', 'algenib'], ['algenib', 'markab'],
  ['vega', 'deneb'], ['deneb', 'altair'], ['altair', 'vega'],
];

class AstroEvent { final DateTime date; final String title, note; const AstroEvent(this.date, this.title, this.note); }

final events = <AstroEvent>[
  AstroEvent(DateTime(2026, 10, 8), 'بارش شهابی اژدهایی', 'بعد از غروب، رو به شمال'),
  AstroEvent(DateTime(2026, 10, 10), 'ماه نو', 'تاریک‌ترین شب‌ها برای رصد اعماق آسمان'),
  AstroEvent(DateTime(2026, 10, 21), 'اوج بارش شهابی جباری', 'تا ۲۰ شهاب در ساعت، بعد از نیمه‌شب'),
  AstroEvent(DateTime(2026, 10, 26), 'ماه کامل', 'ماه شکارچی'),
  AstroEvent(DateTime(2026, 11, 17), 'اوج بارش شهابی اسدی', 'سحرگاه، رو به شرق'),
  AstroEvent(DateTime(2026, 11, 24), 'ماه کامل', 'ماه سرد'),
  AstroEvent(DateTime(2026, 12, 14), 'اوج بارش شهابی جوزایی', 'پربارترین بارش سال'),
  AstroEvent(DateTime(2026, 12, 21), 'انقلاب زمستانی، شب یلدا', 'بلندترین شب سال'),
];

class QuizQ { final String q; final List<String> a; final int c; const QuizQ(this.q, this.a, this.c); }

const quiz = <QuizQ>[
  QuizQ('پرنورترین ستاره‌ی آسمان شب کدام است؟', ['ستاره قطبی', 'شباهنگ', 'نسر واقع', 'دبران'], 1),
  QuizQ('ISS هر چند دقیقه یک بار دور زمین می‌چرخد؟', ['حدود ۹۲', 'حدود ۲۴۰', 'حدود ۱۲', 'حدود ۶۰۰'], 0),
  QuizQ('«صورالکواکب» اثر کدام منجم ایرانی است؟', ['خیام', 'بیرونی', 'عبدالرحمن صوفی', 'خواجه نصیر'], 2),
  QuizQ('کدام سیاره بیشترین قمر شناخته‌شده را دارد؟', ['مشتری', 'زحل', 'نپتون', 'مریخ'], 1),
  QuizQ('نور خورشید چقدر طول می‌کشد تا به زمین برسد؟', ['۸ ثانیه', '۸ دقیقه', '۸ ساعت', '۸ روز'], 1),
];
