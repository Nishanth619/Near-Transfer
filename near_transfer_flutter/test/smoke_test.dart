import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:near_transfer_flutter/main.dart';
import 'package:near_transfer_flutter/shared/providers/theme_provider.dart';
import 'package:near_transfer_flutter/shared/providers/settings_provider.dart';
import 'package:near_transfer_flutter/shared/services/group_session_service.dart';

/// Smoke tests verify that the app launches correctly and basic UI elements load
void main() {
  Widget createTestApp() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => GroupSessionService()),
      ],
      child: const NearTransferApp(),
    );
  }
  
  group('App Smoke Tests', () {
    testWidgets('App launches without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(seconds: 1));
      
      expect(find.byType(MaterialApp), findsOneWidget);
    });
    
    testWidgets('App has Scaffold structure', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      expect(find.byType(Scaffold), findsWidgets);
    });
  });
  
  group('Theme Tests', () {
    testWidgets('ThemeProvider initializes correctly', (WidgetTester tester) async {
      final themeProvider = ThemeProvider();
      
      expect(themeProvider.isDarkMode, isNotNull);
    });
  });
  
  group('Settings Tests', () {
    testWidgets('SettingsProvider initializes correctly', (WidgetTester tester) async {
      final settingsProvider = SettingsProvider();
      
      expect(settingsProvider, isNotNull);
    });
  });
}
