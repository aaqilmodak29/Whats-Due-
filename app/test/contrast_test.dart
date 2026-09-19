import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whats_due/theme.dart';

/// Guards the places where foreground and background are chosen separately.
///
/// These fail silently and invisibly rather than loudly: nothing throws when
/// text is painted the same colour as what is behind it, no layout shifts, and
/// no other test notices. Both cases below shipped.
void main() {
  tearDown(() => C.palette = Palette.light);

  /// Rough perceptual distance. Not a WCAG figure — just enough to catch a
  /// foreground that has collapsed onto its own background.
  double distance(Color a, Color b) {
    double lum(Color c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    return (lum(a) - lum(b)).abs();
  }

  group('the date picker resolves today against its own background', () {
    for (final (name, palette) in [
      ('light', Palette.light),
      ('dark', Palette.night),
    ]) {
      test('in $name', () {
        C.palette = palette;
        final theme = buildDatePickerTheme();

        // Today is the selection the moment the picker opens, because the
        // initial date defaults to it. A flat todayForegroundColor applied in
        // that state too, painting ink on the ink selection fill: the current
        // date was simply not there until you selected something else.
        const selected = {WidgetState.selected};
        final fg = theme.todayForegroundColor!.resolve(selected)!;
        final bg = theme.todayBackgroundColor!.resolve(selected)!;
        expect(
          distance(fg, bg),
          greaterThan(0.3),
          reason: 'selected today is $fg on $bg',
        );

        // And unselected, where the background is the card.
        final restFg = theme.todayForegroundColor!.resolve({})!;
        final restBg = theme.todayBackgroundColor!.resolve({})!;
        expect(restBg.a, 0, reason: 'unselected today should not be filled');
        expect(distance(restFg, palette.card), greaterThan(0.3));
      });
    }
  });

  group('a selected day is legible', () {
    for (final (name, palette) in [
      ('light', Palette.light),
      ('dark', Palette.night),
    ]) {
      test('in $name', () {
        C.palette = palette;
        final theme = buildDatePickerTheme();
        const selected = {WidgetState.selected};
        expect(
          distance(
            theme.dayForegroundColor!.resolve(selected)!,
            theme.dayBackgroundColor!.resolve(selected)!,
          ),
          greaterThan(0.3),
        );
        // An ordinary day sits on the card.
        expect(
          distance(theme.dayForegroundColor!.resolve({})!, palette.card),
          greaterThan(0.3),
        );
      });
    }
  });

  group('what sits on the highlighter stays dark', () {
    // The update banner is highlighter-filled, and painted its text with ink —
    // which is near-white after dark, so the whole bar became unreadable.
    for (final palette in [Palette.light, Palette.night]) {
      test('in ${palette.dark ? 'dark' : 'light'}', () {
        expect(distance(palette.onMark, palette.mark), greaterThan(0.3));
      });
    }

    test('ink is not safe on the highlighter after dark', () {
      // The reason onMark exists at all: guards against anyone "simplifying"
      // it back to ink.
      expect(distance(Palette.night.ink, Palette.night.mark), lessThan(0.3));
    });
  });

  group('what sits on ink stays legible', () {
    for (final palette in [Palette.light, Palette.night]) {
      test('in ${palette.dark ? 'dark' : 'light'}', () {
        expect(distance(palette.onInk, palette.ink), greaterThan(0.3));
      });
    }
  });

  group('every grade colour reads on a card', () {
    // Grades paints the percentage in one of three colours against the card.
    // Red and green are lifted after dark for exactly this reason, so the
    // pairing is worth holding rather than assuming.
    //
    // Only each colour against the card, deliberately — not red against green.
    // They sit within 0.02 of each other in luminance, so that comparison can
    // never pass, and it should not have to: the colour is always redundant.
    // The band name is beside the percentage, the percentage is a number, and
    // the bar has a length. Nothing in Grades is knowable by hue alone.
    for (final palette in [Palette.light, Palette.night]) {
      test('in ${palette.dark ? 'dark' : 'light'}', () {
        for (final c in [palette.red, palette.ink, palette.green]) {
          expect(distance(c, palette.card), greaterThan(0.2));
        }
      });
    }
  });
}
