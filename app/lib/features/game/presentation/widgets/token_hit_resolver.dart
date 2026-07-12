import 'package:flutter/widgets.dart';

/// Resolve one pointer press to the nearest legal pawn.
///
/// Doing this at board level gives each pawn comfortable touch padding without
/// overlapping widget hit boxes stealing taps from a neighbouring pawn.
String? nearestMovableToken({
  required Offset pointer,
  required Map<String, Offset> centers,
  required Set<String> movableTokenIds,
  required double maximumDistance,
}) {
  String? nearest;
  var nearestDistance = double.infinity;

  for (final id in movableTokenIds) {
    final center = centers[id];
    if (center == null) continue;
    final distance = (pointer - center).distance;
    if (distance <= maximumDistance && distance < nearestDistance) {
      nearest = id;
      nearestDistance = distance;
    }
  }

  return nearest;
}
