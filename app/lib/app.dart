import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'features/friends/application/invite_listener.dart';
import 'features/settings/application/settings_controller.dart';
import 'shared/theme/app_theme.dart';

/// Root widget. Localization is wired (delegates + supported locales + live
/// locale switching); visible strings can migrate to `lib/l10n/*.arb` over time.
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
      supportedLocales: const [
        Locale('en'),
        Locale('it'),
        Locale('bn'),
        Locale('hi'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
