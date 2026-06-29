import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../game_engine/board_layout.dart';
import '../../../../game_engine/models/game_status.dart';
import '../../../../game_engine/models/ludo_color.dart';
import '../../../../game_engine/models/move_result.dart';
import '../../../../game_engine/models/token.dart';
import '../../../../game_engine/rules/rule_config.dart';
import '../../application/game_controller.dart';
import 'board_painter.dart';
import 'token_piece.dart';

/// The interactive board: static art (BoardPainter) + animated token layer.
class LudoBoard extends ConsumerStatefulWidget {
  const LudoBoard({super.key});

  @override
  ConsumerState<LudoBoard> createState() => _LudoBoardState();
}

class _LudoBoardState extends ConsumerState<LudoBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  MoveResult? _current;

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  Offset _center(GridPoint gp, double cell) =>
      Offset((gp.col + 0.5) * cell, (gp.row + 0.5) * cell);

  List<Offset> _polyline(MoveResult m, double cell) {
    final parts = m.movedTokenId.split('_');
    final color = LudoColor.fromId(parts[0]);
    final index = int.parse(parts[1]);
    final pts = <Offset>[];
    if (m.fromPosition < 0) {
      pts.add(_center(BoardLayout.baseSlots[color]![index], cell));
    } else {
      pts.add(
          _center(BoardLayout.offsetForRelative(color, m.fromPosition), cell));
    }
    for (final rel in m.path) {
      pts.add(_center(BoardLayout.offsetForRelative(color, rel), cell));
    }
    return pts;
  }

  Offset _lerpPath(List<Offset> pts, double t) {
    if (pts.length == 1) return pts.first;
    final total = pts.length - 1;
    final pos = (t * total).clamp(0.0, total.toDouble());
    final i = pos.floor().clamp(0, total - 1);
    return Offset.lerp(pts[i], pts[i + 1], pos - i)!;
  }

  Offset _stackOffset(int i, int n, double cell) {
    if (n <= 1) return Offset.zero;
    const deltas = [
      Offset(-0.16, -0.10),
      Offset(0.16, -0.10),
      Offset(-0.16, 0.12),
      Offset(0.16, 0.12),
    ];
    final d = deltas[i % deltas.length];
    return Offset(d.dx * cell, d.dy * cell);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final game = session.game;

    if (session.isMoving &&
        session.lastMove != null &&
        !identical(session.lastMove, _current)) {
      _current = session.lastMove;
      final steps =
          session.lastMove!.path.isEmpty ? 1 : session.lastMove!.path.length;
      _move.duration = AppConstants.tokenStep * steps;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _move.forward(from: 0);
      });
    }
    if (!session.isMoving) _current = null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        final cell = side / BoardLayout.gridSize;
        final tokenSize = cell * 0.80;

        final movingId =
            session.isMoving ? session.lastMove?.movedTokenId : null;
        final human = game.currentPlayer.isHuman &&
            game.status == GameStatus.awaitingMove;
        final movable =
            human ? game.pendingMovableTokenIds.toSet() : const <String>{};

        // Faintly highlight ring destination cells of the movable tokens.
        final highlights = <int>{};
        final dice = game.lastDice;
        if (human && dice != null) {
          for (final id in movable) {
            final t = game.tokenById(id);
            final to = t.isInBase ? 0 : t.position + dice;
            if (to >= 0 && to <= RuleConfig.lastRingRel) {
              highlights.add((t.color.startOffset + to) % RuleConfig.ringSize);
            }
          }
        }

        // Group non-moving tokens by cell for neat stacking.
        final drawn = game.tokens.where((t) => t.id != movingId).toList();
        final groups = <String, List<Token>>{};
        for (final t in drawn) {
          final gp = BoardLayout.cellOf(t);
          groups.putIfAbsent('${gp.row}_${gp.col}', () => []).add(t);
        }

        final children = <Widget>[
          CustomPaint(
            size: Size.square(side),
            painter: BoardPainter(highlightCells: highlights),
          ),
        ];

        for (final list in groups.values) {
          for (var k = 0; k < list.length; k++) {
            final t = list[k];
            final center = _center(BoardLayout.cellOf(t), cell) +
                _stackOffset(k, list.length, cell);
            final isMovable = movable.contains(t.id);
            children.add(Positioned(
              left: center.dx - tokenSize / 2,
              top: center.dy - tokenSize / 2,
              width: tokenSize,
              height: tokenSize,
              child: TokenPiece(
                token: t,
                size: tokenSize,
                movable: isMovable,
                onTap: isMovable ? () => controller.pickToken(t.id) : null,
              ),
            ));
          }
        }

        if (movingId != null && session.lastMove != null) {
          final m = session.lastMove!;
          final color = LudoColor.fromId(m.movedTokenId.split('_')[0]);
          final index = int.parse(m.movedTokenId.split('_')[1]);
          final token =
              Token(color: color, index: index, position: m.toPosition);
          final pts = _polyline(m, cell);
          children.add(Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _move,
                child: TokenPiece(token: token, size: tokenSize),
                builder: (context, child) {
                  final c = _lerpPath(pts, _move.value);
                  final hop = math.sin(_move.value * math.pi) * cell * 0.18;
                  return Transform.translate(
                    offset: Offset(
                        c.dx - tokenSize / 2, c.dy - tokenSize / 2 - hop),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                          width: tokenSize, height: tokenSize, child: child),
                    ),
                  );
                },
              ),
            ),
          ));
        }

        return SizedBox(
          width: side,
          height: side,
          child: Stack(children: children),
        );
      },
    );
  }
}
