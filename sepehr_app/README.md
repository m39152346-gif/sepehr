<div dir="rtl">

# سپهر 🔭

**اپ نجوم فارسی برای اندروید**، آنلاین و برای هر شهری در دنیا. ساخته‌شده با Flutter.

[![Build APK](../../actions/workflows/build-apk.yml/badge.svg)](../../actions/workflows/build-apk.yml)

## قابلیت‌ها
- 🌍 **انتخاب هر شهر در هر کشور** با جستجو (فارسی یا انگلیسی) یا **GPS**؛ همه‌ی محاسبات و ساعت‌ها طبق همون شهر
- 🌙 **آسمان امشب**: فاز ماه، درصد ابر (زنده)، غروب و طلوع، امتیاز رصد
- ✨ **نقشه‌ی آسمان**: ستاره‌ها و صورت‌های فلکی بالای سر تو، با کشیدن انگشت زمان رو جابه‌جا کن
- 🛰️ **ردیاب زنده‌ی ISS** + فاصله‌اش تا شهرت و اینکه الان دیده میشه یا نه
- 🖼️ **عکس نجومی روز ناسا**
- 📅 **تقویم نجومی** با یادآور
- 🧠 **کوییز نجوم**
- 🔴 **حالت دید در شب** (صفحه‌ی قرمز برای رصد)

## دانلود
آخرین نسخه‌ی APK از بخش [Releases](../../releases) قابل دانلوده.

## ساخت خودکار با GitHub Actions
- هر بار که کد رو push کنی، APK خودکار ساخته میشه و از تب **Actions ← آخرین اجرا ← sepehr-apk** دانلود میشه.
- برای انتشار نسخه‌ی رسمی، یه تگ بزن (مثلاً `v1.0.0`)؛ APK خودکار تو **Releases** منتشر میشه.
- کلید ناسا: تو **Settings ← Secrets and variables ← Actions** یه secret به اسم `NASA_KEY` بساز (کلید رایگان از https://api.nasa.gov). اگه نسازی، از `DEMO_KEY` استفاده میشه.

## اجرا روی کامپیوتر خودت
```bash
flutter create . --platforms=android --org com.sepehr --project-name sepehr
flutter pub get
flutter run
```
بعد از `flutter create`، این مجوزها رو بالای تگ `<application` تو `android/app/src/main/AndroidManifest.xml` اضافه کن:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

## ساختار پروژه
```
lib/
  main.dart                 ← ناوبری، حالت دید در شب
  core/astro.dart           ← محاسبات نجومی (ستاره‌ها، ماه، رویدادها)
  core/place.dart           ← شهر انتخابی و ذخیره‌اش
  core/api.dart             ← همه‌ی سرویس‌های آنلاین
  core/theme.dart           ← رنگ‌ها، فونت وزیرمتن، اعداد فارسی
  screens/                  ← صفحه‌های اپ
test/astro_test.dart        ← تست محاسبات
```

## سرویس‌های آنلاین (همه رایگان)
[Open-Meteo](https://open-meteo.com) (جستجوی شهر و هوا) · [BigDataCloud](https://www.bigdatacloud.com) (اسم شهر از GPS) · [wheretheiss.at](https://wheretheiss.at) (ISS) · [NASA APOD](https://api.nasa.gov)

## مجوز
MIT

</div>

---

**Sepehr** is a Persian astronomy app for Android (Flutter): worldwide city picker, live sky map, moon phase, cloud forecast, ISS tracker, NASA APOD, astro calendar, quiz and red night-vision mode. Pushes to `main` build an APK via GitHub Actions; tags `v*` publish a Release.
