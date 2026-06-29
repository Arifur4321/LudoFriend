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
              _Group(children: [
                SwitchListTile(
                  title: Text('Sound effects', style: AppTextStyles.body),
                  value: s.sound,
                  activeColor: AppColors.primary,
                  onChanged: (_) => c.toggleSound(),
                ),
                SwitchListTile(
                  title: Text('Music', style: AppTextStyles.body),
                  value: s.music,
                  activeColor: AppColors.primary,
                  onChanged: (_) => c.toggleMusic(),
                ),
              ]),
              _Group(children: [
                ListTile(
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
                  title: Text('How to play', style: AppTextStyles.body),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.help),
                ),
              ]),
              _Group(children: [
                ListTile(
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
