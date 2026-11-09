import 'package:flutter/widgets.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart';

/// Glass tuned so text does not pick up a yellow chromatic fringe.
const readableGlassSettings = LiquidGlassSettings(
  chromaticAberration: 0,
  saturation: 1,
  lightIntensity: 0.3,
  thickness: 16,
  blur: 8,
  refractiveIndex: 1.05,
  glowIntensity: 0,
);

const readableLabelStyle = TextStyle(
  decoration: TextDecoration.none,
  decorationColor: Color(0x00000000),
  fontSize: 11,
);
