import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../shared/services/subscription_service.dart';
import '../../../shared/widgets/animated_background.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _subscriptionService.addListener(_onSubscriptionChanged);
  }

  @override
  void dispose() {
    _subscriptionService.removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (mounted) {
      setState(() {
        _isLoading = _subscriptionService.isLoading;
      });
    }
  }

  Future<void> _handlePurchase() async {
    setState(() => _isLoading = true);
    
    final success = await _subscriptionService.purchaseRemoveAds();
    
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start purchase. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    
    await _subscriptionService.restorePurchases();
    
    if (mounted) {
      if (_subscriptionService.isPremium) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Premium restored successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No previous purchases found.'),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _toggleDebugPremium() {
    _subscriptionService.toggleDebugPremium();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _subscriptionService.isPremium 
              ? '🎉 Debug Premium ENABLED - Ads are now hidden!'
              : '📢 Debug Premium DISABLED - Ads will show again.',
          ),
          backgroundColor: _subscriptionService.isPremium ? Colors.green : Colors.orange,
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = _subscriptionService.isPremium;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Go Premium',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Premium Crown Icon
                FadeInDown(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isPremium 
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : [Colors.amber.shade400, Colors.orange.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isPremium ? Colors.green : Colors.amber).withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      isPremium ? Icons.check_circle : Icons.workspace_premium,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Title
                FadeInDown(
                  delay: const Duration(milliseconds: 100),
                  child: Text(
                    isPremium ? 'You\'re Premium!' : 'Remove All Ads',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Subtitle
                FadeInDown(
                  delay: const Duration(milliseconds: 150),
                  child: Text(
                    isPremium 
                      ? 'Enjoy ad-free file transfers!'
                      : 'One-time purchase • Lifetime access',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Benefits Card
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark 
                        ? Colors.white.withOpacity(0.1) 
                        : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildBenefitItem(
                          icon: Icons.block,
                          title: 'No Banner Ads',
                          subtitle: 'Clean interface without distractions',
                          color: Colors.red,
                          isDark: isDark,
                        ),
                        const Divider(height: 32),
                        _buildBenefitItem(
                          icon: Icons.not_interested,
                          title: 'No Interstitial Ads',
                          subtitle: 'Uninterrupted file transfers',
                          color: Colors.orange,
                          isDark: isDark,
                        ),
                        const Divider(height: 32),
                        _buildBenefitItem(
                          icon: Icons.favorite,
                          title: 'Support Development',
                          subtitle: 'Help us keep improving the app',
                          color: Colors.pink,
                          isDark: isDark,
                        ),
                        const Divider(height: 32),
                        _buildBenefitItem(
                          icon: Icons.all_inclusive,
                          title: 'Lifetime Access',
                          subtitle: 'One-time purchase, forever yours',
                          color: Colors.purple,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Purchase Button (only show if not premium)
                if (!isPremium) ...[
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handlePurchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: Colors.amber.withOpacity(0.4),
                        ),
                        child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.workspace_premium, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  'Get Premium • ${_subscriptionService.priceString}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Restore Purchases Button
                  FadeInUp(
                    delay: const Duration(milliseconds: 350),
                    child: TextButton(
                      onPressed: _isLoading ? null : _handleRestore,
                      child: const Text(
                        'Restore Purchases',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
                
                // Already Premium Message
                if (isPremium)
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Premium Active',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'All ads have been removed',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                
                const SizedBox(height: 32),
                
                // Debug Toggle (for testing)
                FadeIn(
                  delay: const Duration(milliseconds: 400),
                  child: GestureDetector(
                    onLongPress: _toggleDebugPremium,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Long press here to toggle debug premium mode',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.check_circle,
          color: Colors.green.shade400,
          size: 24,
        ),
      ],
    );
  }
}
