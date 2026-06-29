import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/audio/audio_service.dart';

/// Wraps any child with a tactile press-scale animation and an optional click
/// sound. Used by [PrimaryButton] and throughout the menus.
class BouncingButton extends ConsumerStatefulWidget {
  const BouncingButton({
    super.key,
    required this.child,
    this.onTap,
    this.playSound = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool playSound;

  @override
  ConsumerState<BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends ConsumerState<BouncingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    lowerBound: 0.0,
    upperBound: 0.06,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _down(_) => _c.forward();
  void _up(_) => _c.reverse();

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? _down : null,
      onTapCancel: enabled ? () => _c.reverse() : null,
      onTapUp: enabled ? _up : null,
      onTap: enabled
          ? () {
              if (widget.playSound) ref.read(audioServiceProvider).click();
              widget.onTap!();
            }
          : null,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) =>
            Transform.scale(scale: 1 - _c.value, child: child),
        child: Opacity(opacity: enabled ? 1 : 0.5, child: widget.child),
      ),
    );
  }
}
