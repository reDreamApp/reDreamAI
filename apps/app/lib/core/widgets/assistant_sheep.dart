import 'package:flutter/material.dart';

/// The chat assistant's icon: a pixel-art sheep.
///
/// The sprite is 40 pixels wide and shown at about 1.7 screen pixels per
/// sprite pixel, so it relies on the default smooth scaling; nearest-neighbour
/// sampling would make its pixels uneven.
class AssistantSheep extends StatelessWidget {
  const AssistantSheep({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/assistant_sheep.png',
      width: size,
      height: size,
    );
  }
}
