import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'config/app_config.dart';
import 'providers/security_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await GoogleSignIn.instance.initialize(
      clientId: '1006905295094-7k5kvhemvostmhtli0r076p5hmqmvdeu.apps.googleusercontent.com',
      serverClientId: '1006905295094-e4bprelr8fs40sf09njvde74hejc5vbe.apps.googleusercontent.com',
    );
  } catch (e) {
    debugPrint('Google Sign-In initialize error: $e');
  }

  // Set system navigation & status bar colors for dark banking theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: DhaVaultApp(),
    ),
  );
}

class DhaVaultApp extends ConsumerStatefulWidget {
  const DhaVaultApp({super.key});

  @override
  ConsumerState<DhaVaultApp> createState() => _DhaVaultAppState();
}

class _DhaVaultAppState extends ConsumerState<DhaVaultApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        ref.read(securityProvider.notifier).onAppPaused();
      } else if (state == AppLifecycleState.resumed) {
        ref.read(securityProvider.notifier).onAppResumed();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}

