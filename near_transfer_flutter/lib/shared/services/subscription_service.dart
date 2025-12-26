import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Service for managing premium subscriptions and in-app purchases.
/// Handles purchase flow, verification, and persistent premium status.
class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // Storage keys
  static const String _isPremiumKey = 'is_premium';
  static const String _purchaseDateKey = 'premium_purchase_date';

  // Product IDs - configure these in Play Console / App Store Connect
  static const String _removeAdsProductId = 'remove_ads_premium';
  static const Set<String> _productIds = {_removeAdsProductId};

  // State
  bool _isInitialized = false;
  bool _isPremium = false;
  bool _isLoading = false;
  List<ProductDetails> _products = [];
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Debug mode for testing without real purchases
  bool _debugPremiumOverride = false;

  /// Check if user has premium (no ads)
  bool get isPremium => _debugPremiumOverride || _isPremium;

  /// Check if purchase is in progress
  bool get isLoading => _isLoading;

  /// Get available products for purchase
  List<ProductDetails> get products => _products;

  /// Check if in-app purchases are available
  bool get isAvailable => InAppPurchase.instance.isAvailable() as bool? ?? false;

  /// Initialize the subscription service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load cached premium status first (for offline access)
      await _loadPremiumStatus();

      // Check if IAP is available (skip on web)
      if (kIsWeb) {
        debugPrint('In-app purchases not available on web');
        _isInitialized = true;
        return;
      }

      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        debugPrint('In-app purchases not available on this device');
        _isInitialized = true;
        return;
      }

      // Listen for purchase updates
      _subscription = InAppPurchase.instance.purchaseStream.listen(
        _handlePurchaseUpdates,
        onError: (error) {
          debugPrint('Purchase stream error: $error');
        },
      );

      // Load available products
      await _loadProducts();

      // Restore any existing purchases
      await restorePurchases();

      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize SubscriptionService: $e');
      _isInitialized = true;
    }
  }

  /// Load available products from the store
  Future<void> _loadProducts() async {
    try {
      final ProductDetailsResponse response =
          await InAppPurchase.instance.queryProductDetails(_productIds);

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load products: $e');
    }
  }

  /// Load premium status from local storage
  Future<void> _loadPremiumStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isPremium = prefs.getBool(_isPremiumKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load premium status: $e');
    }
  }

  /// Save premium status to local storage
  Future<void> _savePremiumStatus(bool isPremium) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isPremiumKey, isPremium);
      if (isPremium) {
        await prefs.setString(_purchaseDateKey, DateTime.now().toIso8601String());
      }
    } catch (e) {
      debugPrint('Failed to save premium status: $e');
    }
  }

  /// Handle purchase updates from the stream
  void _handlePurchaseUpdates(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _isLoading = true;
        notifyListeners();
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _isLoading = false;
          debugPrint('Purchase error: ${purchaseDetails.error}');
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // Verify and deliver the purchase
          _verifyAndDeliverPurchase(purchaseDetails);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          _isLoading = false;
        }

        // Complete the purchase
        if (purchaseDetails.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }

        notifyListeners();
      }
    }
  }

  /// Verify and deliver the purchase
  Future<void> _verifyAndDeliverPurchase(PurchaseDetails purchaseDetails) async {
    // In a production app, you should verify the purchase with your backend
    // For now, we'll trust the purchase and grant premium access
    
    if (purchaseDetails.productID == _removeAdsProductId) {
      _isPremium = true;
      await _savePremiumStatus(true);
      _isLoading = false;
      notifyListeners();
      debugPrint('Premium purchase verified and delivered!');
    }
  }

  /// Purchase the remove ads product
  Future<bool> purchaseRemoveAds() async {
    if (_products.isEmpty) {
      debugPrint('No products available for purchase');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final ProductDetails product = _products.firstWhere(
        (p) => p.id == _removeAdsProductId,
        orElse: () => _products.first,
      );

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      // For non-consumable (one-time purchase to remove ads)
      final bool success = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      if (!success) {
        _isLoading = false;
        notifyListeners();
      }

      return success;
    } catch (e) {
      debugPrint('Failed to initiate purchase: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    try {
      _isLoading = true;
      notifyListeners();

      await InAppPurchase.instance.restorePurchases();

      // Give some time for restore to process
      await Future.delayed(const Duration(seconds: 2));

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to restore purchases: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle debug premium mode (for testing only)
  void toggleDebugPremium() {
    _debugPremiumOverride = !_debugPremiumOverride;
    notifyListeners();
    debugPrint('Debug premium mode: $_debugPremiumOverride');
  }

  /// Set debug premium mode directly
  void setDebugPremium(bool value) {
    _debugPremiumOverride = value;
    notifyListeners();
  }

  /// Get price string for display
  String get priceString {
    if (_products.isEmpty) {
      return '\$2.99'; // Default fallback price
    }
    return _products.first.price;
  }

  /// Dispose resources
  void disposeService() {
    _subscription?.cancel();
  }
}
