# Codemagic Workflow Reference

اعتمدت سجلات البناء الناجحة المرفقة كمرجع ثابت. نجح البناء باستخدام Xcode 26.4.1، وانتهى بإنشاء archive ثم تصدير `build/ios/ipa/ServerIDE.ipa` ونشر IPA وملفات المصدر والـartifacts. تحافظ النسخة الحالية على نفس المسار العام: تثبيت الاعتماديات، توليد مشروع iOS، تطبيق ملفات التوقيع، فحوص المشروع، ثم بناء IPA موقّع.

## التسلسل المعتمد

1. Codemagic يجهز جهاز البناء ويجلب المصدر ويهيئ هويات التوقيع.
2. يثبت JavaScript dependencies عبر `pnpm install --frozen-lockfile`.
3. يولد مشروع iOS عبر `npx expo prebuild --platform ios --non-interactive`.
4. يطبق provisioning profiles عبر `xcode-project use-profiles`.
5. يشغل TypeScript والاختبارات.
6. يبني archive ويصدر IPA عبر `xcode-project build-ipa`.
7. Codemagic ينفذ النشر والتنظيف كخطوات منصة، بينما يحدد الملف artifacts المطلوبة.

## قواعد الثبات

يجب تثبيت Xcode 26.4.1 المطابق للبناء الناجح بدل استخدام `latest` عندما يكون متاحًا في Codemagic، مع إبقاء Node 22.13.0 وBundle ID وscheme واسم التطبيق دون تغيير. لا توضع شهادات أو مفاتيح أو ملفات بيئة داخل Git.
