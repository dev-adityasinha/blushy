import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'checkin_scene.dart';

/// The scene on a check-in card.
///
/// Prefers a Lottie animation where one has been dropped in, and falls back to
/// the drawn scene where none has. That way the artwork is a data change --
/// add `assets/lottie/<scene>.json` and it is used -- rather than something
/// the cards have to be rebuilt around.
///
/// The drawn scenes are not a placeholder to be embarrassed about: they carry
/// the card's palette, scale to any size and cost nothing in the bundle. The
/// Lottie path exists because a proper illustrated animation will always read
/// better than shapes drawn in code, and there are freely licensed ones.
///
/// Nothing here downloads anything. A file has to be added to the project, so
/// whoever adds it has seen its licence.
class CheckinSceneView extends StatelessWidget {
  const CheckinSceneView({
    super.key,
    required this.scene,
    required this.t,
    this.animate = true,
  });

  final CheckinScene scene;

  /// Where the drawn scene is in its loop. Ignored by Lottie, which runs its
  /// own timeline.
  final double t;

  final bool animate;

  /// Where a replacement for [scene] would live.
  static String assetFor(CheckinScene scene) =>
      'assets/lottie/${scene.name}.json';

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      assetFor(scene),
      fit: BoxFit.contain,
      repeat: animate,
      animate: animate,
      // The whole seam. No file, a malformed file, or a build that never had
      // the directory: the card shows the drawn scene instead of an error box,
      // and nothing about the check-in stops working.
      errorBuilder: (_, _, _) => CustomPaint(
        painter: CheckinScenePainter(scene: scene, t: t),
      ),
    );
  }
}
