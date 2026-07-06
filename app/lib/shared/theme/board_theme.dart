import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A faint per-tier motif drawn over the board base for extra distinction.
enum BoardPattern { none, dots, diagonal, grid, rings, sparkle }

/// Visual identity for a staked board tier. Gameplay colours (token/player
/// colours) stay constant for clarity; a theme restyles the *surface* with a
/// faux-3D treatment — base gradient, bevel highlights/shadows, frame, safe
/// stars, a motif, and matching dice colours — so each tier looks progressively
/// more luxurious while staying perfectly readable.
@immutable
class BoardTheme {
  const BoardTheme({
    required this.key,
    required this.name,
    required this.base,
    required this.line,
    required this.frame,
    required this.safeStar,
    required this.watermark,
    required this.backdrop,
    this.premium = false,
    // 3D / decoration (optional — sensible defaults).
    this.baseAlt = const Color(0xFFFFEFD6),
    this.bevelHi = const Color(0x73FFFFFF),
    this.bevelLo = const Color(0x24000000),
    this.diceTop = const Color(0xFFFFFFFF),
    this.diceBottom = const Color(0xFFE9E4F5),
    this.dicePip = const Color(0xFF3F2BA8),
    this.pattern = BoardPattern.none,
  });

  final String key;
  final String name;
  final Color base; // board background (gradient top)
  final Color line; // cell grid lines
  final Color frame; // outer frame accent
  final Color safeStar; // star on non-owned safe cells
  final Color watermark; // faint centre watermark
  final List<Color> backdrop; // screen gradient behind the board
  final bool premium; // draw an extra accent ring

  final Color baseAlt; // board background gradient bottom
  final Color bevelHi; // 3D highlight edge (top-left)
  final Color bevelLo; // 3D shadow edge (bottom-right)
  final Color diceTop; // die face gradient top
  final Color diceBottom; // die face gradient bottom
  final Color dicePip; // die pip colour
  final BoardPattern pattern; // faint surface motif

  static const casual = BoardTheme(
    key: 'casual',
    name: 'Casual',
    base: Color(0xFFFFF7EC),
    baseAlt: Color(0xFFF4E9D6),
    line: Color(0xFFE7DCC8),
    frame: Color(0xFF90A4AE),
    safeStar: Color(0xFF6B6588),
    watermark: Color(0xFF90A4AE),
    backdrop: [Color(0xFF6A4CE0), Color(0xFF8E6BFF)],
    diceTop: Color(0xFFFFFFFF),
    diceBottom: Color(0xFFE3E8EC),
    dicePip: Color(0xFF546E7A),
    pattern: BoardPattern.none,
  );

  static const classic = BoardTheme(
    key: 'classic',
    name: 'Classic Arena',
    base: Color(0xFFFFF7EC),
    baseAlt: Color(0xFFEFE2C6),
    line: Color(0xFFE7DCC8),
    frame: Color(0xFF4CAF50),
    safeStar: Color(0xFF6B6588),
    watermark: Color(0xFF4CAF50),
    backdrop: [Color(0xFF3E8E41), Color(0xFF6FCF74)],
    diceTop: Color(0xFFFFFFFF),
    diceBottom: Color(0xFFDDF3DE),
    dicePip: Color(0xFF2E7D32),
    pattern: BoardPattern.dots,
  );

  static const bronze = BoardTheme(
    key: 'bronze',
    name: 'Bronze Bazaar',
    base: Color(0xFFFBEFE0),
    baseAlt: Color(0xFFEAD3B4),
    line: Color(0xFFE4C9A5),
    frame: Color(0xFFCD7F32),
    safeStar: Color(0xFF8A5A24),
    watermark: Color(0xFFCD7F32),
    backdrop: [Color(0xFF7A4E1E), Color(0xFFC98A46)],
    bevelHi: Color(0x80FFF3E0),
    bevelLo: Color(0x33000000),
    diceTop: Color(0xFFFFF0DD),
    diceBottom: Color(0xFFE4B483),
    dicePip: Color(0xFF7A4E1E),
    pattern: BoardPattern.diagonal,
  );

  static const silver = BoardTheme(
    key: 'silver',
    name: 'Silver Summit',
    base: Color(0xFFEEF2F6),
    baseAlt: Color(0xFFD3DCE4),
    line: Color(0xFFCAD5DE),
    frame: Color(0xFF8C9BA8),
    safeStar: Color(0xFF5C6B78),
    watermark: Color(0xFFB0BEC5),
    backdrop: [Color(0xFF54626F), Color(0xFF9AA7B4)],
    bevelHi: Color(0x8CFFFFFF),
    bevelLo: Color(0x2E1B2733),
    diceTop: Color(0xFFFFFFFF),
    diceBottom: Color(0xFFCFD8E0),
    dicePip: Color(0xFF455A64),
    pattern: BoardPattern.grid,
  );

  static const gold = BoardTheme(
    key: 'gold',
    name: 'Golden Colosseum',
    base: Color(0xFFFFF6DC),
    baseAlt: Color(0xFFF3DC97),
    line: Color(0xFFEBD9A6),
    frame: Color(0xFFE6A700),
    safeStar: Color(0xFFB07E00),
    watermark: Color(0xFFFFC107),
    backdrop: [Color(0xFF9C6B00), Color(0xFFF4C430)],
    bevelHi: Color(0x99FFFDE7),
    bevelLo: Color(0x33654B00),
    diceTop: Color(0xFFFFF8E1),
    diceBottom: Color(0xFFF0C860),
    dicePip: Color(0xFF8D6E00),
    pattern: BoardPattern.sparkle,
  );

  static const emerald = BoardTheme(
    key: 'emerald',
    name: 'Emerald Empire',
    base: Color(0xFFE7FBF4),
    baseAlt: Color(0xFFBDEBDC),
    line: Color(0xFFB7E6D6),
    frame: Color(0xFF00BFA5),
    safeStar: Color(0xFF067F6C),
    watermark: Color(0xFF00BFA5),
    backdrop: [Color(0xFF045F52), Color(0xFF14B39A)],
    premium: true,
    bevelHi: Color(0x99FFFFFF),
    bevelLo: Color(0x33044A40),
    diceTop: Color(0xFFEAFBF5),
    diceBottom: Color(0xFF8FE0CC),
    dicePip: Color(0xFF00695C),
    pattern: BoardPattern.rings,
  );

  static const diamond = BoardTheme(
    key: 'diamond',
    name: 'Diamond Throne',
    base: Color(0xFF2B2850),
    baseAlt: Color(0xFF17142E),
    line: Color(0xFF3B3660),
    frame: Color(0xFF9B7BFF),
    safeStar: Color(0xFFEDE7FF),
    watermark: Color(0xFF7C4DFF),
    backdrop: [Color(0xFF141229), Color(0xFF3A2C7A)],
    premium: true,
    bevelHi: Color(0x59FFFFFF),
    bevelLo: Color(0x59000000),
    diceTop: Color(0xFFB9A6FF),
    diceBottom: Color(0xFF6A4CE0),
    dicePip: Color(0xFFFFFFFF),
    pattern: BoardPattern.sparkle,
  );

  static const List<BoardTheme> staked = [
    classic, bronze, silver, gold, emerald, diamond,
  ];

  static const Map<String, BoardTheme> _byKey = {
    'casual': casual,
    'classic': classic,
    'bronze': bronze,
    'silver': silver,
    'gold': gold,
    'emerald': emerald,
    'diamond': diamond,
  };

  static BoardTheme forKey(String? key) => _byKey[key] ?? classic;

  /// True when the base is dark and on-board text should be light.
  bool get isDark => base.computeLuminance() < 0.4;
}

/// The theme currently applied to the live game board. Set when a player picks
/// a board (or starts a themed practice); read by [LudoBoard].
final activeBoardThemeProvider =
    StateProvider<BoardTheme>((ref) => BoardTheme.classic);
