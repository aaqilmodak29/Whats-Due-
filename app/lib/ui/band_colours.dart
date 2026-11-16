import 'package:flutter/widgets.dart';

import '../bands.dart';
import '../theme.dart';

/// The one band colour scale: every place a band is shown (Grades, the goal
/// sheet, the Welcome swatches, the band editor) takes its colour from here,
/// so a band never reads two ways on two screens.
///
/// Below the pass mark is red. The passing bands sit on one straight ramp
/// from a neutral slate to the full green, in equal steps: the lowest pass is
/// the slate, the top band is the green, and each band between is its own
/// step along the way. The ramp is built from the palette's own tokens, so
/// after dark every band keeps its place on it (grey, grey-green, green-grey,
/// green) rather than flipping to a different hue.
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
  return Color.lerp(_slate, C.green, rank / (passing - 1))!;
}

/// The colour of one band, by its own lower bound.
Color colourOfBand(GradeBand band, List<GradeBand> bands) =>
    bandColour(band.min, bands);

/// The foot of the passing ramp: between muted and ink, so it reads as a
/// quiet neutral and still clears contrast as small text in both modes.
Color get _slate => Color.lerp(C.muted, C.ink, .6)!;

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
