import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../application/settings_controller.dart';

const _languages = {
  'en': 'English',
  'it': 'Italiano',
  'bn': 'বাংলা',
  'hi': 'हिन्दी',
};

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsControllerProvider);
    final c = ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            children: [
              _SectionLabel('Audio & Haptics'),
              _Group(children: [
                _SwitchTile(
                  icon: Icons.volume_up_rounded,
                  title: 'Sound effects',
                  value: s.sound,
                  onChanged: (_) => c.toggleSound(),
                ),
                _SwitchTile(
                  icon: Icons.music_note_rounded,
                  title: 'Music',
                  value: s.music,
                  onChanged: (_) => c.toggleMusic(),
                ),
                _SwitchTile(
                  icon: Icons.vibration_rounded,
                  title: 'Vibration',
                  value: s.vibration,
                  onChanged: (_) => c.toggleVibration(),
                ),
              ]),
              _SectionLabel('Gameplay'),
              _Group(children: [
                _SwitchTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'Turn alerts',
                  subtitle: 'Sound + buzz when it is your turn',
                  value: s.turnAlerts,
                  onChanged: (_) => c.toggleTurnAlerts(),
                ),
                _SwitchTile(
                  icon: Icons.chat_bubble_rounded,
                  title: 'In-game chat',
                  value: s.chat,
                  onChanged: (_) => c.toggleChat(),
                ),
                _SwitchTile(
                  icon: Icons.emoji_emotions_rounded,
                  title: 'Emoji reactions',
                  value: s.emoji,
                  onChanged: (_) => c.toggleEmoji(),
                ),
              ]),
              _SectionLabel('App'),
              _Group(children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded,
                      color: AppColors.primary),
                  title: Text('Language', style: AppTextStyles.body),
                  trailing: DropdownButton<String>(
                    value: s.localeCode,
                    underline: const SizedBox.shrink(),
                    items: _languages.entries
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
                  title: Text('How to play', style: AppTextStyles.body),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.help),
                ),
              ]),
              _Group(children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded,
                      color: AppColors.primary),
                  title: Text('About', style: AppTextStyles.body),
                  subtitle: Text('Ludo Friends · v1.0.0',
                      style: AppTextStyles.bodyMuted),
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
      subtitle:
          subtitle != null ? Text(subtitle!, style: AppTextStyles.bodyMuted) : null,
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
