import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../features/splash/screens/splash_screen.dart';
import '../features/onboarding/screens/terms_screen.dart';
import '../features/onboarding/screens/onboarding_screen.dart';
import '../shared/screens/main_screen.dart';
import '../features/receive/screens/receive_screen.dart';
import '../features/discovery/screens/device_discovery_screen.dart';
import '../features/file_manager/screens/file_manager_screen.dart';
import '../features/history/screens/history_screen.dart';
import '../features/app_sharing/screens/app_manager_screen.dart';
import '../features/clipboard_sync/screens/clipboard_screen.dart';
import '../features/contact_sharing/screens/contact_manager_screen.dart';
import '../features/shake_connect/screens/shake_connect_screen.dart';
import '../features/resume/screens/resume_transfer_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/group_transfer/screens/group_progress_screen.dart';
import '../features/group_transfer/screens/device_selection_screen.dart';
import '../features/speed_test/screens/speed_test_screen.dart';
import '../features/radar/screens/radar_screen.dart';
import '../features/premium/screens/premium_screen.dart';
import '../shared/models/discovered_device.dart';
import '../shared/providers/transfer_orchestrator.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    // Splash screen on app start
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    // Terms and Conditions screen (first launch)
    GoRoute(
      path: '/terms',
      builder: (context, state) => const TermsAndConditionsScreen(),
    ),
    // Onboarding screen (first-time users after terms)
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => OnboardingScreen(
        onComplete: () => GoRouter.of(context).go('/terms'),
      ),
    ),
    // Main home screen
    GoRoute(
      path: '/home',
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
        
        // Handle pre-selected device from shake-to-connect (with optional orchestrator)
        if (extra is DiscoveredDevice) {
          return DeviceDiscoveryScreen(
            preSelectedDevice: extra,
          );
        }
        else if (extra is Map<String, dynamic> && extra.containsKey('device') && extra['device'] is DiscoveredDevice) {
           return DeviceDiscoveryScreen(
            preSelectedDevice: extra['device'] as DiscoveredDevice,
            preConfiguredOrchestrator: extra['orchestrator'] as dynamic, // Cast as dynamic first to avoid import issues if needed, or import TransferOrchestrator
          );
        }
        // Handle clipboard/contacts
        else if (extra is Map<String, dynamic>) {
          if (extra['type'] == 'clipboard') {
            return DeviceDiscoveryScreen(
              clipboardContent: extra['content'] as String?,
            );
          } else if (extra['type'] == 'contacts') {
            return DeviceDiscoveryScreen(
              clipboardContent: extra['content'] as String?,
              fileName: extra['fileName'] as String? ?? 'contacts.vcf',
            );
          } else if (extra.containsKey('files') && extra['files'] is List<PlatformFile>) {
            // Handle files from file manager
            return DeviceDiscoveryScreen(
              preSelectedFiles: extra['files'] as List<PlatformFile>,
            );
          }
        } 
        // Handle pre-selected files (direct List)
        else if (extra is List<PlatformFile>) {
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
    GoRoute(
      path: '/resume',
      builder: (context, state) {
        final orchestrator = state.extra as TransferOrchestrator;
        return ResumeTransferScreen(orchestrator: orchestrator);
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/premium',
      name: 'premium',
      builder: (context, state) => const PremiumScreen(),
    ),
    GoRoute(
      path: '/device-selection',
      name: 'device-selection',
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        final devices = data['devices'] as List<DiscoveredDevice>;
        final files = data['files'] as List<PlatformFile>;
        return DeviceSelectionScreen(
          devices: devices,
          files: files,
        );
      },
    ),
    GoRoute(
      path: '/group-progress',
      name: 'group-progress',
      builder: (context, state) {
        final groupId = state.extra as String;
        return GroupProgressScreen(groupId: groupId);
      },
    ),
    GoRoute(
      path: '/speed-test',
      name: 'speed-test',
      builder: (context, state) => const SpeedTestScreen(),
    ),
    GoRoute(
      path: '/radar',
      name: 'radar',
      builder: (context, state) => const RadarScreen(),
    ),
  ],
);
