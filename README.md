# Reusable Flutter Ads Feature

A drop-in Google Mobile Ads feature for Flutter. Copy `ads/` into any Flutter
app, configure the IDs once, then use banners and full-screen ad formats from
any feature.

## Included

- Adaptive or fixed-size banners that collapse when unavailable
- Policy-controlled interstitial ads
- User-initiated rewarded ads
- Optional app-open ads after returning from background
- UMP consent and privacy options support
- Ad-free screens and a premium/remove-ads switch

## Install

1. Add the package:

   ```bash
   flutter pub add google_mobile_ads
   ```

2. Copy this repository's `ads/` folder to `lib/ads/` (or `lib/core/ads/`).

3. Configure the Google Mobile Ads app ID for each platform. This is the app
   ID (`ca-app-pub-...~...`), not an ad unit ID.

4. “Tested with google_mobile_ads ^9.2.0, Flutter 3.38.1 أو أحدث”.

### Android

Add the app ID within `<application>` in
`android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY" />
```

Add this direct child of `<manifest>` too:

```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID" />
```

Ensure the project's `minSdk` meets the requirement of the installed
`google_mobile_ads` version.

### iOS

Add the app ID to `ios/Runner/Info.plist`:

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY</string>
```

Add Google's current `SKAdNetworkItems` entries before release. If requesting
App Tracking Transparency permission, also provide
`NSUserTrackingUsageDescription`.

## Initialize once

Keep all app-specific choices in one `AdsConfig`. Set a unit ID to `null` to
disable only that ad format for that platform.

```dart
import 'package:flutter/widgets.dart';
import 'package:your_app/ads/ads.dart';

const adsConfig = AdsConfig(
  android: AdUnitIds(
    banner: 'ca-app-pub-XXXXXXXXXXXXXXXX/1111111111',
    interstitial: 'ca-app-pub-XXXXXXXXXXXXXXXX/2222222222',
    rewarded: 'ca-app-pub-XXXXXXXXXXXXXXXX/3333333333',
    // appOpen: 'ca-app-pub-XXXXXXXXXXXXXXXX/4444444444',
  ),
  ios: AdUnitIds(
    banner: 'ca-app-pub-XXXXXXXXXXXXXXXX/5555555555',
    interstitial: 'ca-app-pub-XXXXXXXXXXXXXXXX/6666666666',
    rewarded: 'ca-app-pub-XXXXXXXXXXXXXXXX/7777777777',
  ),
  // enableAppOpen: true,
  // testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());

  // Call once after runApp; consent needs a UI context.
  AdsService.instance.init(adsConfig);
}
```

Debug builds use Google's test ad unit IDs by default (`testMode: kDebugMode`).
Release builds use the IDs above. Never click live ads while testing. For
multiple application entry points, initialize this service only from the entry
point that owns the app UI.

## Use from anywhere

Import the feature's public API:

```dart
import 'package:your_app/ads/ads.dart';
```

### Banner

`AdBanner` is adaptive by default and occupies no space if it cannot show.

```dart
const AdBanner()
```

For a fixed 320×50 banner or to avoid a loading layout jump:

```dart
const AdBanner(
  size: AdSize.banner,
  reserveSpace: true,
  margin: EdgeInsets.symmetric(vertical: 12),
)
```

Example inside a list:

```dart
if ((index + 1) % 6 == 0) const AdBanner(),
```

### Interstitial

Call this only at a natural break, such as completing a task or leaving a
detail page. It returns `true` when it actually presents an ad.

```dart
final shown = AdsService.instance.maybeShowInterstitial();
```

The default policy waits two minutes after startup, then requires three
eligible breaks and a three-minute gap between ads. Change it in `AdsConfig`:

```dart
const AdsConfig(
  android: AdUnitIds(interstitial: '...'),
  ios: AdUnitIds(interstitial: '...'),
  interstitialFirstGrace: Duration(minutes: 1),
  interstitialMinGap: Duration(minutes: 4),
  interstitialEveryNBreaks: 4,
);
```

### Rewarded

Show rewarded ads only after an explicit user action. The result is `true`
only when the reward was earned.

```dart
ValueListenableBuilder<bool>(
  valueListenable: AdsService.instance.rewardedReady,
  builder: (context, ready, child) => ElevatedButton(
    onPressed: ready
        ? () async {
            final earned = await AdsService.instance.showRewarded();
            if (earned) grantReward();
          }
        : null,
    child: const Text('Watch ad'),
  ),
)
```

Or use a callback:

```dart
await AdsService.instance.showRewarded(onReward: grantReward);
```

Rewarded ads remain available when regular ads are removed because they are
opt-in.

### App-open ads

Set `enableAppOpen: true` and provide `appOpen` IDs. This feature shows an
app-open ad only after the app returns from the background—never on cold start.
It ignores a background trip shorter than 30 seconds by default and reloads
ads older than four hours.

```dart
const AdsConfig(
  android: AdUnitIds(appOpen: '...'),
  ios: AdUnitIds(appOpen: '...'),
  enableAppOpen: true,
  appOpenMinBackground: Duration(seconds: 45),
  appOpenMaxAge: Duration(hours: 4),
);
```

### Ad-free screens and premium users

Protect sensitive screens from interstitial and app-open ads:

```dart
AdFreeZone(child: CheckoutScreen())
```

Use it for onboarding, payment, alarm, lock, or active-media screens. After a
successful remove-ads purchase:

```dart
AdsService.instance.setAdsEnabled(false);
```

This hides banners and prevents interstitial/app-open ads. Call
`setAdsEnabled(true)` to restore them if an entitlement changes.

## Consent and privacy

Consent is enabled by default. The service requests UMP consent before it
initializes the Mobile Ads SDK, and never waits for more than 15 seconds.

Show a privacy-options control only where required:

```dart
final required = await AdsService.instance.isPrivacyOptionsRequired();
if (required) {
  ListTile(
    title: const Text('Privacy choices'),
    onTap: AdsService.instance.showPrivacyOptions,
  );
}
```

Content settings are also configurable:

```dart
const AdsConfig(
  android: AdUnitIds(),
  ios: AdUnitIds(),
  childDirected: true,
  maxAdContentRating: MaxAdContentRating.pg,
)
```

## Release checklist

- Use test ads during development; never click live ads.
- Configure native AdMob app IDs and production ad unit IDs.
- Configure UMP/GDPR messages in AdMob Privacy & messaging where applicable.
- Provide accurate Privacy Policy, Google Play Data Safety, and App Store App
  Privacy declarations.
- Link the app to its store listing in AdMob and host `app-ads.txt` when
  applicable.
- Expect new apps and ad units to need time before production ad serving is
  fully available.

## Behavior reference

| Situation | Result |
| --- | --- |
| Unsupported platform (web/desktop) | Exits safely without requesting ads. |
| A unit ID is `null` | That ad format is disabled safely. |
| Consent blocks requests | The ads SDK does not initialize. |
| A banner fails | It collapses unless `reserveSpace` is enabled. |
| A full-screen ad is visible | Other full-screen ad types do not show. |
| `AdFreeZone` is mounted | Interstitial and app-open ads are blocked. |

The only host-app-specific code should be the `AdsConfig`; the `ads/`
implementation can remain unchanged when copied into another app.
