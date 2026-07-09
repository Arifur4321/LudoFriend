import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../data/room_repository.dart';

class CreateRoomScreen extends ConsumerStatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  ConsumerState<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends ConsumerState<CreateRoomScreen> {
  int _seats = 4;
  bool _botFill = true;
  bool _isPrivate = true;
  double _timer = 20;
  bool _busy = false;

  Future<void> _create() async {
    if (_busy) return;
    setState(() => _busy = true);
    final res = await ref.read(roomRepositoryProvider).create(
          mode: _seats == 2 ? '2p' : '4p',
          botFill: _botFill,
          turnTimer: _timer.round(),
          visibility: _isPrivate ? 'private' : 'public',
        );
    if (!mounted) return;
    setState(() => _busy = false);
    res.when(
      ok: (room) {
        ref.read(activeRoomProvider.notifier).state = room;
        context.push(AppRoutes.lobby);
      },
      err: (f) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Room')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Players', style: AppTextStyles.title),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Choice(
                            label: '2',
                            selected: _seats == 2,
                            onTap: () => setState(() => _seats = 2)),
                        const SizedBox(width: 12),
                        _Choice(
                            label: '4',
                            selected: _seats == 4,
                            onTap: () => setState(() => _seats = 4)),
                      ],
                    ),
                  ],
                ),
              ),
              _Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Fill empty seats with bots',
                          style: AppTextStyles.body),
                      value: _botFill,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _botFill = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Private room', style: AppTextStyles.body),
                      subtitle: Text('Only people with the code can join',
                          style: AppTextStyles.bodyMuted),
                      value: _isPrivate,
                      activeColor: AppColors.primary,
                      onChanged: (v) => setState(() => _isPrivate = v),
                    ),
                  ],
                ),
              ),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Turn timer: ${_timer.round()}s',
                        style: AppTextStyles.title),
                    Slider(
                      value: _timer,
                      min: 10,
                      max: 40,
                      divisions: 6,
                      activeColor: AppColors.primary,
                      label: '${_timer.round()}s',
                      onChanged: (v) => setState(() => _timer = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: _busy ? 'Creating…' : 'Create Room',
                onPressed: _create,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: child,
      );
}

class _Choice extends StatelessWidget {
  const _Choice(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: AppTextStyles.title
                  .copyWith(color: selected ? Colors.white : AppColors.ink)),
        ),
      ),
    );
  }
}
