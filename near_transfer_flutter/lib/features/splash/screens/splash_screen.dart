import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  bool _navigated = false;
  
  static const String _onboardingCompleteKey = 'onboarding_complete';

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Reduced from 1500ms
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    // Listen for animation completion
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_navigated) {
        _checkTermsAndNavigate();
      }
    });

    _progressController.forward();
  }

  Future<void> _checkTermsAndNavigate() async {
    if (!mounted || _navigated) return;
    
    _navigated = true;
    
    bool termsAccepted = false;
    bool onboardingComplete = false;
    
    // Check if terms have been accepted (with error handling for web)
    try {
      final prefs = await SharedPreferences.getInstance();
      termsAccepted = prefs.getBool('terms_accepted') ?? false;
      onboardingComplete = prefs.getBool(_onboardingCompleteKey) ?? false;
    } catch (e) {
      // On error, show terms screen
      termsAccepted = false;
    }
    
    // Small delay to ensure UI shows 100%
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (mounted) {
      if (!onboardingComplete) {
        GoRouter.of(context).go('/onboarding');
      } else if (!termsAccepted) {
        GoRouter.of(context).go('/terms');
      } else {
        GoRouter.of(context).go('/home');
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E), // Deep Blue - matches home
              Color(0xFF283593), // Medium Blue
              Color(0xFF00695C), // Teal - matches home
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),
              
              // Logo with animation - matching native splash style
              FadeInDown(
                duration: const Duration(milliseconds: 800),
                child: SizedBox(
                  width: 150,
                  height: 150,
                  child: Image.asset(
                    'assets/app_icon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.swap_horiz,
                        size: 100,
                        color: Colors.white,
                      );
                    },
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // App Name
              FadeInUp(
                delay: const Duration(milliseconds: 300),
                duration: const Duration(milliseconds: 800),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF0077B6),
                      Color(0xFF00B4D8),
                      Color(0xFF48CAE4),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    'NearTransfer',
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Tagline
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                duration: const Duration(milliseconds: 800),
                child: Text(
                  'Phone to PC • Cross-Platform Transfer',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              
              const Spacer(flex: 2),
              
              // Progress Bar
              FadeInUp(
                delay: const Duration(milliseconds: 700),
                duration: const Duration(milliseconds: 600),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Column(
                    children: [
                      _buildProgressBar(),
                      const SizedBox(height: 16),
                      _buildProgressText(),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Version text
              FadeIn(
                delay: const Duration(milliseconds: 900),
                child: Text(
                  'v1.0.0',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white38,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: Colors.white.withValues(alpha: 0.2),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: _progressAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF00B4D8),
                      Color(0xFF48CAE4),
                      Colors.white,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00B4D8).withValues(alpha: 0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressText() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Text(
          '${(_progressAnimation.value * 100).toInt()}%',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        );
      },
    );
  }
}

