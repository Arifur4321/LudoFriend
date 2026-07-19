import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/features/game/presentation/widgets/winner_overlay.dart';
import 'package:ludo_friends/game_engine/models/ludo_color.dart';

void main() {
  testWidgets('WinnerOverlay shows the WINNING TEAM in team mode',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WinnerOverlay(
          winner: LudoColor.red,
          winnerName: 'Aisha',
          teamWin: true,
          teamLabel: 'Team A',
          teammateNames: const ['Aisha', 'Maya'],
          onRematch: () {},
          onHome: () {},
        ),
      ),
    ));
    // One frame only — the confetti controller repeats forever, so
    // pumpAndSettle() would never return.
    await tester.pump();

    expect(find.text('WINNING TEAM'), findsOneWidget);
    expect(find.text('Team A wins! 🏆'), findsOneWidget);
    expect(find.text('Aisha  &  Maya'), findsOneWidget);
  });

  testWidgets('WinnerOverlay shows a single winner in free-for-all',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WinnerOverlay(
          winner: LudoColor.green,
          winnerName: 'Sam',
          onRematch: () {},
          onHome: () {},
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('WINNER'), findsOneWidget);
    expect(find.text('Sam wins! 🏆'), findsOneWidget);
  });
}
