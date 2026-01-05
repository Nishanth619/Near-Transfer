import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:near_transfer_flutter/main.dart';
import 'package:near_transfer_flutter/shared/providers/theme_provider.dart';
import 'package:near_transfer_flutter/shared/providers/settings_provider.dart';
import 'package:near_transfer_flutter/shared/services/group_session_service.dart';

/// Integration tests that verify multiple components work together
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

  group('App Integration Tests', () {
    testWidgets('App initializes all required widgets', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(seconds: 1));
      
      // Verify core widget tree structure
      expect(find.byType(MaterialApp), findsOneWidget);
    });
    
    testWidgets('App handles rapid rebuilds without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      
      // Simulate rapid rebuilds
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      
      expect(find.byType(MaterialApp), findsOneWidget);
    });
    
    testWidgets('App renders safely with different screen sizes', (WidgetTester tester) async {
      // Small screen (mobile)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MaterialApp), findsOneWidget);
      
      // Reset
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    
    testWidgets('App renders safely on large screen (desktop)', (WidgetTester tester) async {
      // Large screen (desktop)
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      
      await tester.pumpWidget(createTestApp());
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(MaterialApp), findsOneWidget);
      
      // Reset
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
  
  group('Provider Integration Tests', () {
    testWidgets('All providers are accessible from widget tree', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // The app should build without Provider errors
      expect(tester.takeException(), isNull);
    });
  });
  
  group('Navigation Flow Tests', () {
    testWidgets('Initial route loads correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle(const Duration(seconds: 3));
      
      // App should navigate to splash/home without errors
      expect(tester.takeException(), isNull);
    });
  });
  
  group('Stability Tests', () {
    testWidgets('App remains stable after multiple pump calls', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp());
      
      // Multiple pump calls to ensure stability
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }
      
      // App should still be functional
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
