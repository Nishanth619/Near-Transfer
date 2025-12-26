import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../core/ad_config.dart';
import 'subscription_service.dart';

/// Service for managing Google AdMob ads
/// Only initializes on mobile platforms (Android/iOS)
/// Skips ads for premium users
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  
  // Track if interstitial was shown this session to avoid spamming
  bool _interstitialShownThisSession = false;

  /// Check if ads are supported on current platform
  bool get isSupported => !kIsWeb;

  /// Check if ads should be shown (not premium and supported)
  bool get shouldShowAds => isSupported && !SubscriptionService().isPremium;

  /// Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    // Skip initialization on web
    if (kIsWeb) {
      print('AdMob not supported on web platform');
      return;
    }
    
    if (_isInitialized) return;
    
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      
      // Only preload ads if not premium
      if (shouldShowAds) {
        _loadInterstitialAd();
      }
    } catch (e) {
      print('Failed to initialize AdMob: $e');
    }
  }

  /// Load an interstitial ad
  void _loadInterstitialAd() {
    if (kIsWeb || !shouldShowAds) return;
    
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isInterstitialAdReady = false;
              // Reload for next time (if still not premium)
              if (shouldShowAds) {
                _loadInterstitialAd();
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _isInterstitialAdReady = false;
              if (shouldShowAds) {
                _loadInterstitialAd();
              }
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('Interstitial ad failed to load: ${error.message}');
          _isInterstitialAdReady = false;
          // Retry after delay (if still not premium)
          if (shouldShowAds) {
            Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
          }
        },
      ),
    );
  }

  /// Show interstitial ad (e.g., after transfer completes)
  /// Returns true if ad was shown, false otherwise
  Future<bool> showInterstitialAd() async {
    // Skip on web or for premium users
    if (kIsWeb || !shouldShowAds) return false;
    
    // Only show once per session to not annoy users
    if (_interstitialShownThisSession) {
      return false;
    }
    
    if (_isInterstitialAdReady && _interstitialAd != null) {
      _interstitialShownThisSession = true;
      await _interstitialAd!.show();
      return true;
    }
    return false;
  }

  /// Create a banner ad
  BannerAd createBannerAd({
    required Function() onAdLoaded,
    required Function(LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      size: AdSize.banner,
      adUnitId: AdConfig.bannerAdUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => onAdLoaded(),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(error);
        },
      ),
    );
  }

  /// Dispose resources
  void dispose() {
    _interstitialAd?.dispose();
  }
}
