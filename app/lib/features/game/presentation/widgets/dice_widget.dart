import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_assets.dart';

/// An animated die. While [rolling] it spins and flickers faces, then settles
/// on [face]. Tapping calls [onRoll] when [enabled].
class DiceWidget extends StatefulWidget {
  const DiceWidget({
    super.key,
    required this.face,
    required this.rolling,
    required this.enabled,
    required this.onRoll,
    this.size = 64,
    this.tint = AppColors.primary,
  });

  final int? face;
  final bool rolling;
  final bool enabled;
  final VoidCallback onRoll;
  final double size;
  final Color tint;

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  final math.Random _rng = math.Random();
  int _shown = 1;

  @override
  void initState() {
    super.initState();
    _shown = widget.face ?? 1;
    if (widget.rolling) _spin.repeat();
  }

  @override
  void didUpdateWidget(covariant DiceWidget old) {
    super.didUpdateWidget(old);
    if (widget.rolling && !old.rolling) {
      _spin.repeat();
    } else if (!widget.rolling && old.rolling) {
      _spin.reset();
      setState(() => _shown = widget.face ?? _shown);
    } else if (!widget.rolling && widget.face != null) {
      _shown = widget.face!;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled && !widget.rolling ? widget.onRoll : null,
      child: AnimatedBuilder(
        animation: _spin,
        builder: (context, child) {
          final face =
              widget.rolling ? (_rng.nextInt(6) + 1) : (widget.face ?? _shown);
          final angle = widget.rolling ? _spin.value * 2 * math.pi : 0.0;
          return Opacity(
            opacity: widget.enabled || widget.rolling ? 1 : 0.55,
            child: Transform.rotate(
              angle: angle,
              child: Container(
                width: widget.size,
                height: widget.size,
                padding: EdgeInsets.all(widget.size * 0.08),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(widget.size * 0.22),
                  boxShadow: [
                    BoxShadow(
                      color: widget.tint.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SvgPicture.asset(AppAssets.die(face)),
              ),
            ),
          );
        },
      ),
    );
  }
}
