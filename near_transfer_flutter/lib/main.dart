import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/background_transfer_service.dart';
import 'shared/services/ad_service.dart';
import 'shared/services/subscription_service.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/settings_provider.dart';
import 'shared/services/group_session_service.dart';

/// Check if running on mobile (Android/iOS)
bool get isMobile {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}

/// Check if running on desktop (Windows/macOS/Linux)
bool get isDesktop {
  if (kIsWeb) return false;
  return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SQLite FFI for desktop platforms FIRST
  // This must happen before any database operations
  if (isDesktop) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  // Only initialize mobile-only services on Android/iOS
  if (isMobile) {
    await NotificationService().init();
    await BackgroundTransferService().initialize();
  }
  
  // Initialize subscription service first (to check premium status before ads)
  // Skip on desktop as in-app purchases use mobile stores
  if (isMobile) {
    await SubscriptionService().initialize();
  }
  
  // AdService - only on mobile
  if (isMobile) {
    await AdService().initialize();
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => GroupSessionService()),
      ],
      child: const NearTransferApp(),
    ),
  );
}

class NearTransferApp extends StatelessWidget {
  const NearTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp.router(
          title: 'NearTransfer',
          theme: AppTheme.lightTheme,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
