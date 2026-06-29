import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';
import '../theme/app_text_styles.dart';
import 'bouncing_button.dart';

/// The standard gradient pill button used across menus.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient = AppGradients.primaryButton,
    this.icon,
    this.leading,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final IconData? icon;
  final Widget? leading;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return BouncingButton(
      onTap: loading ? null : onPressed,
      child: Container(
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            else ...[
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
              ],
              Text(label, style: AppTextStyles.button),
            ],
          ],
        ),
      ),
    );
  }
}
