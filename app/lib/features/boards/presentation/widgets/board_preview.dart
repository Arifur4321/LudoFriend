import 'package:flutter/material.dart';

import '../../../../shared/theme/board_theme.dart';
import '../../../game/presentation/widgets/board_painter.dart';

/// A small non-interactive render of a board using its tier theme.
class BoardPreview extends StatelessWidget {
  const BoardPreview({super.key, required this.theme, this.size = 92});

  final BoardTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        size: Size.square(size),
        painter: BoardPainter(theme: theme),
      ),
    );
  }
}
