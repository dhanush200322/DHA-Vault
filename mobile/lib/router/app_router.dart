import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/documents/document_details_screen.dart';
import '../features/documents/document_viewer_screen.dart';
import '../features/documents/document_intelligence_screen.dart';
import '../features/documents/documents_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/scanner/scanner_screen.dart';
import '../features/security/vault_unlock_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/backup_sync_screen.dart';
import '../features/devices/devices_screen.dart';
import '../features/family/family_vault_screen.dart';
import '../features/emergency/emergency_access_screen.dart';
import '../features/sharing/shared_screen.dart';
import '../features/splash/splash_screen.dart';
import '../models/document.dart';
import '../navigation/main_scaffold.dart';
import '../providers/auth_provider.dart';
import '../providers/security_provider.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authProvider);
      final secState = ref.read(securityProvider);

      final isSplash = state.matchedLocation == '/';
      final isAuthRoute = state.matchedLocation == '/welcome' ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (isSplash) return null;

      if (!authState.isAuthenticated) {
        return isAuthRoute ? null : '/welcome';
      }

      // If user is authenticated but vault is locked, route to unlock
      if (!secState.isUnlocked && state.matchedLocation != '/unlock') {
        return '/unlock';
      }

      // If unlocked and on auth screen, send to home
      if (authState.isAuthenticated && secState.isUnlocked && (isAuthRoute || state.matchedLocation == '/unlock')) {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/unlock',
        builder: (context, state) => const VaultUnlockScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/documents',
            builder: (context, state) => const DocumentsScreen(),
          ),
          GoRoute(
            path: '/scan',
            builder: (context, state) => const ScannerScreen(),
          ),
          GoRoute(
            path: '/shared',
            builder: (context, state) => const SharedScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/document-details/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final doc = state.extra as DocumentModel?;
          return DocumentDetailsScreen(documentId: id, initialDocument: doc);
        },
      ),
      GoRoute(
        path: '/document-viewer/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final doc = state.extra as DocumentModel?;
          return DocumentViewerScreen(documentId: id, document: doc);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/document-intelligence/:id',
        builder: (context, state) {
          final doc = state.extra as DocumentModel;
          return DocumentIntelligenceScreen(document: doc);
        },
      ),
      GoRoute(
        path: '/backup-sync',
        builder: (context, state) => const BackupSyncScreen(),
      ),
      GoRoute(
        path: '/devices',
        builder: (context, state) => const DevicesScreen(),
      ),
      GoRoute(
        path: '/family',
        builder: (context, state) => const FamilyVaultScreen(),
      ),
      GoRoute(
        path: '/emergency-access',
        builder: (context, state) => const EmergencyAccessScreen(),
      ),
    ],
  );
});
