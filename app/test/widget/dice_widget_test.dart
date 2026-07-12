import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/features/game/presentation/widgets/dice_widget.dart';

void main() {
  testWidgets('one pointer press rolls once across the padded dice target',
      (tester) async {
    var rolls = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: DiceWidget(
                face: null,
                rolling: false,
                enabled: true,
                size: 48,
                tapTargetSize: 68,
                onRoll: () => rolls++,
              ),
            ),
          ),
        ),
      ),
    );

    final rect = tester.getRect(find.byType(DiceWidget));
    // This point is inside the 68px target but outside the 48px painted die.
    final gesture = await tester.startGesture(
      Offset(rect.right - 3, rect.center.dy),
    );
    expect(rolls, 1);
    await gesture.up();
    await tester.pump();
    expect(rolls, 1);
  });

  testWidgets('disabled and rolling dice ignore pointer presses',
      (tester) async {
    var rolls = 0;

    Future<void> pumpDice({required bool enabled, required bool rolling}) {
      return tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DiceWidget(
              face: 3,
              rolling: rolling,
              enabled: enabled,
              onRoll: () => rolls++,
            ),
          ),
        ),
      );
    }

    await pumpDice(enabled: false, rolling: false);
    await tester.tap(find.byType(DiceWidget));
    await pumpDice(enabled: true, rolling: true);
    await tester.tap(find.byType(DiceWidget));

    expect(rolls, 0);
  });
}
