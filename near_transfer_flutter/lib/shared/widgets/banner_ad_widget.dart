import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' show Platform;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/ad_config.dart';
import '../services/subscription_service.dart';

/// Check if running on mobile (Android/iOS)
bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

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
    // Only load ads on mobile platforms and non-premium users
    if (_isMobile && !SubscriptionService().isPremium && _bannerAd == null) {
      _loadAd();
    }
  }

  void _loadAd() {
    // Skip on web/desktop or for premium users
    if (!_isMobile) {
      debugPrint('BannerAd: Skipped - not mobile');
      return;
    }
    if (SubscriptionService().isPremium) {
      debugPrint('BannerAd: Skipped - user is premium');
      return;
    }
    
    debugPrint('BannerAd: Loading ad with ID: ${AdConfig.bannerAdUnitId}');
    
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: AdConfig.bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('BannerAd: Ad loaded successfully!');
          if (mounted) {
            setState(() => _isAdLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd: Failed to load - ${error.code}: ${error.message}');
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
    // On web/desktop or premium users, return empty space (no ads)
    if (!_isMobile || SubscriptionService().isPremium) {
      return const SizedBox.shrink();
    }
    
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
