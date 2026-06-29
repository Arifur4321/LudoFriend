import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_text_styles.dart';
import 'app_background.dart';
import 'primary_button.dart';

/// Reusable full-screen status layout used for no-internet, error and other
/// empty/blocking states.
class StatusView extends StatelessWidget {
  const StatusView({
    super.key,
    required this.asset,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String asset;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(asset, height: 200),
                  const SizedBox(height: 28),
                  Text(title,
                      style: AppTextStyles.display,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Text(message,
                      style: AppTextStyles.body.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center),
                  if (actionLabel != null) ...[
                    const SizedBox(height: 28),
                    PrimaryButton(
                        label: actionLabel!,
                        onPressed: onAction,
                        expand: false),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
