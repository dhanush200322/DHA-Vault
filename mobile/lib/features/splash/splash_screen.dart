import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/security_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dha_vault_logo.dart';

/// Premium 3.0 - 3.4 Second Startup Splash Experience
///
/// Features a coordinated GPU-friendly sequence:
/// 1. 0.00s - 0.40s: Dark navy background + ambient blue radial halo
/// 2. 0.40s - 1.10s: Logo reveal (scale 0.78 -> 1.0, opacity 0.0 -> 1.0, easeOutCubic)
/// 3. 1.10s - 1.80s: Electric-blue / cyan security bloom around shield
/// 4. 1.80s - 2.40s: Security pulse light sweep across shield & lock
/// 5. 2.40s - 3.00s: Brand confirmation (DHA Vault typography & hold)
/// 6. 3.00s - 3.30s: Smooth fade & gentle scale transition to destination
///
/// Runs async authentication & vault initialization in parallel.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Background ambient glow
  late final Animation<double> _glowOpacity;
  late final Animation<double> _glowRadius;

  // Logo Reveal (0.40s - 1.10s)
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // Security Glow bloom (1.10s - 1.80s)
  late final Animation<double> _securityGlow;

  // Security Light Sweep (1.80s - 2.40s)
  late final Animation<double> _sweepProgress;

  // Minimal Brand Text (2.15s - 2.80s)
  late final Animation<double> _textOpacity;
  late final Animation<double> _textSlide;

  // Exit transition (3.00s - 3.30s)
  late final Animation<double> _exitOpacity;
  late final Animation<double> _exitScale;

  Future<void>? _initFuture;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3300),
    );

    // 0.00s - 0.45s (0.00 - 0.35): Ambient glow
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.35, curve: Curves.easeOut),
      ),
    );

    _glowRadius = Tween<double>(begin: 140.0, end: 250.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    // 0.40s - 1.10s (0.12 - 0.33): Logo reveal
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 0.33, curve: Curves.easeOutCubic),
      ),
    );

    _logoScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    // 1.10s - 1.80s (0.33 - 0.55): Security glow bloom
    _securityGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.33, 0.55, curve: Curves.easeInOutCubic),
      ),
    );

    // 1.80s - 2.40s (0.55 - 0.73): Light sweep across shield & lock
    _sweepProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.73, curve: Curves.easeInOutCubic),
      ),
    );

    // 2.15s - 2.80s (0.65 - 0.85): Minimal brand text reveal
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 0.85, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.65, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    // 3.00s - 3.30s (0.91 - 1.00): Exit transition
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.91, 1.00, curve: Curves.easeInQuad),
      ),
    );

    _exitScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.91, 1.00, curve: Curves.easeOutQuad),
      ),
    );

    // Parallel app initialization
    _initFuture = _initializeApp();

    // Start animation timeline
    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onAnimationComplete();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Accessibility: Honor reduced motion preference
    if (MediaQuery.of(context).disableAnimations && !_hasNavigated) {
      _controller.duration = const Duration(milliseconds: 900);
      if (_controller.isAnimating) {
        _controller.forward(from: 0.8);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Warm up providers in parallel while animation runs
      ref.read(authProvider);
      ref.read(securityProvider);
    } catch (_) {
      // Non-blocking fallback
    }
  }

  Future<void> _onAnimationComplete() async {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    // Ensure async initialization finished
    if (_initFuture != null) {
      await _initFuture;
    }
    if (!mounted) return;

    final authState = ref.read(authProvider);
    final securityState = ref.read(securityProvider);

    // Authentication-aware routing
    if (authState.isAuthenticated) {
      if (securityState.isUnlocked) {
        context.go('/home');
      } else {
        context.go('/unlock');
      }
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _exitOpacity.value,
            child: Transform.scale(
              scale: _exitScale.value,
              child: child,
            ),
          );
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Stack with dynamic ambient glow and light sweep
              SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1. Ambient deep-blue radial halo
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final double opacity = _glowOpacity.value;
                        final double radius = _glowRadius.value;
                        return Container(
                          width: radius,
                          height: radius,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF1D4ED8).withValues(alpha: 0.32 * opacity),
                                const Color(0xFF0EA5E9).withValues(alpha: 0.16 * opacity),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.48, 1.0],
                            ),
                          ),
                        );
                      },
                    ),

                    // 2. Focused cyan security bloom
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final double bloom = _securityGlow.value;
                        if (bloom <= 0.0) return const SizedBox.shrink();
                        return Container(
                          width: 175.0 + (30.0 * bloom),
                          height: 175.0 + (30.0 * bloom),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF06B6D4).withValues(alpha: 0.28 * bloom),
                                const Color(0xFF3B82F6).withValues(alpha: 0.14 * bloom),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                        );
                      },
                    ),

                    // 3. Logo reveal with security light sweep
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final double logoOp = _logoOpacity.value;
                        final double logoSc = _logoScale.value;
                        final double sweep = _sweepProgress.value;

                        return Opacity(
                          opacity: logoOp,
                          child: Transform.scale(
                            scale: logoSc,
                            child: ShaderMask(
                              blendMode: BlendMode.srcATop,
                              shaderCallback: (Rect bounds) {
                                if (sweep <= 0.0 || sweep >= 1.0) {
                                  return const LinearGradient(
                                    colors: [Colors.transparent, Colors.transparent],
                                  ).createShader(bounds);
                                }
                                final double pos = -0.7 + (sweep * 2.4);
                                return LinearGradient(
                                  begin: Alignment(pos - 0.5, -1.0),
                                  end: Alignment(pos + 0.5, 1.0),
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.15),
                                    const Color(0xFF67E8F9).withValues(alpha: 0.45),
                                    Colors.white.withValues(alpha: 0.15),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.35, 0.50, 0.65, 1.0],
                                ).createShader(bounds);
                              },
                              child: const DhaVaultLogo(
                                size: 136,
                                useHero: false,
                                softEdges: true,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 4. Subtle brand confirmation text
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final double textOp = _textOpacity.value;
                  final double textDy = _textSlide.value;

                  return Opacity(
                    opacity: textOp,
                    child: Transform.translate(
                      offset: Offset(0, textDy),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'DHA Vault',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  letterSpacing: 0.3,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  fontSize: 22,
                                ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Encrypted Digital Locker',
                            style: TextStyle(
                              color: AppTheme.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
