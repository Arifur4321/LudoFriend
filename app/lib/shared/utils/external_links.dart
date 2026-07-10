import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in the device's default browser (external application).
///
/// Used for the public legal pages (privacy / terms / data deletion). It never
/// throws to the caller; if the link can't be opened it shows a SnackBar. The
/// [ScaffoldMessenger] is captured before the first `await` so we don't use a
/// [BuildContext] across an async gap.
Future<void> openExternalUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final uri = Uri.tryParse(url);
  if (uri == null) {
    messenger?.showSnackBar(const SnackBar(content: Text('Invalid link.')));
    return;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger?.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  } catch (_) {
    messenger?.showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}
