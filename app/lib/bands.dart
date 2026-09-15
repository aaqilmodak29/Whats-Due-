/// A letter grade band: a name, and the lowest percentage that earns it.
///
/// Stored as a lower bound rather than a range. Ranges would let two bands
/// overlap or leave a gap between them, and there is no sensible answer to
/// "what grade is 62" when 60–61 is a Pass and 63–70 a Credit. Bounds cannot
/// express that mistake: every percentage lands in exactly one band.
class GradeBand {
  const GradeBand({required this.name, required this.min});

  factory GradeBand.fromJson(Map<String, dynamic> j) => GradeBand(
    name: (j['name'] as String? ?? '').trim(),
    min: switch (j['min']) {
      num n => n.toDouble().clamp(0, 100),
      String s => (double.tryParse(s.trim()) ?? 0).clamp(0, 100),
      _ => 0,
    },
  );

  final String name;

  /// Inclusive lower bound, 0–100.
  final double min;

  Map<String, dynamic> toJson() => {'name': name, 'min': min};

  GradeBand copyWith({String? name, double? min}) =>
      GradeBand(name: name ?? this.name, min: min ?? this.min);
}

/// What the band editor starts from. Australian, because that is where this is
/// used — but every field is editable, including the names, because "does your
/// university use letter grades" is not a question with one answer.
const kDefaultBands = <GradeBand>[
  GradeBand(name: 'Fail', min: 0),
  GradeBand(name: 'Pass', min: 50),
  GradeBand(name: 'Credit', min: 65),
  GradeBand(name: 'Distinction', min: 75),
  GradeBand(name: 'High Distinction', min: 85),
];

/// Fewer than two bands cannot express a threshold, and past six the editor
/// stops fitting a phone.
const kMinBands = 2;
const kMaxBands = 6;

/// Sorted by their lower bound, lowest first, with unnamed bands dropped.
///
/// Everything below reads bands in this order, so normalising once here means
/// nothing else has to care what order they were entered or edited in.
List<GradeBand> normaliseBands(Iterable<GradeBand> bands) {
  final out = bands.where((b) => b.name.trim().isNotEmpty).toList()
    ..sort((a, b) => a.min.compareTo(b.min));
  return out;
}

/// The band [percent] falls in, or null when no bands are configured.
///
/// The lowest band catches everything beneath the next one up, whatever its
/// bound — so a percentage can only fall through when the bands do not start
/// at zero, which is the one case the editor warns about rather than silently
/// rounding away.
GradeBand? bandFor(double percent, List<GradeBand> bands) {
  GradeBand? found;
  for (final b in bands) {
    if (percent + 1e-9 >= b.min) {
      found = b;
    } else {
      break;
    }
  }
  return found;
}

/// The band immediately above [b], or null when it is already the top.
GradeBand? bandAbove(GradeBand b, List<GradeBand> bands) {
  for (final other in bands) {
    if (other.min > b.min) return other;
  }
  return null;
}

/// What is wrong with [bands], or null when nothing is.
///
/// Returned rather than thrown: this drives a warning line under the editor
/// while someone is still typing, and a half-entered band is not an error yet.
String? bandProblem(List<GradeBand> bands) {
  if (bands.length < kMinBands) {
    return 'Two bands at least, or there is no threshold to cross.';
  }
  if (bands.first.min > 0) {
    return 'The lowest band should start at 0, or scores beneath '
        '${trimBound(bands.first.min)}% land in no band at all.';
  }
  for (var i = 1; i < bands.length; i++) {
    if (bands[i].min == bands[i - 1].min) {
      return '${bands[i].name} and ${bands[i - 1].name} both start at '
          '${trimBound(bands[i].min)}%. Give them different bounds.';
    }
  }
  return null;
}

/// `65` rather than `65.0`, while still allowing `62.5`.
String trimBound(double v) {
  final r = v.round();
  return (v - r).abs() < 0.005 ? '$r' : v.toStringAsFixed(1);
}
