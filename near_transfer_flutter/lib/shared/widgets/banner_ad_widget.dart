import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/ad_config.dart';
import '../services/subscription_service.dart';

/// Reusable adaptive banner ad widget
/// Shows ads only on mobile platforms (Android/iOS)
/// Returns empty container on web/desktop or for premium users
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only load ads on non-web platforms and non-premium users
    if (!kIsWeb && !SubscriptionService().isPremium && _bannerAd == null) {
      _loadAd();
    }
  }

  void _loadAd() {
    // Skip on web or for premium users
    if (kIsWeb || SubscriptionService().isPremium) return;
    
    _bannerAd = BannerAd(
      size: AdSize.largeBanner,
      adUnitId: AdConfig.bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isAdLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner ad failed to load: ${error.message}');
          ad.dispose();
          if (mounted) {
            setState(() => _isAdLoaded = false);
          }
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // On web or premium users, return empty space (no ads)
    if (kIsWeb || SubscriptionService().isPremium) {
      return const SizedBox.shrink();
    }
    
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox(height: 100);
    }

    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
