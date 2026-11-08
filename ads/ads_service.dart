import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';
import 'app_open_manager.dart';

/// Single entry point for all ads. Works in any app:
///   await AdsService.instance.init(config);
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  AdsConfig? _config;
  AdsConfig get config => _config!;
  AdUnitIds? get units => _config?.units;

  /// true once the SDK is initialised and consent allows requesting ads.
  final ValueNotifier<bool> ready = ValueNotifier(false);

  /// Set to false for premium / "remove ads" users. Hides banners,
  /// interstitials and app-open. Rewarded stays (user opts in).
  final ValueNotifier<bool> adsEnabled = ValueNotifier(true);

  /// Rewarded ad loaded and ready to show.
  final ValueNotifier<bool> rewardedReady = ValueNotifier(false);

  bool _initStarted = false;
  DateTime? _initTime;

  // Full-screen bookkeeping (shared with AppOpenManager).
  bool _fullScreenShowing = false;
  DateTime? _lastFullScreenClosed;
  int _blockers = 0;

  // Interstitial.
  InterstitialAd? _interstitial;
  DateTime? _interstitialLoadedAt;
  bool _loadingInterstitial = false;
  int _interstitialRetries = 0;
  DateTime? _lastInterstitial;
  int _breaks = 0;

  // Rewarded.
  RewardedAd? _rewarded;
  DateTime? _rewardedLoadedAt;
  bool _loadingRewarded = false;
  int _rewardedRetries = 0;

  AppOpenManager? _appOpen;

  // ---------------------------------------------------------------- init

  /// Call once, ideally right AFTER runApp() (the consent form needs UI).
  /// Safe to call more than once. Never throws.
  Future<void> init(AdsConfig config) async {
    if (_initStarted) return;
    _initStarted = true;
    _config = config;

    if (!config.supported) return;
    if (!kDebugMode && config.testMode) {
      debugPrint('[Ads] WARNING: testMode is ON in a release build.');
    }

    try {
      final child = config.childDirected;
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds:
              config.testDeviceIds.isEmpty ? null : config.testDeviceIds,
          maxAdContentRating: config.maxAdContentRating,
          tagForChildDirectedTreatment: child == null
              ? null
              : (child
                  ? TagForChildDirectedTreatment.yes
                  : TagForChildDirectedTreatment.no),
        ),
      );

      if (config.enableConsent) await _gatherConsent();

      final canRequest = !config.enableConsent ||
          await ConsentInformation.instance.canRequestAds();
      if (!canRequest) {
        debugPrint('[Ads] Consent does not allow requesting ads.');
        return;
      }

      await MobileAds.instance.initialize();
      _initTime = DateTime.now();
      ready.value = true;

      loadInterstitial();
      loadRewarded();

      if (config.enableAppOpen && config.units.appOpen != null) {
        _appOpen = AppOpenManager(this)..start();
      }
    } catch (e, st) {
      debugPrint('[Ads] init failed: $e\n$st');
    }
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) debugPrint('[Ads] Consent form: ${error.message}');
          finish();
        });
      },
      (FormError error) {
        debugPrint('[Ads] Consent info: ${error.message}');
        finish();
      },
    );

    return done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
  }

  /// Show a "Privacy settings" button in your settings screen only when true.
  Future<bool> isPrivacyOptionsRequired() async {
    if (_config?.supported != true || !_config!.enableConsent) return false;
    final status =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  void showPrivacyOptions() {
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) debugPrint('[Ads] Privacy options: ${error.message}');
    });
  }

  // ------------------------------------------------------------- helpers

  bool _canServe({bool respectRemoval = true}) =>
      _config != null &&
      ready.value &&
      (!respectRemoval || adsEnabled.value);

  /// Remove / restore ads (call after an in-app purchase, for example).
  void setAdsEnabled(bool value) => adsEnabled.value = value;

  /// Used by [AdFreeZone] to temporarily block full-screen ads.
  void blockAds() => _blockers++;
  void unblockAds() {
    if (_blockers > 0) _blockers--;
  }

  bool get blocked => _blockers > 0;
  bool get isFullScreenAdShowing => _fullScreenShowing;
  DateTime? get lastFullScreenClosed => _lastFullScreenClosed;

  void markFullScreen(bool showing) {
    _fullScreenShowing = showing;
    if (!showing) _lastFullScreenClosed = DateTime.now();
  }

  bool _isStale(DateTime? loadedAt) =>
      loadedAt == null ||
      DateTime.now().difference(loadedAt) > const Duration(minutes: 55);

  void _retry(VoidCallback fn, int attempt) {
    if (attempt > 3) return;
    Timer(Duration(seconds: 15 * attempt), fn);
  }

  // -------------------------------------------------------- interstitial

  void loadInterstitial() {
    final id = units?.interstitial;
    if (!_canServe() || id == null) return;
    if (_interstitial != null || _loadingInterstitial) return;

    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: id,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitialLoadedAt = DateTime.now();
          _loadingInterstitial = false;
          _interstitialRetries = 0;
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ads] Interstitial: ${error.message}');
          _loadingInterstitial = false;
          _retry(loadInterstitial, ++_interstitialRetries);
        },
      ),
    );
  }

  /// Call at NATURAL breaks only (after finishing a task, closing a detail
  /// page...). The frequency rules in [AdsConfig] decide if it really shows.
  /// Returns true if an ad was shown.
  bool maybeShowInterstitial() {
    if (!_canServe() || blocked || _fullScreenShowing) return false;

    final c = config;
    _breaks++;
    final now = DateTime.now();
    final every = c.interstitialEveryNBreaks < 1 ? 1 : c.interstitialEveryNBreaks;

    final tooEarly =
        _initTime == null || now.difference(_initTime!) < c.interstitialFirstGrace;
    final tooSoon = _lastInterstitial != null &&
        now.difference(_lastInterstitial!) < c.interstitialMinGap;
    final notYet = _breaks % every != 0;

    if (_interstitial != null && _isStale(_interstitialLoadedAt)) {
      _interstitial!.dispose();
      _interstitial = null;
    }
    final ad = _interstitial;

    if (tooEarly || tooSoon || notYet || ad == null) {
      loadInterstitial();
      return false;
    }

    _interstitial = null;
    _lastInterstitial = now;
    _fullScreenShowing = true;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        markFullScreen(false);
        loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        markFullScreen(false);
        loadInterstitial();
      },
    );
    ad.show();
    return true;
  }

  // ------------------------------------------------------------ rewarded

  void loadRewarded() {
    final id = units?.rewarded;
    if (!_canServe(respectRemoval: false) || id == null) return;
    if (_rewarded != null || _loadingRewarded) return;

    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: id,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _rewardedLoadedAt = DateTime.now();
          _loadingRewarded = false;
          _rewardedRetries = 0;
          rewardedReady.value = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ads] Rewarded: ${error.message}');
          _loadingRewarded = false;
          rewardedReady.value = false;
          _retry(loadRewarded, ++_rewardedRetries);
        },
      ),
    );
  }

  /// Only call from a button the user pressed ("Watch ad to get X").
  /// Returns true if the user earned the reward.
  Future<bool> showRewarded({VoidCallback? onReward}) {
    if (_rewarded != null && _isStale(_rewardedLoadedAt)) {
      _rewarded!.dispose();
      _rewarded = null;
      rewardedReady.value = false;
    }
    final ad = _rewarded;
    if (ad == null || _fullScreenShowing) {
      loadRewarded();
      return Future.value(false);
    }

    final result = Completer<bool>();
    var earned = false;
    void finish(bool v) {
      if (!result.isCompleted) result.complete(v);
    }

    _rewarded = null;
    rewardedReady.value = false;
    _fullScreenShowing = true;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        markFullScreen(false);
        loadRewarded();
        finish(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        markFullScreen(false);
        loadRewarded();
        finish(false);
      },
    );
    ad.show(onUserEarnedReward: (_, __) {
      earned = true;
      onReward?.call();
    });
    return result.future;
  }

  // ------------------------------------------------------------ app open

  /// Used by [AppOpenManager].
  bool get canShowAppOpen =>
      _canServe() && !blocked && !_fullScreenShowing &&
      (_lastFullScreenClosed == null ||
          DateTime.now().difference(_lastFullScreenClosed!) >
              const Duration(seconds: 3));
}
