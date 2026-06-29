import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../game_engine/models/token.dart';
import '../../../../shared/widgets/app_assets.dart';

/// A single rendered token. Pulses and uses the glow asset when it is a legal
/// move target.
class TokenPiece extends StatefulWidget {
  const TokenPiece({
    super.key,
    required this.token,
    required this.size,
    this.movable = false,
    this.onTap,
  });

  final Token token;
  final double size;
  final bool movable;
  final VoidCallback? onTap;

  @override
  State<TokenPiece> createState() => _TokenPieceState();
}

class _TokenPieceState extends State<TokenPiece>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    lowerBound: 0.96,
    upperBound: 1.14,
  );

  @override
  void initState() {
    super.initState();
    if (widget.movable) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant TokenPiece old) {
    super.didUpdateWidget(old);
    if (widget.movable && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.movable && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final piece = SvgPicture.asset(
      AppAssets.token(widget.token.color, glow: widget.movable),
      width: widget.size,
      height: widget.size,
    );
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child:
          widget.movable ? ScaleTransition(scale: _pulse, child: piece) : piece,
    );
  }
}
