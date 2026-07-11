import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../boards/data/board_models.dart';
import '../data/room_models.dart';
import '../data/room_repository.dart';

/// Join a friend's private room by its 6-character code. As soon as a full code
/// is entered we fetch a best-effort preview (host / board / free seats) so the
/// player can confirm before joining. The preview is optional — if the backend
/// lookup route isn't available the player can still join blindly.
class JoinRoomScreen extends ConsumerStatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  ConsumerState<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends ConsumerState<JoinRoomScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  bool _looking = false;
  RoomPreview? _preview;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  String _boardName(String key) {
    if (key == 'casual') return 'Casual · free';
    final match = BoardTier.fallback.where((t) => t.key == key);
    return match.isEmpty ? key : match.first.name;
  }

  void _onChanged(String raw) {
    final code = raw.trim().toUpperCase();
    if (_preview != null) setState(() => _preview = null);
    if (code.length == 6) _lookup(code);
  }

  Future<void> _lookup(String code) async {
    setState(() => _looking = true);
    final res = await ref.read(roomRepositoryProvider).lookup(code);
    if (!mounted) return;
    // Ignore a stale response if the user kept editing the code meanwhile —
    // but still clear the spinner so it never gets stuck on.
    if (_code.text.trim().toUpperCase() != code) {
      setState(() => _looking = false);
      return;
    }
    setState(() {
      _looking = false;
      res.when(
        ok: (p) => _preview = p,
        // Endpoint missing or bad code — stay silent and allow a blind join.
        err: (_) => _preview = null,
      );
    });
  }

  Future<void> _join() async {
    if (_busy) return;
    final code = _code.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter the 6-character room code')));
      return;
    }
    setState(() => _busy = true);
    final res = await ref.read(roomRepositoryProvider).join(code);
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
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Join Private Room')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 90, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Enter room code', style: AppTextStyles.display),
                const SizedBox(height: 8),
                Text('Ask your friend for their 6-character room code.',
                    style: AppTextStyles.body.copyWith(color: Colors.white70)),
                const SizedBox(height: 20),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.heading,
                  decoration: const InputDecoration(hintText: 'ABC123'),
                  maxLength: 6,
                  inputFormatters: [
                    _UpperCaseFormatter(),
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  ],
                  onChanged: _onChanged,
                ),
                const SizedBox(height: 8),
                if (_looking)
                  const Center(
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)),
                  )
                else if (preview != null)
                  _PreviewCard(
                      preview: preview,
                      boardName: _boardName(preview.boardTier)),
                const SizedBox(height: 16),
                PrimaryButton(
                    label: _busy ? 'Joining…' : 'Join & Play',
                    onPressed: _join),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview, required this.boardName});
  final RoomPreview preview;
  final String boardName;

  @override
  Widget build(BuildContext context) {
    final ok = preview.joinable;
    final hasAvatar =
        preview.hostAvatar != null && preview.hostAvatar!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surfaceMuted,
            backgroundImage: hasAvatar ? NetworkImage(preview.hostAvatar!) : null,
            child: hasAvatar
                ? null
                : Text((preview.hostName ?? 'P').characters.first.toUpperCase(),
                    style: const TextStyle(color: AppColors.ink)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    preview.hostName != null
                        ? "${preview.hostName}'s room"
                        : 'Private room',
                    style: AppTextStyles.title),
                const SizedBox(height: 2),
                Text(
                    ok
                        ? '$boardName · ${preview.players}/${preview.capacity} players'
                        : (preview.status == 'lobby'
                            ? '$boardName · room is full'
                            : '$boardName · game already started'),
                    style: AppTextStyles.bodyMuted),
              ],
            ),
          ),
          Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
              color: ok ? AppColors.success : AppColors.warning),
        ],
      ),
    );
  }
}

/// Uppercases room-code input live as the user types.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
