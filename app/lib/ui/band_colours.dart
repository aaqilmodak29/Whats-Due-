import 'package:flutter/widgets.dart';

import '../bands.dart';
import '../theme.dart';

/// The one band colour scale: every place a band is shown (Grades, the goal
/// sheet, the Welcome swatches, the band editor) takes its colour from here,
/// so a band never reads two ways on two screens.
///
/// Below the pass mark is red. The passing bands climb four stops that move
/// from grey to green in hue and also jump in lightness, so neighbours tell
/// apart at a glance even as small swatches:
///
///  * Pass: slate, the palette's muted grey; lighter than ink, never mistaken
///    for it.
///  * Credit: a light sea-green, half slate and half green, lifted towards
///    the card.
///  * Distinction: a deep green, the green half way to ink.
///  * High Distinction: the green itself, at full strength.
///
/// Every stop is mixed from the palette's own tokens, so after dark the same
/// recipe holds: "towards ink" lightens and "towards the card" deepens, and
/// each band keeps its place in the hue order.
///
/// With more than four passing bands, the extra bands fall evenly between the
/// stops; with fewer, they take stops spread from Pass to High Distinction.
///
/// Without bands there are no steps to show, so this keeps [gradeColour]'s
/// three: red, ink, green.
Color bandColour(double percent, List<GradeBand> bands) {
  if (bands.length < 2) return gradeColour(percent, bands);
  if (percent + 1e-9 < bands[1].min) return C.red;
  final passing = bands.length - 1;
  if (passing <= 1) return C.green;
  final band = bandFor(percent, bands);
  final rank = band == null ? 0 : bands.indexOf(band) - 1;
  final stops = _stops;
  final at = rank / (passing - 1) * (stops.length - 1);
  final lo = at.floor().clamp(0, stops.length - 1);
  final hi = at.ceil().clamp(0, stops.length - 1);
  return Color.lerp(stops[lo], stops[hi], at - lo)!;
}

/// The colour of one band, by its own lower bound.
Color colourOfBand(GradeBand band, List<GradeBand> bands) =>
    bandColour(band.min, bands);

/// The four passing stops, lowest first. See [bandColour].
List<Color> get _stops => [
  C.muted,
  Color.lerp(Color.lerp(C.muted, C.green, .5), C.card, .15)!,
  Color.lerp(C.green, C.ink, .55)!,
  C.green,
];

/// A band's lower bound, written the one way the app writes it everywhere:
/// "75%+". Bands are stored as floors, so the floor is what is shown.
String bandFloor(GradeBand band) => '${trimBound(band.min)}%+';

/// The small block that stands for a band wherever one is listed.
class BandSwatch extends StatelessWidget {
  const BandSwatch(
    this.colour, {
    super.key,
    this.width = 14,
    this.height = 8,
  });

  final Color colour;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: width, height: height, child: ColoredBox(color: colour));
}
