import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_service.dart';

/// Shows an App Open ad when the app returns from background (never on cold
/// start). Enabled by `AdsConfig.enableAppOpen`. Created by [AdsService].
class AppOpenManager with WidgetsBindingObserver {
  AppOpenManager(this._svc);

  final AdsService _svc;
  AppOpenAd? _ad;
  DateTime? _loadedAt;
  bool _loading = false;
  DateTime? _pausedAt;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _ad?.dispose();
    _ad = null;
  }

  bool get _expired =>
      _loadedAt == null ||
      DateTime.now().difference(_loadedAt!) > _svc.config.appOpenMaxAge;

  void _load() {
    final id = _svc.units?.appOpen;
    if (id == null || _loading || _ad != null) return;
    _loading = true;
    AppOpenAd.load(
      adUnitId: id,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _ad = ad;
          _loadedAt = DateTime.now();
          _loading = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ads] AppOpen: ${error.message}');
          _loading = false;
        },
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _maybeShow();
    }
  }

  void _maybeShow() {
    final pausedAt = _pausedAt;
    _pausedAt = null;

    // Ignore short trips (permission dialogs, share sheets, ...).
    if (pausedAt == null ||
        DateTime.now().difference(pausedAt) < _svc.config.appOpenMinBackground) {
      return;
    }
    if (!_svc.canShowAppOpen) return;

    if (_ad != null && _expired) {
      _ad!.dispose();
      _ad = null;
    }
    final ad = _ad;
    if (ad == null) {
      _load();
      return;
    }

    _ad = null;
    _svc.markFullScreen(true);
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _svc.markFullScreen(false);
        _load();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _svc.markFullScreen(false);
        _load();
      },
    );
    ad.show();
  }
}
