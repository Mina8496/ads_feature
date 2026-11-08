# Ads feature (قابلة لإعادة الاستخدام في أي تطبيق)

الفولدر ده مستقل. انسخه كما هو لأي مشروع، وغيّر **ملف واحد بس**: الـ `AdsConfig` اللي بتبنيه في `main.dart`.

## 1) التركيب في مشروع جديد
1. `flutter pub add google_mobile_ads`
2. انسخ فولدر `ads/` جوه `lib/` (أو `lib/core/ads/`).
3. **Android** — `AndroidManifest.xml` جوه `<application>`:
   ```xml
   <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
              android:value="ca-app-pub-XXXX~YYYY"/>
   ```
   وفوق: `<uses-permission android:name="com.google.android.gms.permission.AD_ID"/>`
   و`minSdk` مناسب للنسخة (راجع توثيق الباكج).
4. **iOS** — `Info.plist`: `GADApplicationIdentifier` (App ID الخاص بـ iOS) + `SKAdNetworkItems`
   (القائمة الرسمية من جوجل)، و`NSUserTrackingUsageDescription` لو هتستخدم ATT.
5. AdMob → Privacy & messaging: فعّل رسالة الـ GDPR (UMP) لو هتنشر في أوروبا/بريطانيا.

## 2) التهيئة (`main.dart`)
```dart
import 'package:your_app/ads/ads.dart';

const adsConfig = AdsConfig(
  android: AdUnitIds(
    banner: 'ca-app-pub-XXXX/1111111111',
    interstitial: 'ca-app-pub-XXXX/2222222222',
    rewarded: 'ca-app-pub-XXXX/3333333333',
    // appOpen: ... (اختياري)
  ),
  ios: AdUnitIds(), // فاضي لحد ما تعمل iOS app في AdMob = مفيش إعلانات على iOS
  // enableAppOpen: false,  // الافتراضي
  // testDeviceIds: ['YOUR_DEVICE_ID'],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... باقي التهيئة
  runApp(const MyApp());
  AdsService.instance.init(adsConfig); // بعد runApp، من غير await
}
```
- في **debug** بيستخدم Test IDs تلقائياً، وفي **release** بيستخدم الحقيقية. مفيش `isTestMode` يدوي.
- أي نوع إعلان الـ ID بتاعه `null` بيتعطل لوحده (مفيش crash).
- لو بتستخدم entrypoint تاني (زي `ambientMain`) **ماتستدعيش `init` فيه**.

## 3) الاستخدام
**بانر** (أي مكان، وبيختفي لوحده لو مفيش إعلان):
```dart
if ((index + 1) % 6 == 0) const AdBanner(),
```
**Interstitial** عند نقطة انتقال طبيعية (القواعد جوه الـ config بتقرر هل يظهر فعلاً):
```dart
AdsService.instance.maybeShowInterstitial();
```
**Rewarded** من زرار المستخدم ضغطه:
```dart
ValueListenableBuilder<bool>(
  valueListenable: AdsService.instance.rewardedReady,
  builder: (_, ready, __) => ElevatedButton(
    onPressed: ready
        ? () async {
            final earned = await AdsService.instance.showRewarded();
            if (earned) { /* اعطي المكافأة */ }
          }
        : null,
    child: const Text('شاهد إعلان'),
  ),
);
```
**شاشات ممنوع فيها إعلانات** (تنبيه، قفل، onboarding، دفع...):
```dart
AdFreeZone(child: AlarmScreen())
```
**إزالة الإعلانات** (بعد شراء مثلاً): `AdsService.instance.setAdsEnabled(false);`

**زر إعدادات الخصوصية** (مطلوب في أوروبا): اعرضه لو `await AdsService.instance.isPrivacyOptionsRequired()` رجعت true،
وعند الضغط `AdsService.instance.showPrivacyOptions()`.

## 4) منشور أو لسه؟
| الحالة | اللي تعمله |
|---|---|
| **لسه مش منشور** | جرّب بـ debug (Test IDs). ممكن تحط الـ IDs الحقيقية من دلوقتي، والإعلانات الحقيقية ممكن ماتظهرش لحد النشر وربط التطبيق بالمتجر. |
| **منشور** | ابنِ release، وتأكد إن `testMode` مش شغال. ماتضغطش على إعلانات حقيقية أبداً وانت بتجرب (استخدم `testDeviceIds`). |
| **بعد النشر** | AdMob → App settings → Link to store، وأضف `app-ads.txt` على موقع المطوّر. |

## 5) Checklist للمتاجر
- Privacy Policy فيها الإعلانات وجمع بيانات الجهاز.
- Google Play: Data Safety + Advertising ID + "يحتوي على إعلانات".
- App Store: App Privacy + ATT (لو تتبع).

## ملاحظات
- IDs الاختبار مكتوبة في `ads_config.dart`، راجعها مع صفحة Test ads في توثيق جوجل لو الباكج اتحدّث.
- لو الإعلانات بتزعج: زوّد `interstitialMinGap` و`interstitialEveryNBreaks`.
