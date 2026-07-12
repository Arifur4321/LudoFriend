import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/router/app_routes.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/utils/external_links.dart';
import '../../../shared/widgets/app_background.dart';
import '../application/settings_controller.dart';

/// Every supported UI language, shown in its own native form. The keys are the
/// locale codes persisted locally; the values are never translated (a language
/// picker always reads best in-script).
const Map<String, String> kSupportedLanguages = {
  'en': 'English',
  'de': 'Deutsch',
  'nl': 'Nederlands',
  'es': 'Español',
  'it': 'Italiano',
  'pt': 'Português',
  'bn': 'বাংলা',
  'hi': 'हिन्दी',
  'zh': '简体中文',
  'ko': '한국어',
  'ja': '日本語',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(settingsControllerProvider);
    final c = ref.read(settingsControllerProvider.notifier);

    // Guard against a persisted code that is no longer supported.
    final currentLocale =
        kSupportedLanguages.containsKey(s.localeCode) ? s.localeCode : 'en';

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            children: [
              _SectionLabel(l.audioHaptics),
              _Group(children: [
                _SwitchTile(
                  icon: Icons.volume_up_rounded,
                  title: l.soundEffects,
                  value: s.sound,
                  onChanged: (_) => c.toggleSound(),
                ),
                _SwitchTile(
                  icon: Icons.music_note_rounded,
                  title: l.music,
                  value: s.music,
                  onChanged: (_) => c.toggleMusic(),
                ),
                _SwitchTile(
                  icon: Icons.vibration_rounded,
                  title: l.vibration,
                  value: s.vibration,
                  onChanged: (_) => c.toggleVibration(),
                ),
              ]),
              _SectionLabel(l.gameplay),
              _Group(children: [
                _SwitchTile(
                  icon: Icons.notifications_active_rounded,
                  title: l.turnAlerts,
                  subtitle: l.turnAlertsSubtitle,
                  value: s.turnAlerts,
                  onChanged: (_) => c.toggleTurnAlerts(),
                ),
                _SwitchTile(
                  icon: Icons.chat_bubble_rounded,
                  title: l.inGameChat,
                  value: s.chat,
                  onChanged: (_) => c.toggleChat(),
                ),
                _SwitchTile(
                  icon: Icons.emoji_emotions_rounded,
                  title: l.emojiReactions,
                  value: s.emoji,
                  onChanged: (_) => c.toggleEmoji(),
                ),
              ]),
              _SectionLabel(l.appSection),
              _Group(children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded,
                      color: AppColors.primary),
                  title: Text(l.language, style: AppTextStyles.body),
                  trailing: DropdownButton<String>(
                    value: currentLocale,
                    underline: const SizedBox.shrink(),
                    items: kSupportedLanguages.entries
                        .map((e) => DropdownMenuItem(
                            value: e.key, child: Text(e.value)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) c.setLocale(v);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded,
                      color: AppColors.primary),
                  title: Text(l.howToPlay, style: AppTextStyles.body),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.help),
                ),
              ]),
              _Group(children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary),
                  title: Text(l.about, style: AppTextStyles.body),
                  subtitle: Text('Ludo Friends · v1.0.0',
                      style: AppTextStyles.bodyMuted),
                ),
              ]),
              _SectionLabel(l.legal),
              _Group(children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined,
                      color: AppColors.primary),
                  title: Text(l.privacyPolicy, style: AppTextStyles.body),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () =>
                      openExternalUrl(context, AppConfig.privacyPolicyUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: AppColors.primary),
                  title: Text(l.termsOfService, style: AppTextStyles.body),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () => openExternalUrl(context, AppConfig.termsUrl),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.primary),
                  title: Text(l.dataDeletion, style: AppTextStyles.body),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                  onTap: () =>
                      openExternalUrl(context, AppConfig.dataDeletionUrl),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
        child: Text(text,
            style: AppTextStyles.label.copyWith(color: Colors.white)),
      );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTextStyles.body),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.bodyMuted)
          : null,
      value: value,
      activeColor: AppColors.primary,
      onChanged: onChanged,
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(children: children),
      );
}
