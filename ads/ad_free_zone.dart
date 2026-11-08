import 'package:flutter/widgets.dart';

import 'ads_service.dart';

/// Wrap screens where ads must NEVER appear (alarm, lock screen, onboarding,
/// payment, audio playback...). While mounted it blocks interstitial and
/// App Open ads.
class AdFreeZone extends StatefulWidget {
  const AdFreeZone({super.key, required this.child});
  final Widget child;

  @override
  State<AdFreeZone> createState() => _AdFreeZoneState();
}

class _AdFreeZoneState extends State<AdFreeZone> {
  @override
  void initState() {
    super.initState();
    AdsService.instance.blockAds();
  }

  @override
  void dispose() {
    AdsService.instance.unblockAds();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
