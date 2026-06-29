import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/features/game/presentation/widgets/player_chip.dart';
import 'package:ludo_friends/game_engine/models/game_player.dart';
import 'package:ludo_friends/game_engine/models/ludo_color.dart';

void main() {
  testWidgets('PlayerChip renders the player name', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerChip(
            player: GamePlayer(color: LudoColor.red, name: 'Alice'),
            active: true,
            homeCount: 2,
          ),
        ),
      ),
    );
    expect(find.text('Alice'), findsOneWidget);
  });

  testWidgets('PlayerChip marks bots with an icon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerChip(
            player: GamePlayer(
                color: LudoColor.blue, name: 'Bot 1', kind: PlayerKind.bot),
            active: false,
            homeCount: 0,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.smart_toy), findsOneWidget);
  });
}
