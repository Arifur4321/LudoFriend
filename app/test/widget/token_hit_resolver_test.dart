import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/features/game/presentation/widgets/token_hit_resolver.dart';

void main() {
  test('one press selects the nearest legal pawn inside padded hit radius', () {
    final selected = nearestMovableToken(
      pointer: const Offset(58, 50),
      centers: const {
        'red_0': Offset(50, 50),
        'red_1': Offset(100, 50),
      },
      movableTokenIds: const {'red_0', 'red_1'},
      maximumDistance: 36,
    );

    expect(selected, 'red_0');
  });

  test('ignores non-movable pawns even when they are closer', () {
    final selected = nearestMovableToken(
      pointer: const Offset(62, 50),
      centers: const {
        'red_0': Offset(60, 50),
        'red_1': Offset(82, 50),
      },
      movableTokenIds: const {'red_1'},
      maximumDistance: 36,
    );

    expect(selected, 'red_1');
  });

  test('returns null when the press is outside the padded pawn target', () {
    final selected = nearestMovableToken(
      pointer: const Offset(150, 150),
      centers: const {'red_0': Offset(50, 50)},
      movableTokenIds: const {'red_0'},
      maximumDistance: 36,
    );

    expect(selected, isNull);
  });
}
