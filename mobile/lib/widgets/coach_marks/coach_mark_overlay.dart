import 'package:flutter/material.dart';
import '../../widgets/dha_vault_logo.dart';
import 'animated_coach_arrow.dart';
import 'coach_mark_card.dart';
import 'coach_mark_model.dart';

class CoachMarkOverlay extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  const CoachMarkOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
    required this.onSkip,
  });

  @override
  State<CoachMarkOverlay> createState() => _CoachMarkOverlayState();
}

class _CoachMarkOverlayState extends State<CoachMarkOverlay> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isTransitioning = false;
  bool _isCompletedState = false;

  // Controllers
  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late AnimationController _arrowController;
  late AnimationController _rectTweenController;

  // Target rectangle tracking
  Rect? _currentRect;
  Rect? _previousRect;
  Animation<Rect?>? _rectAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _rectTweenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTargetRect();
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _arrowController.dispose();
    _rectTweenController.dispose();
    super.dispose();
  }

  void _calculateTargetRect({bool animate = false}) {
    if (_currentIndex >= widget.steps.length) {
      setState(() {
        _isCompletedState = true;
        _currentRect = null;
      });
      return;
    }

    final step = widget.steps[_currentIndex];
    final targetContext = step.targetKey.currentContext;

    if (targetContext != null) {
      // Ensure target is visible in scrollable container
      Scrollable.ensureVisible(
        targetContext,
        alignment: 0.45,
        duration: const Duration(milliseconds: 250),
      ).then((_) {
        _updateTargetBounds(step, animate: animate);
      });
    } else {
      _updateTargetBounds(step, animate: animate);
    }
  }

  void _updateTargetBounds(CoachMarkStep step, {bool animate = false}) {
    final renderBox = step.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize && mounted) {
      final offset = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final padding = step.targetPadding;

      final newRect = Rect.fromLTWH(
        offset.dx - padding.left,
        offset.dy - padding.top,
        size.width + padding.horizontal,
        size.height + padding.vertical,
      );

      if (animate && _currentRect != null) {
        _previousRect = _currentRect;
        _rectAnimation = RectTween(begin: _previousRect, end: newRect).animate(
          CurvedAnimation(parent: _rectTweenController, curve: Curves.easeInOutCubic),
        );
        _rectTweenController.forward(from: 0.0);
      }

      setState(() {
        _currentRect = newRect;
        _isTransitioning = false;
      });
    }
  }

  void _handleNext() {
    if (_isTransitioning) return;

    if (_currentIndex < widget.steps.length - 1) {
      setState(() {
        _isTransitioning = true;
        _currentIndex++;
      });
      _calculateTargetRect(animate: true);
    } else if (!_isCompletedState) {
      setState(() {
        _isCompletedState = true;
        _currentRect = null;
      });
    } else {
      _dismiss(completed: true);
    }
  }

  void _dismiss({required bool completed}) {
    _fadeController.reverse().then((_) {
      if (completed) {
        widget.onFinish();
      } else {
        widget.onSkip();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomNavPadding = MediaQuery.of(context).padding.bottom + 65.0; // Account for BottomNav

    return AnimatedBuilder(
      animation: Listenable.merge([
        _fadeController,
        _pulseController,
        _arrowController,
        _rectTweenController,
      ]),
      builder: (context, _) {
        final activeRect = _rectAnimation != null && _rectTweenController.isAnimating
            ? _rectAnimation!.value
            : _currentRect;

        final currentStep = _currentIndex < widget.steps.length ? widget.steps[_currentIndex] : null;

        // Position explanation card & arrow dynamically
        double? cardTop;
        double? cardBottom;
        Offset? arrowStart;
        Offset? arrowEnd;

        if (activeRect != null && currentStep != null && !_isCompletedState) {
          const estimatedCardHeight = 150.0;
          const arrowHeight = 32.0;
          final spaceBelow = screenSize.height - bottomNavPadding - (activeRect.bottom + arrowHeight + 8);
          final spaceAbove = activeRect.top - statusBarHeight - (arrowHeight + 8);

          bool placeBelow;
          if (currentStep.position == CoachMarkPosition.below) {
            placeBelow = true;
          } else if (currentStep.position == CoachMarkPosition.above) {
            placeBelow = false;
          } else {
            // Auto positioning
            placeBelow = spaceBelow >= estimatedCardHeight || spaceBelow >= spaceAbove;
          }

          final targetCenterX = activeRect.center.dx.clamp(48.0, screenSize.width - 48.0);

          if (placeBelow) {
            cardTop = activeRect.bottom + arrowHeight + 8;
            arrowStart = Offset(targetCenterX, cardTop);
            arrowEnd = Offset(targetCenterX, activeRect.bottom + 2);
          } else {
            cardBottom = (screenSize.height - activeRect.top) + arrowHeight + 8;
            final cardBottomY = activeRect.top - arrowHeight - 8;
            arrowStart = Offset(targetCenterX, cardBottomY);
            arrowEnd = Offset(targetCenterX, activeRect.top - 2);
          }
        }

        return FadeTransition(
          opacity: _fadeController,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Spotlight Cutout Background Mask
              CustomPaint(
                size: Size.infinite,
                painter: _SpotlightPainter(
                  targetRect: activeRect,
                  borderRadius: currentStep?.borderRadius ?? 14.0,
                  pulseValue: _pulseController.value,
                  overlayOpacity: _fadeController.value,
                ),
              ),

              // Animated Dotted Arrow (when target active)
              if (arrowStart != null && arrowEnd != null && !_isCompletedState)
                AnimatedCoachArrow(
                  start: arrowStart,
                  end: arrowEnd,
                  animationValue: _arrowController.value,
                  pulseValue: _pulseController.value,
                ),

              // Explanation Card (Positioned dynamically)
              if (!_isCompletedState && currentStep != null)
                Positioned(
                  top: cardTop,
                  bottom: cardBottom,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: CoachMarkCard(
                      title: currentStep.title,
                      description: currentStep.description,
                      stepIndex: _currentIndex,
                      totalSteps: widget.steps.length,
                      onNext: _handleNext,
                      onSkip: () => _dismiss(completed: false),
                    ),
                  ),
                ),

              // Final Completion Modal: "You're all set."
              if (_isCompletedState)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 380),
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF334155),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.16),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Celebratory Official 3D Shield Logo
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const DhaVaultLogo(size: 64),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "You're all set.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Explore your secure vault and start adding your documents.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            child: InkWell(
                              onTap: () => _dismiss(completed: true),
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Get Started',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double borderRadius;
  final double pulseValue;
  final double overlayOpacity;

  _SpotlightPainter({
    required this.targetRect,
    required this.borderRadius,
    required this.pulseValue,
    required this.overlayOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final screenPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final bgPaint = Paint()..color = const Color(0xFF090D16).withValues(alpha: 0.82 * overlayOpacity);

    if (targetRect == null) {
      canvas.drawPath(screenPath, bgPaint);
      return;
    }

    final rrect = RRect.fromRectAndRadius(targetRect!, Radius.circular(borderRadius));
    final cutoutPath = Path()..addRRect(rrect);
    final combinedPath = Path.combine(PathOperation.difference, screenPath, cutoutPath);

    // Draw dimmed background overlay everywhere outside cutout
    canvas.drawPath(combinedPath, bgPaint);

    // Soft outer glow around the spotlight
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..color = const Color(0xFF06B6D4).withValues(alpha: (0.35 + 0.35 * pulseValue) * overlayOpacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawRRect(rrect, glowPaint);

    // Crisp cyan border around the spotlight
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = const Color(0xFF38BDF8).withValues(alpha: (0.65 + 0.35 * pulseValue) * overlayOpacity);
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.overlayOpacity != overlayOpacity ||
        oldDelegate.borderRadius != borderRadius;
  }
}
