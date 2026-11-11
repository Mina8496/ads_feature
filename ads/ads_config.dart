import 'package:flutter/foundation.dart';

/// Ad unit IDs for ONE platform. Leave a field null to disable that ad type.
class AdUnitIds {
  const AdUnitIds({
    this.banner,
    this.interstitial,
    this.rewarded,
    this.appOpen,
  });

  final String? banner;
  final String? interstitial;
  final String? rewarded;
  final String? appOpen;
}

/// Everything app-specific lives here. The rest of the feature is generic.
class AdsConfig {
  const AdsConfig({
    required this.android,
    required this.ios,
    this.testMode = kDebugMode,
    this.testDeviceIds = const [],
    this.enableConsent = true,
    this.childDirected,
    this.maxAdContentRating,
    this.interstitialFirstGrace = const Duration(minutes: 2),
    this.interstitialMinGap = const Duration(minutes: 3),
    this.interstitialEveryNBreaks = 3,
    this.enableAppOpen = false,
    this.appOpenMaxAge = const Duration(hours: 4),
    this.appOpenMinBackground = const Duration(seconds: 30),
  });

  /// Real IDs per platform (used when [testMode] is false).
  final AdUnitIds android;
  final AdUnitIds ios;

  /// true => Google test IDs are used. Defaults to debug builds only.
  final bool testMode;

  /// Device IDs (printed in logcat/Xcode) to receive test ads with real IDs.
  final List<String> testDeviceIds;

  /// Show the UMP consent form when required (EEA/UK/etc).
  final bool enableConsent;

  /// null = unspecified, true/false = child-directed treatment.
  final bool? childDirected;

  /// e.g. MaxAdContentRating.g / .pg / .t / .ma
  final String? maxAdContentRating;

  /// Interstitial rules.
  final Duration interstitialFirstGrace;
  final Duration interstitialMinGap;
  final int interstitialEveryNBreaks;

  /// App Open rules (off by default).
  final bool enableAppOpen;
  final Duration appOpenMaxAge;
  final Duration appOpenMinBackground;

  static const AdUnitIds _testAndroid = AdUnitIds(
    banner: 'ca-app-pub-3940256099942544/9214589741',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
    appOpen: 'ca-app-pub-3940256099942544/9257395921',
  );

  static const AdUnitIds _testIos = AdUnitIds(
    banner: 'ca-app-pub-3940256099942544/2934735716',
    interstitial: 'ca-app-pub-3940256099942544/4411468910',
    rewarded: 'ca-app-pub-3940256099942544/1712485313',
    appOpen: 'ca-app-pub-3940256099942544/5575463023',
  );

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _isIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// Ads only exist on Android / iOS.
  bool get supported => !kIsWeb && (_isAndroid || _isIos);

  /// IDs resolved for the current platform + mode.
  AdUnitIds get units {
    if (testMode) return _isAndroid ? _testAndroid : _testIos;
    return _isAndroid ? android : ios;
  }
}
