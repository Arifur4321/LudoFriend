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
import '../../../../shared/theme/board_theme.dart';
import '../../application/game_controller.dart';
import 'board_painter.dart';
import 'token_hit_resolver.dart';
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

  List<Offset> _capturedPolyline(
      String tokenId, int fromPosition, double cell) {
    final parts = tokenId.split('_');
    final color = LudoColor.fromId(parts[0]);
    final index = int.parse(parts[1]);
    final pts = <Offset>[
      _center(BoardLayout.offsetForRelative(color, fromPosition), cell),
    ];
    for (var rel = fromPosition - 1; rel >= 0; rel--) {
      pts.add(_center(BoardLayout.offsetForRelative(color, rel), cell));
    }
    pts.add(_center(BoardLayout.baseSlots[color]![index], cell));
    return pts;
  }

  Duration _mainDuration(MoveResult move) =>
      AppConstants.tokenStep * (move.path.isEmpty ? 1 : move.path.length);

  Duration _captureDuration(MoveResult move) =>
      AppConstants.capturedTokenStep * move.maxCapturedReturnSteps;

  Duration _animationDuration(MoveResult move) =>
      _mainDuration(move) + _captureDuration(move);

  Offset _lerpPath(List<Offset> pts, double t) {
    if (pts.length == 1) return pts.first;
    final total = pts.length - 1;
    final pos = (t * total).clamp(0.0, total.toDouble());
    final i = pos.floor().clamp(0, total - 1);
    final local = Curves.easeInOut.transform(pos - i);
    return Offset.lerp(pts[i], pts[i + 1], local)!;
  }

  double _segmentProgress(List<Offset> pts, double t) {
    if (pts.length <= 1 || t <= 0) return 0;
    if (t >= 1) return 1;
    final pos = t * (pts.length - 1);
    return pos - pos.floor();
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
    final boardTheme = ref.watch(activeBoardThemeProvider);
    final game = session.game;

    if (session.isMoving &&
        session.lastMove != null &&
        !identical(session.lastMove, _current)) {
      _current = session.lastMove;
      _move.duration = _animationDuration(session.lastMove!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _move.forward(from: 0);
      });
    }
    if (!session.isMoving) _current = null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        final cell = side / BoardLayout.gridSize;
        // Slightly larger than a cell so pawns read clearly on small phones;
        // the pawn shape + white outline keeps neighbours distinguishable.
        final tokenSize = cell * 0.96;

        final movingId =
            session.isMoving ? session.lastMove?.movedTokenId : null;
        final capturedIds = session.isMoving
            ? session.lastMove?.capturedTokenIds.toSet() ?? const <String>{}
            : const <String>{};
        final human = game.currentPlayer.isHuman &&
            game.status == GameStatus.awaitingMove &&
            !session.isBusy;
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
        final drawn = game.tokens
            .where((t) => t.id != movingId && !capturedIds.contains(t.id))
            .toList();
        final groups = <String, List<Token>>{};
        for (final t in drawn) {
          final gp = BoardLayout.cellOf(t);
          groups.putIfAbsent('${gp.row}_${gp.col}', () => []).add(t);
        }

        final children = <Widget>[
          CustomPaint(
            size: Size.square(side),
            painter:
                BoardPainter(highlightCells: highlights, theme: boardTheme),
          ),
        ];
        final tokenCenters = <String, Offset>{};

        for (final list in groups.values) {
          for (var k = 0; k < list.length; k++) {
            final t = list[k];
            final center = _center(BoardLayout.cellOf(t), cell) +
                _stackOffset(k, list.length, cell);
            tokenCenters[t.id] = center;
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
          final mainMs = _mainDuration(m).inMicroseconds;
          final totalMs = _animationDuration(m).inMicroseconds;
          final mainEnd = totalMs == 0 ? 1.0 : mainMs / totalMs;
          children.add(Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _move,
                child: TokenPiece(token: token, size: tokenSize),
                builder: (context, child) {
                  final progress = mainEnd <= 0
                      ? 1.0
                      : (_move.value / mainEnd).clamp(0.0, 1.0);
                  final c = _lerpPath(pts, progress);
                  final hop = math.sin(
                        _segmentProgress(pts, progress) * math.pi,
                      ) *
                      cell *
                      0.18;
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

          for (final entry in m.capturedFromPositions.entries) {
            final capturedParts = entry.key.split('_');
            final capturedColor = LudoColor.fromId(capturedParts[0]);
            final capturedIndex = int.parse(capturedParts[1]);
            final capturedToken = Token(
              color: capturedColor,
              index: capturedIndex,
              position: entry.value,
            );
            final capturedPath =
                _capturedPolyline(entry.key, entry.value, cell);
            children.add(Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _move,
                  child: TokenPiece(token: capturedToken, size: tokenSize),
                  builder: (context, child) {
                    final progress = mainEnd >= 1
                        ? 1.0
                        : ((_move.value - mainEnd) / (1 - mainEnd))
                            .clamp(0.0, 1.0);
                    final c = _lerpPath(capturedPath, progress);
                    final hop = math.sin(
                          _segmentProgress(capturedPath, progress) * math.pi,
                        ) *
                        cell *
                        0.11;
                    return Transform.translate(
                      offset: Offset(
                        c.dx - tokenSize / 2,
                        c.dy - tokenSize / 2 - hop,
                      ),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: tokenSize,
                          height: tokenSize,
                          child: child,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ));
          }
        }

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: human
              ? (event) {
                  final tokenId = nearestMovableToken(
                    pointer: event.localPosition,
                    centers: tokenCenters,
                    movableTokenIds: movable,
                    maximumDistance: cell * 0.72,
                  );
                  if (tokenId != null) controller.pickToken(tokenId);
                }
              : null,
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(children: children),
          ),
        );
      },
    );
  }
}
