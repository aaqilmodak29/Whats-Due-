import 'package:flutter/material.dart';

/// One set of colour tokens.
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
class Palette {
  const Palette({
    required this.ink,
    required this.paper,
    required this.card,
    required this.rule,
    required this.muted,
    required this.mark,
    required this.red,
    required this.green,
    required this.field,
    required this.dark,
  });

  /// Text and lines. Light on paper in dark mode, so the *name* is the role,
  /// not the colour — do not read `ink` as "black".
  final Color ink;

  final Color paper;
  final Color card;
  final Color rule;
  final Color muted;

  /// The highlighter. Deliberately identical in both modes: it is the one
  /// saturated accent in the design, it carries enough contrast against a dark
  /// ground, and shifting it would break the paper metaphor.
  final Color mark;

  final Color red;
  final Color green;

  /// Input surfaces.
  final Color field;

  final bool dark;

  /// What sits *on* a filled ink surface — a primary button's label, the icon
  /// in the header square, a tooltip.
  ///
  /// Ink is near-white after dark, so reversing out to white would put white on
  /// white. This follows the ground instead.
  Color get onInk => dark ? paper : const Color(0xFFFFFFFF);

  /// What sits *on* the highlighter — a filled button's label, the tick inside
  /// a checked box.
  ///
  /// Always the dark ink, in both modes. Using [ink] here would render a
  /// near-white label on highlighter yellow in dark mode, which is unreadable;
  /// this is the one place the two roles genuinely diverge.
  Color get onMark => const Color(0xFF16202E);

  /// Ported verbatim from the web app's CSS custom properties.
  static const light = Palette(
    ink: Color(0xFF16202E),
    paper: Color(0xFFE3E8ED),
    card: Color(0xFFFFFFFF),
    rule: Color(0xFFC9D2DB),
    muted: Color(0xFF6B7A8C),
    mark: Color(0xFFDCEE3A),
    red: Color(0xFFFF3B1F),
    green: Color(0xFF1B9C68),
    field: Color(0xFFFAFBFC),
    dark: false,
  );

  /// The same design after dark, not a different one: the roles keep their
  /// relationships, so a card still sits above the page and a rule still reads
  /// as a hairline. Red and green are lifted, because the light-mode values are
  /// too dense to read against a dark ground.
  static const night = Palette(
    ink: Color(0xFFE6ECF2),
    paper: Color(0xFF0E1622),
    card: Color(0xFF16202E),
    rule: Color(0xFF2C3849),
    muted: Color(0xFF8A99AB),
    mark: Color(0xFFDCEE3A),
    red: Color(0xFFFF6A52),
    green: Color(0xFF2FBF85),
    field: Color(0xFF111B28),
    dark: true,
  );
}

/// The palette in force.
///
/// Every widget reads `C.ink` and friends rather than holding a colour, so a
/// swap here plus the root rebuild repaints the whole app. This is global
/// mutable state, which the rest of the codebase avoids — the alternative was
/// threading a palette through several hundred call sites for a setting that
/// changes at most a handful of times in the app's life.
///
/// The cost is that none of these can be `const` any more. That is not a
/// formality: a `const` colour is baked in at compile time and would keep its
/// light value after a swap.
class C {
  C._();

  static Palette palette = Palette.light;

  static Color get ink => palette.ink;
  static Color get paper => palette.paper;
  static Color get card => palette.card;
  static Color get rule => palette.rule;
  static Color get muted => palette.muted;
  static Color get mark => palette.mark;
  static Color get red => palette.red;
  static Color get green => palette.green;
  static Color get field => palette.field;
  static Color get onMark => palette.onMark;
  static Color get onInk => palette.onInk;

  static bool get isDark => palette.dark;
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
  Color? color,
  double? height,
  TextDecoration? decoration,
}) => TextStyle(
  fontFamily: kSans,
  fontSize: size,
  color: color ?? C.ink,
  fontWeight: FontWeight.values[(weight ~/ 100) - 1],
  fontVariations: [FontVariation('wght', weight.toDouble())],
  // CSS tracking is em-relative; Flutter's letterSpacing is absolute.
  letterSpacing: size * em,
  height: height,
  decoration: decoration,
  decorationColor: color ?? C.ink,
);

TextStyle _mono(
  double size, {
  int weight = 400,
  double em = 0,
  Color? color,
  double? height,
}) => TextStyle(
  fontFamily: kMono,
  fontSize: size,
  color: color ?? C.ink,
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
  static TextStyle eyebrow([Color? color]) =>
      _mono(10, em: .14, color: color ?? C.muted, height: 1.4);

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
  static TextStyle get primary => _mono(12, em: .1, color: C.onInk);

  /// CSS `.ghost` — mono 11 / .08em.
  static TextStyle ghost([Color? color]) =>
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
    brightness: C.isDark ? Brightness.dark : Brightness.light,
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
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: C.ink,
      selectionColor: C.mark,
      selectionHandleColor: C.ink,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: C.ink),
      textStyle: T.eyebrow(C.onInk),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    ),
  );
}
