import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../shared/screens/main_screen.dart';
import '../features/receive/screens/receive_screen.dart';
import '../features/discovery/screens/device_discovery_screen.dart';
import '../features/file_manager/screens/file_manager_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/app_sharing/screens/app_manager_screen.dart';
import '../features/clipboard_sync/screens/clipboard_screen.dart';
import '../features/contact_sharing/screens/contact_manager_screen.dart';
import '../features/shake_connect/screens/shake_connect_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const MainScreen(),
    ),
    GoRoute(
      path: '/receive',
      builder: (context, state) => const ReceiveScreen(),
    ),
    GoRoute(
      path: '/discovery',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Map<String, dynamic>) {
          if (extra['type'] == 'clipboard') {
            return DeviceDiscoveryScreen(
              clipboardContent: extra['content'] as String?,
            );
          } else if (extra['type'] == 'contacts') {
            return DeviceDiscoveryScreen(
              clipboardContent: extra['content'] as String?,
              fileName: extra['fileName'] as String? ?? 'contacts.vcf',
            );
          }
        } else if (extra is List<PlatformFile>) {
          return DeviceDiscoveryScreen(
            preSelectedFiles: extra,
          );
        }
        return const DeviceDiscoveryScreen();
      },
    ),
    GoRoute(
      path: '/app-manager',
      builder: (context, state) => const AppManagerScreen(),
    ),
    GoRoute(
      path: '/clipboard',
      builder: (context, state) => const ClipboardScreen(),
    ),
    GoRoute(
      path: '/contact-manager',
      builder: (context, state) => const ContactManagerScreen(),
    ),
    GoRoute(
      path: '/shake-connect',
      builder: (context, state) => const ShakeConnectScreen(),
    ),
    GoRoute(
      path: '/file-manager',
      builder: (context, state) => const FileManagerScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
  ],
);
