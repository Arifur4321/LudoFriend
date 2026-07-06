import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local description of a private room being created/joined. Online play (Phase
/// 2) replaces this with server state synced over the WebSocket; the offline
/// flow uses it to start a bot-filled match end-to-end.
class RoomDraft {
  RoomDraft({
    required this.code,
    required this.seats,
    required this.botFill,
    required this.turnTimer,
    required this.isPrivate,
    this.isHost = true,
    this.boardThemeKey = 'casual',
    this.boardName,
    this.teamMode = false,
  });

  final String code;
  final int seats; // 2 or 4
  final bool botFill;
  final int turnTimer;
  final bool isPrivate;
  final bool isHost;
  final String boardThemeKey;
  final String? boardName;
  final bool teamMode;

  static String generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

final roomDraftProvider = StateProvider<RoomDraft?>((ref) => null);
