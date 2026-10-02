# راهنمای گذاشتن پروژه روی GitHub

## روش ۱: از مرورگر (بدون نصب چیزی)
1. https://github.com/new ← اسم: `sepehr` ← Public ← **Create repository**
2. روی **uploading an existing file** بزن
3. **همه‌ی** محتوای پوشه‌ی `sepehr_app` رو بکش و بنداز. ⚠️ پوشه‌ی مخفی `.github` و فایل `.gitignore` هم باید باشن
   (تو ویندوز: View ← Hidden items، تو مک: Cmd+Shift+.)
4. **Commit changes**
5. تب **Actions** ← صبر کن تیک سبز بخوره (۵ تا ۸ دقیقه) ← **sepehr-apk** رو دانلود کن

## روش ۲: با git
```bash
cd sepehr_app
git init
git add .
git commit -m "Sepehr v1.0.0"
git branch -M main
git remote add origin https://github.com/<USERNAME>/sepehr.git
git push -u origin main
```

## انتشار نسخه‌ی رسمی
```bash
git tag v1.0.0
git push origin v1.0.0
```
APK خودکار تو صفحه‌ی **Releases** منتشر میشه.

## اگه تیک قرمز خورد
روی اجرای قرمز بزن، مرحله‌ای که خطا داده رو باز کن، متن خطا رو کپی کن و برای Brain بفرست.
