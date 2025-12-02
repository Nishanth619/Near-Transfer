import 'package:flutter/material.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'shared/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const NearTransferApp());
}

class NearTransferApp extends StatelessWidget {
  const NearTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'NearTransfer',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
