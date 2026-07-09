import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_text_styles.dart';
import '../../../shared/widgets/app_background.dart';
import '../../auth/application/auth_controller.dart';
import '../data/friends_repository.dart';

/// Friends hub: your share code, add-by-code, Facebook app-friends sync, and a
/// list of friends with live online status (presence heartbeats).
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _code = TextEditingController();
  final Map<int, AppFriend> _friends = {};
  bool _loading = true;
  bool _syncing = false;
  Timer? _presence;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Heartbeat so others see us online, and refresh the list periodically.
    _presence = Timer.periodic(const Duration(seconds: 25), (_) {
      ref.read(friendsRepositoryProvider).presencePing();
    });
    ref.read(friendsRepositoryProvider).presencePing();
  }

  @override
  void dispose() {
    _presence?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final repo = ref.read(friendsRepositoryProvider);
    final res = await repo.list();
    if (!mounted) return;
    res.when(
      ok: (friends) => setState(() {
        for (final f in friends) {
          _friends[f.id] = f;
        }
        _loading = false;
      }),
      err: (_) => setState(() => _loading = false),
    );
  }

  Future<void> _syncFacebook() async {
    setState(() => _syncing = true);
    final res = await ref.read(friendsRepositoryProvider).facebookFriends();
    if (!mounted) return;
    setState(() => _syncing = false);
    res.when(
      ok: (friends) {
        setState(() {
          for (final f in friends) {
            _friends[f.id] = f;
          }
        });
        if (friends.isEmpty) {
          _toast('No app-connected Facebook friends found yet.');
        }
      },
      err: (f) => _toast(f.message),
    );
  }

  Future<void> _add() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    final res = await ref.read(friendsRepositoryProvider).addByCode(code);
    if (!mounted) return;
    res.when(
      ok: (_) {
        _code.clear();
        _toast('Friend added.');
        _refresh();
      },
      err: (f) => _toast(f.message),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).valueOrNull;
    final friends = _friends.values.toList()
      ..sort((a, b) => a.online == b.online
          ? a.name.compareTo(b.name)
          : (a.online ? -1 : 1));

    return Scaffold(
      appBar: AppBar(title: const Text('Friends')),
      extendBodyBehindAppBar: true,
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            children: [
              if (me != null && !me.isGuest)
                _Card(children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Your friend code', style: AppTextStyles.label),
                    subtitle: Text(me.id,
                        style: AppTextStyles.title
                            .copyWith(color: AppColors.primary)),
                    trailing: IconButton(
                      icon: const Icon(Icons.ios_share_rounded,
                          color: AppColors.primary),
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Add me on Ludo Friends! My friend code is ${me.id}.',
                        ),
                      ),
                    ),
                  ),
                ]),
              _Card(children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          decoration: const InputDecoration(
                            hintText: 'Add friend by code',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(onPressed: _add, child: const Text('Add')),
                    ],
                  ),
                ),
              ]),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _syncing ? null : _syncFacebook,
                  icon: _syncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.people_alt_rounded, color: Colors.white),
                  label: const Text('Sync Facebook friends',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (friends.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('No friends yet — add by code or sync Facebook.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.label.copyWith(color: Colors.white)),
                )
              else
                _Card(
                  children: [
                    for (final f in friends) _FriendTile(friend: f),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({required this.friend});
  final AppFriend friend;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.surfaceMuted,
            backgroundImage: (friend.avatar != null && friend.avatar!.isNotEmpty)
                ? NetworkImage(friend.avatar!)
                : null,
            child: (friend.avatar == null || friend.avatar!.isEmpty)
                ? Text(friend.name.isNotEmpty
                    ? friend.name.characters.first.toUpperCase()
                    : '?')
                : null,
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: friend.online
                    ? const Color(0xFF39D353)
                    : const Color(0xFF9AA4AD),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(friend.name, style: AppTextStyles.body),
      subtitle: Text(friend.online ? 'Online' : 'Offline',
          style: AppTextStyles.bodyMuted),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(children: children),
      );
}
