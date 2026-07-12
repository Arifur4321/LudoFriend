import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'features/friends/application/invite_listener.dart';
import 'features/settings/application/settings_controller.dart';
import 'l10n/generated/app_localizations.dart';
import 'shared/theme/app_theme.dart';

/// Root widget. Localization is fully wired: the generated [AppLocalizations]
/// delegate is registered, all supported locales are advertised, and the active
/// locale switches live from the (locally persisted) Settings selection.
class LudoFriendsApp extends ConsumerWidget {
  const LudoFriendsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final localeCode =
        ref.watch(settingsControllerProvider.select((s) => s.localeCode));

    return MaterialApp.router(
      title: 'Ludo Friends',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) =>
          InviteListener(child: child ?? const SizedBox.shrink()),
      locale: Locale(localeCode),
      // Delegates + locales come from the generated class, so they always match
      // the .arb files (adding a locale is just adding an .arb).
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      // Safe fallback: an unknown/unsupported code resolves to English rather
      // than the device locale, so users never see raw keys or a wrong language.
      localeResolutionCallback: (locale, supported) {
        for (final s in supported) {
          if (s.languageCode == locale?.languageCode) return s;
        }
        return const Locale('en');
      },
    );
  }
}
