/// Ad configuration with production AdMob IDs
/// Set useTestAds = false for production builds
class AdConfig {
  // Test App ID (use this for development)
  static const String testAppId = 'ca-app-pub-3940256099942544~3347511713';
  
  // Production App ID
  static const String productionAppId = 'ca-app-pub-4025737666505759~7607161650';
  
  // Test Ad Unit IDs (provided by Google for testing)
  static const String testBannerAdId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdId = 'ca-app-pub-3940256099942544/1033173712';
  static const String testRewardedAdId = 'ca-app-pub-3940256099942544/5224354917';
  
  // Production Ad Unit IDs
  static const String productionBannerAdId = 'ca-app-pub-4025737666505759/8385697339';
  static const String productionInterstitialAdId = 'ca-app-pub-4025737666505759/4840385750';
  static const String productionRewardedAdId = 'YOUR_REWARDED_AD_UNIT_ID'; // Add when needed
  
  // ⚠️ Set to FALSE for production release builds!
  static const bool useTestAds = false;
  
  // Get the appropriate app ID based on mode
  static String get appId => useTestAds ? testAppId : productionAppId;
  
  // Get the appropriate ad IDs based on mode
  static String get bannerAdUnitId => 
      useTestAds ? testBannerAdId : productionBannerAdId;
  
  static String get interstitialAdUnitId => 
      useTestAds ? testInterstitialAdId : productionInterstitialAdId;
  
  static String get rewardedAdUnitId => 
      useTestAds ? testRewardedAdId : productionRewardedAdId;
}
