import 'package:flutter/material.dart';

/// A shrinking countdown bar for the active turn. Recreated each turn (via a
/// ValueKey) so it restarts; calls [onExpire] when it runs out.
class TurnTimerBar extends StatefulWidget {
  const TurnTimerBar({
    super.key,
    required this.seconds,
    required this.onExpire,
    required this.color,
  });

  final int seconds;
  final VoidCallback onExpire;
  final Color color;

  @override
  State<TurnTimerBar> createState() => _TurnTimerBarState();
}

class _TurnTimerBarState extends State<TurnTimerBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.seconds),
  );
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _c
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && !_fired) {
          _fired = true;
          widget.onExpire();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final remaining = 1 - _c.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: remaining,
            minHeight: 6,
            backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation(
              remaining < 0.25 ? Colors.redAccent : widget.color,
            ),
          ),
        );
      },
    );
  }
}
