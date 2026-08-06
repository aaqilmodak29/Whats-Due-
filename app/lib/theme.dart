import 'package:flutter/material.dart';

/// Colour tokens, ported verbatim from the web app's CSS custom properties.
///
/// The look is subject-derived — the three marks a student makes on paper:
/// ink, highlighter, red pen. Two colour channels carry two distinct meanings
/// and must never be merged:
///
///   * a card's left spine encodes **urgency**
///   * the dot beside a subject name encodes **which subject**
///
/// Colouring the spine by subject would destroy at-a-glance triage, which is
/// the app's entire reason to exist.
class C {
  C._();

  static const ink = Color(0xFF16202E);
  static const paper = Color(0xFFE3E8ED);
  static const card = Color(0xFFFFFFFF);
  static const rule = Color(0xFFC9D2DB);
  static const muted = Color(0xFF6B7A8C);
  static const mark = Color(0xFFDCEE3A);
  static const red = Color(0xFFFF3B1F);
  static const green = Color(0xFF1B9C68);

  /// Input surfaces — the web app's `#FAFBFC`.
  static const field = Color(0xFFFAFBFC);
}

/// Subject palette, assigned round-robin by subject count.
///
/// Held as `#RRGGBB` strings rather than [Color] because that is exactly what
/// the web app writes into storage, which keeps a JSON export from one usable
/// as an import to the other.
const kPalette = <String>[
  '#0E7C7B',
  '#2F5FA8',
  '#7B3F61',
  '#C08A2E',
  '#4A7A3A',
  '#B4502A',
  '#A32E76',
  '#4A5568',
];

Color hexToColor(String hex) {
  final h = hex.replaceFirst('#', '').trim();
  final v = int.tryParse(h, radix: 16);
  if (v == null) return C.muted;
  return Color(h.length <= 6 ? 0xFF000000 | v : v);
}

String colorToHex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

const kSans = 'Inter';
const kMono = 'PlexMono';

/// Inter ships only as a variable font, so the weight has to travel as a
/// [FontVariation] as well as a [FontWeight]. Setting [FontWeight] alone
/// renders every weight at the file's default instance.
TextStyle _sans(
  double size,
  int weight, {
  double em = 0,
  Color color = C.ink,
  double? height,
  TextDecoration? decoration,
}) => TextStyle(
  fontFamily: kSans,
  fontSize: size,
  color: color,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  // CSS tracking is em-relative; Flutter's letterSpacing is absolute.
  letterSpacing: size * em,
  height: height,
  decoration: decoration,
  decorationColor: color,
);

TextStyle _mono(
  double size, {
  int weight = 400,
  double em = 0,
  Color color = C.ink,
  double? height,
}) => TextStyle(
  fontFamily: kMono,
  fontSize: size,
  color: color,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  letterSpacing: size * em,
  height: height,
);

/// Type scale. Two families, sharply separated by role:
/// **sans** for titles and task text, **mono** for every piece of data and
/// every label. The mono-for-data convention is what makes the app read like a
/// timetable rather than a to-do list — it is load-bearing, not decorative.
class T {
  T._();

  /// CSS `.eyebrow` — mono 10 / .14em. Callers uppercase their own text.
  static TextStyle eyebrow([Color color = C.muted]) =>
      _mono(10, em: .14, color: color, height: 1.4);

  /// CSS `h1` — sans 32 / 800 / -.035em.
  static TextStyle get h1 => _sans(32, 800, em: -.035, height: 1.05);

  /// CSS `.flabel` — mono 9 / .12em.
  static TextStyle get flabel => _mono(9, em: .12, color: C.muted);

  /// CSS `.count` — mono 11 / 600 / .06em, coloured by urgency.
  static TextStyle count(Color color) =>
      _mono(11, weight: 600, em: .06, color: color);

  /// CSS `.title` — sans 17 / 700 / -.015em.
  static TextStyle title({bool struck = false}) => _sans(
    17,
    700,
    em: -.015,
    height: 1.25,
    decoration: struck ? TextDecoration.lineThrough : null,
  );

  /// CSS `.frac` — mono 10, muted.
  static TextStyle get frac => _mono(10, color: C.muted);

  /// CSS `.ttext` — sans 14, struck and muted once ticked.
  static TextStyle task({required bool done}) => _sans(
    14,
    400,
    height: 1.3,
    color: done ? C.muted : C.ink,
    decoration: done ? TextDecoration.lineThrough : null,
  );

  /// CSS `.chip` — mono 10 / .08em.
  static TextStyle chip(Color color) => _mono(10, em: .08, color: color);

  /// CSS `.tab` — mono 11 / .1em.
  static TextStyle tab(Color color) => _mono(11, em: .1, color: color);

  /// CSS `.primary` — mono 12 / .1em, reversed out of ink.
  static TextStyle get primary => _mono(12, em: .1, color: Colors.white);

  /// CSS `.ghost` — mono 11 / .08em.
  static TextStyle ghost([Color color = C.ink]) =>
      _mono(11, em: .08, color: color);

  /// Text typed into a field — sans 15.
  static TextStyle get input => _sans(15, 400);

  /// Dates and other data typed into a field — mono 13.
  static TextStyle get monoInput => _mono(13);

  /// CSS `.empty b` and `.empty span`.
  static TextStyle get emptyHead => _sans(15, 600);
  static TextStyle get emptyBody => _sans(13, 400, color: C.muted, height: 1.4);

  /// Prose in the backup screen. The web app's `.eyebrow` with
  /// `text-transform:none` applied.
  static TextStyle get note =>
      _mono(10, em: .04, color: C.muted, height: 1.65);

  static TextStyle get body => _sans(14, 400, height: 1.45);
}

/// Page furniture shared by every screen: paper background, a 620px column.
ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: kSans,
  );
  return base.copyWith(
    scaffoldBackgroundColor: C.paper,
    colorScheme: base.colorScheme.copyWith(
      primary: C.ink,
      secondary: C.mark,
      surface: C.card,
      error: C.red,
    ),
    // The design uses hard 90-degree corners throughout; Material's default
    // rounding fights it, so splashes and highlights are switched off rather
    // than restyled.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: C.ink,
      selectionColor: C.mark,
      selectionHandleColor: C.ink,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: const BoxDecoration(color: C.ink),
      textStyle: T.eyebrow(Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
  );
}
