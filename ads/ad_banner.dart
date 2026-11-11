import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_service.dart';

/// Drop-in banner. Collapses to nothing when there is no ad, when ads are
/// disabled, or before the SDK is ready. Adaptive width by default.
///
///   const AdBanner()                       // adaptive
///   const AdBanner(size: AdSize.banner)    // fixed 320x50
class AdBanner extends StatefulWidget {
  const AdBanner({
    super.key,
    this.size,
    this.reserveSpace = false,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  /// null => anchored adaptive banner sized to the screen width.
  final AdSize? size;

  /// Keep an empty box of the ad's height while loading (no layout jump).
  final bool reserveSpace;

  final EdgeInsets margin;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  final _svc = AdsService.instance;
  BannerAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _svc.ready.addListener(_onChange);
    _svc.adsEnabled.addListener(_onChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  void _onChange() {
    if (!mounted) return;
    if (!_svc.adsEnabled.value) _disposeAd();
    setState(() {});
    _maybeLoad();
  }

  void _disposeAd() {
    _ad?.dispose();
    _ad = null;
    _loaded = false;
    _loading = false;
  }

  Future<void> _maybeLoad() async {
    if (_ad != null || _loading || _failed) return;
    if (!_svc.ready.value || !_svc.adsEnabled.value) return;
    final id = _svc.units?.banner;
    if (id == null) return;

    _loading = true;
    AdSize? size = widget.size;
    if (size == null) {
      final width =
          (MediaQuery.sizeOf(context).width - widget.margin.horizontal).truncate();
      size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
      size ??= AdSize.banner;
    }
    if (!mounted) return;

    final ad = BannerAd(
      adUnitId: id,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() {
            _loaded = true;
            _loading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('[Ads] Banner: ${error.message}');
          ad.dispose();
          _failed = true;
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
            _loading = false;
          });
        },
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _svc.ready.removeListener(_onChange);
    _svc.adsEnabled.removeListener(_onChange);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) {
      if (widget.reserveSpace && _svc.adsEnabled.value && !_failed) {
        return SizedBox(height: (widget.size?.height ?? 50).toDouble());
      }
      return const SizedBox.shrink();
    }
    return Padding(
      padding: widget.margin,
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
