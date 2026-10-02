<div dir="rtl">

# سپهر ۲ 🔭

**اپ نجوم فارسی برای اندروید**؛ از برنامه‌ریزی رصد تا پیدا کردن ستاره‌ها و دنبال‌کردن ایستگاه فضایی. نسخه‌ی ۲ با تمرکز بر پیش‌بینی قابل‌فهم، ابزارهای میدانی و ذخیره‌سازی تنظیم‌ها ساخته شده است.

[![Build APK](../actions/workflows/build-apk.yml/badge.svg)](../actions/workflows/build-apk.yml)

## قابلیت‌های نسخه‌ی ۲

1. **امتیاز رصد شفاف** بر اساس ابر، فاز ماه، رطوبت، باد و دید افقی؛ همراه با توضیح محدودیت برآورد.
2. **پیش‌بینی ساعتی ۱۲ساعته و چشم‌انداز هفت‌روزه** شامل ابر، دما و احتمال بارش، با واحد °C/°F.
3. **فازهای ماه و تقویم نجومی پویا**؛ رویدادهای قمری، بارش‌های شهابی و فصل‌ها با برچسب تقریبی.
4. **نقشه‌ی تعاملی‌تر آسمان** با جابه‌جایی زمان، بزرگ‌نمایی، حد قدر ستاره‌ها و روشن/خاموش‌کردن خطوط صور فلکی.
5. **ردیاب بهتر ISS** با ارتفاع مداری، سمت و ارتفاع هندسی نسبت به افق شهر؛ بدون ادعای رؤیت قطعی.
6. **بایگانی عکس روز ناسا** با انتخاب تاریخ، نمایش عکس/ویدئو و نشان‌کردن موارد دلخواه روی دستگاه.
7. **تقویم قابل فیلتر** برای ماه، بارش شهابی و رویدادهای فصلی؛ نشان‌ها در دستگاه ذخیره می‌شوند.
8. **کوییز بازطراحی‌شده** با ترتیب تصادفی سؤال‌ها، توضیح پاسخ و ثبت بهترین امتیاز.
9. **مکان‌های رصد اخیر و نشان‌شده**؛ جست‌وجوی شهر یا دریافت موقعیت با GPS.
10. **کیت رصد و شخصی‌سازی**: محاسبه‌گر تلسکوپ، تایمر سازگاری چشم، چک‌لیست، دید در شب قرمز، اندازه‌ی نوشته و واحد دما.

## دریافت APK

هر push روی شاخه‌ی کاری یا شاخه‌ی اصلی، APK نسخه‌ی release را در GitHub Actions می‌سازد. در اجرای موفق، از بخش **Artifacts → sepehr-apk** فایل را دریافت و از ZIP، `app-release.apk` را خارج کن. برای انتشار نسخه‌ی رسمی، تگ نسخه‌ای مانند `v2.0.0` بساز.

## ساخت محلی

از پوشه‌ی ریشه‌ی مخزن:

```bash
cd sepehr_app
flutter create . --platforms=android --org com.sepehr --project-name sepehr
flutter pub get
flutter test
flutter build apk --release
```

Workflow در `.github/workflows/build-apk.yml` مجوز اینترنت و موقعیت را به Manifest اندروید اضافه می‌کند. برای ساخت دستی، این مجوزها باید در `android/app/src/main/AndroidManifest.xml` بالای `<application>` باشند:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

برای محدودیت کمتر NASA APOD، در GitHub Actions یک secret به نام `NASA_KEY` قرار بده؛ در غیر این صورت اپ از `DEMO_KEY` استفاده می‌کند.

## ساختار

```text
lib/core/       محاسبات نجومی، API، مکان و تنظیم‌ها
lib/screens/    خانه، نقشه، ISS، عکس روز، رویدادها، کوییز و ابزارها
test/           تست محاسبات، هندسه‌ی دید و خواندن پیش‌بینی هوا
```

تمام پیش‌بینی‌های هوا و زمان فاز ماه تقریبی‌اند و جایگزین ابزار رصدی/هواشناسی حرفه‌ای نیستند.

## مجوز

MIT

</div>

---

**Sepehr 2.0** is a Persian Flutter astronomy app with a seven-day weather outlook, an interactive sky map, topocentric ISS tracking, NASA APOD archive and favorites, a rolling astronomy calendar, randomized quiz, observing tools, saved locations, and persistent accessibility settings.
