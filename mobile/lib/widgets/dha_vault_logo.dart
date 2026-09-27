import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Official DHA Vault Reusable Brand Logo Component
/// Displays the official shield, document, and lock identity
/// with optional wordmark and taglines.
class DhaVaultLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;
  final String wordmarkText;
  final double? wordmarkSize;
  final String? subtitle;
  final BoxFit fit;
  final String semanticLabel;
  final bool useHero;
  final bool softEdges;

  const DhaVaultLogo({
    super.key,
    this.size = 48.0,
    this.showWordmark = false,
    this.wordmarkText = 'DHA Vault',
    this.wordmarkSize,
    this.subtitle,
    this.fit = BoxFit.contain,
    this.semanticLabel = 'DHA Vault Official Logo',
    this.useHero = false,
    this.softEdges = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoImage = Image.asset(
      'assets/branding/dha_vault_logo.png',
      width: size,
      height: size,
      fit: fit,
      semanticLabel: semanticLabel,
      filterQuality: FilterQuality.high,
    );

    if (softEdges) {
      logoImage = ShaderMask(
        shaderCallback: (Rect bounds) {
          return const RadialGradient(
            center: Alignment.center,
            radius: 0.5,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.70, 0.98],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: logoImage,
      );
    }

    if (useHero) {
      logoImage = Hero(
        tag: 'dha_vault_brand_logo',
        child: logoImage,
      );
    }

    if (!showWordmark) {
      return logoImage;
    }

    final double effectiveWordmarkSize = wordmarkSize ?? (size >= 80 ? 24.0 : 18.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        logoImage,
        const SizedBox(height: 12),
        Text(
          wordmarkText,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: effectiveWordmarkSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppTheme.textPrimary,
              ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              color: AppTheme.primaryLight,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ],
    );
  }
}
