import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_assets.dart';

/// Blocking overlay shown over an online match while the WebSocket reconnects.
/// Drop this into a Stack when connection drops (Phase 2 wiring).
class ReconnectOverlay extends StatelessWidget {
  const ReconnectOverlay({super.key, this.onCancel});
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ModalBarrier(color: Colors.black54, dismissible: false),
        Center(
          child: Container(
            padding: const EdgeInsets.all(28),
            margin: const EdgeInsets.symmetric(horizontal: 40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 90,
                  child: Lottie.asset(
                    AppAssets.loading,
                    errorBuilder: (_, __, ___) =>
                        const CircularProgressIndicator(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Reconnecting…', style: AppTextStyles.title),
                const SizedBox(height: 6),
                Text('Hold tight — restoring your game.',
                    style: AppTextStyles.bodyMuted,
                    textAlign: TextAlign.center),
                if (onCancel != null) ...[
                  const SizedBox(height: 16),
                  TextButton(onPressed: onCancel, child: const Text('Leave')),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
