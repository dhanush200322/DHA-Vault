import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Pixel-perfect vector painter for the official Google 'G' 4-color icon
class GoogleLogo extends StatelessWidget {
  final double size;
  const GoogleLogo({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _GoogleLogoPainter(),
        ),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final Offset center = Offset(r, r);
    final double strokeWidth = size.width * 0.22;
    final double arcRadius = r - strokeWidth / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: arcRadius);

    final Paint bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Paint greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Paint yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Paint redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Paint blueFill = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    // 1. Blue horizontal crossbar into center
    final Rect barRect = Rect.fromLTRB(
      center.dx,
      center.dy - strokeWidth / 2,
      size.width,
      center.dy + strokeWidth / 2,
    );
    canvas.drawRect(barRect, blueFill);

    // 2. Arcs for the 4 Google colors
    // Blue arc (bottom-right ending at horizontal bar)
    canvas.drawArc(rect, 0, math.pi / 4, false, bluePaint);

    // Green arc (bottom)
    canvas.drawArc(rect, math.pi / 4, math.pi / 2, false, greenPaint);

    // Yellow arc (left)
    canvas.drawArc(rect, 3 * math.pi / 4, math.pi / 2, false, yellowPaint);

    // Red arc (top)
    canvas.drawArc(rect, 5 * math.pi / 4, math.pi / 2, false, redPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Premium Google Sign-In button engineered with DHA Vault banking dark aesthetics
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;

  const GoogleSignInButton({
    super.key,
    this.onPressed,
    this.text = 'Continue with Google',
    this.isLoading = false,
  });

  static void showGoogleAuthSheet(
    BuildContext context, {
    void Function(String email, String name)? onSelectAccount,
    VoidCallback? onSelectDemo,
    VoidCallback? onUseSystemChooser,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    GoogleLogo(size: 24),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Choose a Google Account',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'to sign in and open DHA Vault',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.border),
                const SizedBox(height: 10),

                // Account 1 (Primary Detected Phone Account)
                _buildAccountTile(
                  ctx: ctx,
                  name: 'Dhanush',
                  email: 'ro224313@gmail.com',
                  initial: 'D',
                  color: AppTheme.primary,
                  isVerified: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (onSelectAccount != null) {
                      onSelectAccount('ro224313@gmail.com', 'Dhanush');
                    } else if (onSelectDemo != null) {
                      onSelectDemo();
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Account 2 (Google Cloud Developer Account)
                _buildAccountTile(
                  ctx: ctx,
                  name: 'Dhanush R',
                  email: 'dhanush200322@gmail.com',
                  initial: 'D',
                  color: AppTheme.accentPurple,
                  isVerified: false,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (onSelectAccount != null) {
                      onSelectAccount('dhanush200322@gmail.com', 'Dhanush R');
                    } else if (onSelectDemo != null) {
                      onSelectDemo();
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Account 3 (Secondary Google Account)
                _buildAccountTile(
                  ctx: ctx,
                  name: 'Dhanush Personal',
                  email: 'dhanush.developer@gmail.com',
                  initial: 'D',
                  color: AppTheme.accentGreen,
                  isVerified: false,
                  onTap: () {
                    Navigator.pop(ctx);
                    if (onSelectAccount != null) {
                      onSelectAccount('dhanush.developer@gmail.com', 'Dhanush Personal');
                    } else if (onSelectDemo != null) {
                      onSelectDemo();
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Account 4 / Add Any Google Account
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showAddGoogleAccountDialog(
                        context,
                        onSelectAccount: onSelectAccount,
                        onSelectDemo: onSelectDemo,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.person_add_alt_outlined, color: AppTheme.primaryLight, size: 22),
                          SizedBox(width: 14),
                          Text(
                            'Add another Google account',
                            style: TextStyle(color: AppTheme.primaryLight, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (onUseSystemChooser != null) ...[
                  const SizedBox(height: 4),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.pop(ctx);
                        onUseSystemChooser();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.devices, color: AppTheme.textSecondary, size: 20),
                            SizedBox(width: 14),
                            Text(
                              'Select from Android System Accounts',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security, color: AppTheme.accentGreen, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '256-bit AES client-side encryption is preserved with Google OAuth.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildAccountTile({
    required BuildContext ctx,
    required String name,
    required String email,
    required String initial,
    required Color color,
    required bool isVerified,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppTheme.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color,
                child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (isVerified)
                const Icon(Icons.check_circle_outline, color: AppTheme.accentGreen, size: 20)
              else
                const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  static void _showAddGoogleAccountDialog(
    BuildContext context, {
    void Function(String email, String name)? onSelectAccount,
    VoidCallback? onSelectDemo,
  }) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: const Row(
          children: [
            GoogleLogo(size: 20),
            SizedBox(width: 10),
            Text('Enter Gmail Account', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your Google email to connect with your vault:',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                hintText: 'user@gmail.com',
                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final email = controller.text.trim();
              if (email.isNotEmpty && email.contains('@')) {
                Navigator.pop(dialogCtx);
                final name = email.split('@')[0];
                if (onSelectAccount != null) {
                  onSelectAccount(email, name);
                } else if (onSelectDemo != null) {
                  onSelectDemo();
                }
              }
            },
            child: const Text('Connect & Enter'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isLoading ? null : onPressed,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.border,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight),
                )
              else ...[
                const GoogleLogo(size: 20),
                const SizedBox(width: 14),
                Text(
                  text,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
