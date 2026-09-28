import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/document.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// A robust, overlay-based notification popup that auto-dismisses after exactly 2 seconds.
/// Unlike Flutter's SnackBar with SnackBarAction, this popup is NOT hijacked by Android OS
/// accessibility timeouts (which override durations to 1 day on devices with accessibility flags).
class VaultPopup {
  static OverlayEntry? _activeEntry;
  static Timer? _activeTimer;

  static void showSaved(
    BuildContext context, {
    required DocumentModel document,
    Duration duration = const Duration(seconds: 2),
  }) {
    // 1. Wipe out any lingering Flutter SnackBars from previous screens/states
    final navContext = rootNavigatorKey.currentContext ?? context;
    try {
      ScaffoldMessenger.maybeOf(navContext)?.clearSnackBars();
    } catch (_) {}

    // 2. Dismiss any existing popup cleanly
    dismiss();

    // 3. Resolve the top-level overlay
    final overlayState = rootNavigatorKey.currentState?.overlay ?? Overlay.maybeOf(context);
    if (overlayState == null) return;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _VaultPopupWidget(
        document: document,
        duration: duration,
        onDismiss: () => dismiss(),
        onIntelligencePressed: () {
          dismiss();
          final targetContext = rootNavigatorKey.currentContext ?? context;
          targetContext.push('/document-intelligence/${document.id}', extra: document);
        },
      ),
    );

    _activeEntry = entry;
    overlayState.insert(entry);

    // Hard fallback safety timer to ensure clean removal from overlay tree
    _activeTimer = Timer(duration + const Duration(milliseconds: 250), () {
      dismiss();
    });
  }

  static void dismiss() {
    _activeTimer?.cancel();
    _activeTimer = null;
    if (_activeEntry != null) {
      try {
        _activeEntry?.remove();
      } catch (_) {}
      _activeEntry = null;
    }
  }
}

class _VaultPopupWidget extends StatefulWidget {
  final DocumentModel document;
  final Duration duration;
  final VoidCallback onDismiss;
  final VoidCallback onIntelligencePressed;

  const _VaultPopupWidget({
    required this.document,
    required this.duration,
    required this.onDismiss,
    required this.onIntelligencePressed,
  });

  @override
  State<_VaultPopupWidget> createState() => _VaultPopupWidgetState();
}

class _VaultPopupWidgetState extends State<_VaultPopupWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    const animDuration = Duration(milliseconds: 250);
    _controller = AnimationController(
      vsync: this,
      duration: animDuration,
      reverseDuration: animDuration,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _controller.forward();

    // Start auto-reverse timer so total visible time matches exactly 2.0 seconds
    final holdDuration = widget.duration > animDuration
        ? widget.duration - animDuration
        : const Duration(milliseconds: 1750);

    _dismissTimer = Timer(holdDuration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismiss();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleManualDismiss() {
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 100) {
                _handleManualDismiss();
              }
            },
            child: Material(
              color: AppTheme.accentGreen,
              elevation: 8,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.document.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'saved to Vault!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: widget.onIntelligencePressed,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Intelligence'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
