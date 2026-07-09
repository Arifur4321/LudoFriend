import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../game_engine/models/game_player.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Renders a player's avatar inside a colored ring.
///
/// Selection order:
///  1. Bot        → bot glyph
///  2. Photo URL  → Facebook / Google profile photo (cached in-memory by the
///                  framework), with graceful fallbacks while loading / on error
///  3. Guest      → a stable bundled SVG face
///  4. Otherwise  → a colored monogram of the first letter
///
/// It never throws on a bad or slow URL — the board always keeps rendering.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.player,
    this.radius = 28,
    this.ring = true,
  });

  final GamePlayer player;
  final double radius;
  final bool ring;

  /// Bundled guest faces (already declared under `assets/svg/`).
  static const List<String> _guestFaces = [
    'assets/svg/avatar_guest.svg',
    'assets/svg/avatar_male.svg',
    'assets/svg/avatar_female.svg',
    'assets/svg/avatar_neutral.svg',
  ];

  /// A deterministic guest face so a given guest always looks the same.
  String get _guestAsset {
    if (player.avatarAsset != null) return player.avatarAsset!;
    final key = (player.userId ?? player.name);
    if (key.isEmpty) return _guestFaces.first;
    final sum = key.codeUnits.fold<int>(0, (a, b) => a + b);
    return _guestFaces[sum % _guestFaces.length];
  }

  @override
  Widget build(BuildContext context) {
    final color = AppColors.of(player.color);
    final d = radius * 2;
    final url = player.avatarUrl;

    Widget inner;
    if (player.isBot) {
      inner = _padSvg('assets/svg/icon_bot.svg');
    } else if (url != null && url.isNotEmpty) {
      inner = Image.network(
        url,
        width: d,
        height: d,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        loadingBuilder: (ctx, child, progress) =>
            progress == null ? child : _monogram(color),
        errorBuilder: (ctx, _, __) =>
            player.isGuest ? _padSvg(_guestAsset) : _monogram(color),
      );
    } else if (player.isGuest) {
      inner = _padSvg(_guestAsset);
    } else {
      inner = _monogram(color);
    }

    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceMuted,
        border: ring ? Border.all(color: color, width: radius * 0.11) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: radius * 0.22,
            offset: Offset(0, radius * 0.10),
          ),
        ],
      ),
      child: ClipOval(child: inner),
    );
  }

  Widget _padSvg(String asset) => Padding(
        padding: EdgeInsets.all(radius * 0.12),
        child: SvgPicture.asset(asset, fit: BoxFit.contain),
      );

  Widget _monogram(Color color) => Container(
        color: color,
        alignment: Alignment.center,
        child: Text(
          player.name.isNotEmpty
              ? player.name.characters.first.toUpperCase()
              : '?',
          style: AppTextStyles.button.copyWith(fontSize: radius * 0.85),
        ),
      );
}
