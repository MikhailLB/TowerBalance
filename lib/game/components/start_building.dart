import 'package:flame/components.dart';
import 'package:flame_forge2d/flame_forge2d.dart';

import '../game_constants.dart';

/// First "platform" the player stacks on.
///
/// Visually invisible — the painted shop / city scene is provided entirely by
/// [StartBg]. We keep an actual physics body so that the first block has
/// something concrete to land on at a deterministic spot in the centre of the
/// screen, and Forge2D contact resolution stays clean.
class StartBuilding extends BodyComponent {
  StartBuilding() : super(priority: 0);

  @override
  bool get renderBody => false;

  @override
  Body createBody() {
    final width = GameConstants.startBuildingWidth;
    final height = GameConstants.startBuildingHeight;
    final centreY = GameConstants.startBuildingTopY + height / 2;
    final shape = PolygonShape()..setAsBoxXY(width / 2, height / 2);
    final body = world.createBody(BodyDef(
      type: BodyType.static,
      position: Vector2(0, centreY),
      userData: 'start_building',
    ));
    body.createFixture(FixtureDef(
      shape,
      friction: 0.95,
      restitution: 0.0,
    ));
    return body;
  }
}
