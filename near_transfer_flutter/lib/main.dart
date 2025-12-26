import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'shared/services/notification_service.dart';
import 'shared/services/background_transfer_service.dart';
import 'shared/services/ad_service.dart';
import 'shared/services/subscription_service.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/settings_provider.dart';
import 'shared/services/group_session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Only initialize mobile-only services on non-web platforms
  if (!kIsWeb) {
    await NotificationService().init();
    await BackgroundTransferService().initialize();
  }
  
  // Initialize subscription service first (to check premium status before ads)
  await SubscriptionService().initialize();
  
  // AdService has its own web check
  await AdService().initialize();
  
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
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
