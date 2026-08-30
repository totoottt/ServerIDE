# GitHub وCodemagic — نتائج الفحص

## GitHub
- المستودع: `https://github.com/totoottt/ServerIDE`
- الفرع الظاهر: `main`
- آخر commit ظاهر: `c285a57` بعنوان `fix`
- عدد الـ commits الظاهر: 27
- بنية المستودع الحالية: مشروع iOS أصلي بلغة Swift مع مجلدات `ServerIDE/` و`ServerIDETests/` و`assets/` و`scripts/` و`tests/`، وملفات `project.yml` و`codemagic.yaml` و`README.md` وملفات release.
- اللغات الظاهرة: Swift 89.5%، Python 10.2%، Shell 0.3%.
- README يذكر أن المشروع الأصلي يدير SSH وSFTP ومحرر كود وطرفية وفحوص الشبكة، وأن ملف `codemagic.yaml` موجود مسبقًا.
- README يذكر أن workflow الموقع حاليًا يستخدم توقيع Ad Hoc وBundle ID: `app.carambola5307.spinach7929`، وأن المصدر لم يُبنَ محليًا باستخدام iOS SDK.

## Codemagic
- الصفحة الرئيسية تعرض دعم ربط GitHub وباقي مستودعات Git، وتدعم Native iOS وReact Native وAndroid.
- Codemagic يتيح إدارة code signing identities وربط Apple Developer portal من داخل الخدمة.
- مسار الدخول الظاهر: Login / Sign up ثم Return to app، مع توثيق متاح على `https://docs.codemagic.io`.
- لا ينبغي رفع شهادات Apple أو مفاتيحها إلى GitHub؛ يجب ربطها داخل Codemagic عبر code signing أو متغيرات آمنة.

## قرار المزامنة
المشروع الحالي في WebDev هو تطبيق Expo React Native جديد باسم Server IDE، بينما المستودع القديم هو تطبيق iOS Swift قائم. قبل رفع الملفات يجب اختيار ما إذا كان المطلوب استبدال محتوى المستودع القديم بنسخة Expo، أو إبقاء مشروع Swift ورفع تغييرات تصميمه. لا يجوز دمج ملفي المشروعين عشوائيًا لأن إعدادات Codemagic وBundle ID ومسارات البناء مختلفة.
