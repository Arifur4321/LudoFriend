import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_friends/features/room/data/room_models.dart';

void main() {
  test('RoomModel parses team_mode (defaults false)', () {
    final ffa = RoomModel.fromJson({'id': 1, 'capacity': 4});
    expect(ffa.teamMode, isFalse);

    final team =
        RoomModel.fromJson({'id': 2, 'team_mode': true, 'capacity': 4});
    expect(team.teamMode, isTrue);
  });

  test('RoomPlayerModel.teamSide follows color (A: red/yellow, B: green/blue)',
      () {
    RoomPlayerModel p(String color) =>
        RoomPlayerModel.fromJson({'color': color, 'seat': 0});
    expect(p('red').teamSide, 0);
    expect(p('yellow').teamSide, 0);
    expect(p('green').teamSide, 1);
    expect(p('blue').teamSide, 1);
  });
}
