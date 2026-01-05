import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' show Platform;
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

  /// Check if running on mobile (Android/iOS)
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Check if ads are supported on current platform
  bool get isSupported => _isMobile;

  /// Check if ads should be shown (not premium and supported)
  bool get shouldShowAds => isSupported && !SubscriptionService().isPremium;

  /// Initialize the Mobile Ads SDK
  Future<void> initialize() async {
    // Skip initialization on web and desktop
    if (!_isMobile) {
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
    }
  }

  /// Load an interstitial ad
  void _loadInterstitialAd() {
    if (kIsWeb) {
      debugPrint('InterstitialAd: Skipped - running on web');
      return;
    }
    if (!shouldShowAds) {
      debugPrint('InterstitialAd: Skipped - shouldShowAds=false (premium: ${SubscriptionService().isPremium})');
      return;
    }
    
    debugPrint('InterstitialAd: Loading with ID: ${AdConfig.interstitialAdUnitId}');
    
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('InterstitialAd: Loaded successfully!');
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('InterstitialAd: Dismissed');
              ad.dispose();
              _isInterstitialAdReady = false;
              if (shouldShowAds) {
                _loadInterstitialAd();
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('InterstitialAd: Failed to show - ${error.code}: ${error.message}');
              ad.dispose();
              _isInterstitialAdReady = false;
              if (shouldShowAds) {
                _loadInterstitialAd();
              }
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd: Failed to load - ${error.code}: ${error.message}');
          _isInterstitialAdReady = false;
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
    debugPrint('InterstitialAd: showInterstitialAd() called');
    
    // Skip on web or for premium users
    if (kIsWeb || !shouldShowAds) {
      debugPrint('InterstitialAd: Not showing - web or premium');
      return false;
    }
    
    // Only show once per session to not annoy users
    if (_interstitialShownThisSession) {
      debugPrint('InterstitialAd: Already shown this session');
      return false;
    }
    
    if (_isInterstitialAdReady && _interstitialAd != null) {
      debugPrint('InterstitialAd: Showing ad now!');
      _interstitialShownThisSession = true;
      await _interstitialAd!.show();
      return true;
    }
    debugPrint('InterstitialAd: Not ready (ready=$_isInterstitialAdReady, ad=${_interstitialAd != null})');
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
