import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/widgets/app_assets.dart';
import '../../../shared/widgets/status_view.dart';

class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key, this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return StatusView(
      asset: AppAssets.illusNoInternet,
      title: 'No connection',
      message:
          "You're offline. You can still play pass-and-play and bot matches!",
      actionLabel: 'Play offline',
      onAction: onRetry ?? () => context.go(AppRoutes.home),
    );
  }
}

/// Generic error screen (e.g. for unexpected failures).
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key, this.message, this.onAction});
  final String? message;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return StatusView(
      asset: AppAssets.illusError,
      title: 'Something went wrong',
      message: message ?? 'Please try again in a moment.',
      actionLabel: 'Back to menu',
      onAction: onAction ?? () => context.go(AppRoutes.home),
    );
  }
}
