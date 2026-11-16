import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../bands.dart';
import '../models.dart';
import '../theme.dart';

/// A mono, uppercase, wide-tracked label. CSS `.eyebrow`.
class Eyebrow extends StatelessWidget {
  const Eyebrow(
    this.text, {
    super.key,
    this.color,
    this.upper = true,
    this.maxLines,
  });

  final String text;

  /// Defaults to muted, resolved when built so a palette swap reaches it.
  final Color? color;

  /// The CSS applies `text-transform:uppercase`; a couple of places override it
  /// back to sentence case for prose.
  final bool upper;
  final int? maxLines;

  @override
  Widget build(BuildContext context) => Text(
    upper ? text.toUpperCase() : text,
    style: T.eyebrow(color ?? C.muted),
    maxLines: maxLines,
    overflow: maxLines == null ? null : TextOverflow.ellipsis,
  );
}

/// The small round colour marker beside a subject name. CSS `.dot`.
class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// A flat, square-cornered tappable region. Material's ripple and rounding are
/// switched off app-wide; this keeps the press feedback to a simple opacity
/// change so the hard-edged look survives.
class Tap extends StatelessWidget {
  const Tap({
    super.key,
    required this.onTap,
    required this.child,
    this.semanticLabel,
    this.cursor = SystemMouseCursors.click,
  });

  final VoidCallback? onTap;
  final Widget child;
  final String? semanticLabel;
  final MouseCursor cursor;

  @override
  Widget build(BuildContext context) {
    final content = MouseRegion(
      cursor: onTap == null ? SystemMouseCursors.basic : cursor,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: child,
      ),
    );
    if (semanticLabel == null) return content;
    return Semantics(
      // `container: true` is load-bearing. Without it Flutter merges the
      // annotation into the nearest enclosing node, so the + button's label
      // gets glued onto the page headline and announced as one long string
      // instead of a focusable button of its own.
      container: true,
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: content),
    );
  }
}

/// CSS `.primary` — full-width, ink, reversed-out mono label.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onPressed,
    semanticLabel: label,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: onPressed == null ? C.rule : C.ink,
      alignment: Alignment.center,
      child: Text(label.toUpperCase(), style: T.primary),
    ),
  );
}

/// CSS `.ghost` — an outlined mono button. `filled` paints it highlighter
/// yellow, reserved for the single primary action on a card.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.color,
    this.icon,
    this.expand = false,
    this.quiet = false,
    this.solid = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  /// Filled with [color] (ink when null) and the label reversed out: the
  /// commit button of a dialog, where the highlighter would make a second
  /// primary over a screen that already has one.
  final bool solid;

  /// No box at all: an underlined label, for the secondary actions beside a
  /// section's main one, so a section has one button that looks like a button.
  final bool quiet;

  /// Outline (and [icon]) colour for an unfilled button — [C.red] for the one
  /// destructive action. Ink when null. The label stays ink either way, since
  /// small red type on white fails contrast.
  final Color? color;

  /// An optional leading glyph, drawn in [color].
  final IconData? icon;

  /// Fill the available width with the label centred, for a stacked pair of
  /// full-width choices.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final line = color ?? C.ink;
    final text = Text(
      label.toUpperCase(),
      style: quiet
          ? T.link
          : T.ghost(
              solid
                  ? C.onInk
                  : filled
                  ? C.onMark
                  : C.ink,
            ),
    );
    if (quiet) {
      return Tap(
        onTap: onPressed,
        semanticLabel: label,
        child: Padding(
          // The same height as a boxed button, so the two share a baseline
          // when they sit in one row.
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9.5),
          child: text,
        ),
      );
    }
    return Tap(
      onTap: onPressed,
      semanticLabel: label,
      child: Container(
        width: expand ? double.infinity : null,
        alignment: expand ? Alignment.center : null,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: solid
              ? line
              : filled
              ? C.mark
              : Colors.transparent,
          border: Border.all(color: filled ? C.ink : line, width: 1.5),
        ),
        child: icon == null
            ? text
            : Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  Icon(icon, size: 15, color: solid ? C.onInk : line),
                  text,
                ],
              ),
      ),
    );
  }
}

/// The 40px square in the header. CSS `.iconbtn`.
///
/// The web app drew its `+` and `✕` as text. Here they are Material icons
/// instead: neither bundled font covers U+2715 (HEAVY MULTIPLICATION X), so a
/// text `✕` renders as a missing-glyph box unless the platform happens to
/// substitute a fallback font. Same reason for every other close and delete
/// affordance in the app.
class IconSquare extends StatelessWidget {
  const IconSquare({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.open = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String semanticLabel;

  /// When the panel it controls is open, the button inverts.
  final bool open;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onPressed,
    semanticLabel: semanticLabel,
    child: Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: open ? Colors.transparent : C.ink,
        border: Border.all(color: C.ink, width: 1.5),
      ),
      child: Icon(icon, size: 22, color: open ? C.ink : C.onInk),
    ),
  );
}

/// The small dismiss/remove affordance used in task rows, subject rows and the
/// date field. A Material icon rather than a `✕` glyph — see [IconSquare].
class CloseGlyph extends StatelessWidget {
  const CloseGlyph({super.key, this.color, this.size = 16});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.close, size: size, color: color ?? C.muted);
}

/// A text button rendered in eyebrow type — the footer links.
class EyebrowButton extends StatelessWidget {
  const EyebrowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onPressed,
    semanticLabel: label,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Eyebrow(label, color: color ?? C.muted),
    ),
  );
}

/// CSS `input` — square, hairline-bordered, on the near-white field surface.
InputDecoration fieldDecoration({
  String? hint,
  bool mono = false,
  bool dense = false,
}) => InputDecoration(
      hintText: hint,
      hintStyle: (mono ? T.monoInput : T.input).copyWith(color: C.muted),
      filled: true,
      fillColor: C.field,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: dense ? 8 : 11,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: C.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: C.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: C.ink, width: 2),
      ),
    );

/// The shared page body: a centred 620px column with the standard header.
///
/// Every destination in the nav bar uses this, so the four pages agree on
/// margins, column width and the shape of a title. It is not a [Scaffold] —
/// the shell owns the one Scaffold and the nav bar beneath it.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.title,
    required this.children,
    this.eyebrow,
    this.eyebrowColor,
    this.action,
    this.controller,
  });

  final String title;
  final List<Widget> children;
  final String? eyebrow;
  final Color? eyebrowColor;

  /// The square button in the top right, where a page has one.
  final Widget? action;

  final ScrollController? controller;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('Coursework'),
                      const SizedBox(height: 3),
                      Text(title, style: T.h1),
                    ],
                  ),
                ),
                ?action,
              ],
            ),
            if (eyebrow != null) ...[
              const SizedBox(height: 10),
              Text(eyebrow!.toUpperCase(), style: T.eyebrow(eyebrowColor ?? C.muted)),
            ],
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    ),
  );
}

/// The app's one "nothing here" pattern: an icon, a heading, one sentence and
/// at most one action, all centred, set on the page rather than in a card (a
/// lone box over bare paper reads as a list that failed to load).
///
/// [minHeight] is for a list that is the page's whole content: pass the height
/// left below the page's chrome and the block sits in the vertical middle of
/// it rather than hugging the top. Without it the block takes its own height.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.head,
    required this.body,
    this.icon,
    this.action,
    this.onAction,
    this.primary = false,
    this.minHeight,
  });

  final String head;
  final String body;
  final IconData? icon;

  /// The one control that undoes whatever emptied the list, or starts it.
  final String? action;
  final VoidCallback? onAction;

  /// Lime, only where this is the screen's one call to action.
  final bool primary;

  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final block = Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 32, color: C.ink),
            const SizedBox(height: 12),
          ],
          Text(head, style: T.emptyHead, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            body,
            style: T.emptyBody.copyWith(color: C.ink),
            textAlign: TextAlign.center,
          ),
          if (action != null && onAction != null) ...[
            const SizedBox(height: 14),
            GhostButton(label: action!, filled: primary, onPressed: onAction!),
          ],
        ],
      ),
    );
    if (minHeight == null) return Center(child: block);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight!),
      child: Center(child: block),
    );
  }
}

/// A small numeric field, rendered in mono like every other piece of data.
///
/// Hands back null for an empty or unparseable box, which the store reads as
/// "untracked" — so clearing a mark is the same gesture as never entering one.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.semanticLabel,
    this.hint,
    this.suffix,
    this.dense = false,
  });

  final TextEditingController controller;
  final ValueChanged<double?> onChanged;
  final String semanticLabel;
  final String? hint;

  /// A trailing unit, e.g. `%`.
  final String? suffix;

  /// Tighter vertical padding, for a stack of rows such as the band editor.
  final bool dense;

  @override
  Widget build(BuildContext context) => Semantics(
    textField: true,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: TextField(
        controller: controller,
        style: T.monoInput,
        // A decimal weight is real (12.5% of a unit); a negative one is not.
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: fieldDecoration(
          hint: hint,
          mono: true,
          dense: dense,
        ).copyWith(
          // Undense, the [DateField]'s 45px, so a date and the numbers in one
          // row of a form are one height of box.
          contentPadding: dense
              ? null
              : const EdgeInsets.symmetric(horizontal: 10, vertical: 12.5),
          suffixText: suffix,
          suffixStyle: T.monoInput.copyWith(color: C.muted),
        ),
        onChanged: (raw) {
          final text = raw.trim();
          if (text.isEmpty) return onChanged(null);
          final v = double.tryParse(text);
          onChanged(v == null || v < 0 ? null : v);
        },
      ),
    ),
  );
}

/// A labelled field. CSS `.flabel` + `input`.
class LabelledField extends StatelessWidget {
  const LabelledField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(label.toUpperCase(), style: T.flabel),
      ),
      child,
    ],
  );
}

/// The date picker's wording: the app's own date format rather than the US
/// one Material ships with, and weeks that start on Monday like the fortnight
/// strip on the assignments page.
class _PickerLocalizations extends DefaultMaterialLocalizations {
  const _PickerLocalizations();

  static const delegate = _PickerLocalizationsDelegate();

  @override
  int get firstDayOfWeekIndex => 1;

  /// "THU 6 AUG" — the headline, and how a due date reads on a card.
  @override
  String formatMediumDate(DateTime date) => shortDate(date);

  /// "AUGUST 2026" above the grid.
  @override
  String formatMonthYear(DateTime date) =>
      super.formatMonthYear(date).toUpperCase();

}

/// A date the way the app writes one on screen: "FRI 7 AUG".
String shortDate(DateTime date) =>
    '${_shortDays[date.weekday - 1]} ${date.day} '
    '${_shortMonths[date.month - 1]}';

const _shortDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _shortMonths = [
  'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
  'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
];

class _PickerLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _PickerLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      SynchronousFuture<MaterialLocalizations>(const _PickerLocalizations());

  @override
  bool shouldReload(_PickerLocalizationsDelegate old) => false;
}

/// A tappable date field standing in for the web app's `<input type="date">`.
///
/// Shows a picked date the way the rest of the app writes one ("FRI 7 AUG",
/// mono), and hands back the `YYYY-MM-DD` string form so nothing downstream
/// has to deal with a [DateTime].
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  /// `YYYY-MM-DD`, or empty.
  final String value;
  final ValueChanged<String> onChanged;
  final String? label;

  Future<void> _pick(BuildContext context) async {
    // Through the clock seam, not DateTime.now(): a snapshot of the calendar
    // would otherwise capture the real date and fail the following day.
    final now = midnight();
    final current = value.isEmpty ? null : DateTime.tryParse(value);
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => Localizations.override(
        context: context,
        // Monday-first, with dates written the way the rest of the app writes
        // them ("THU 6 AUG", "AUGUST 2026"), whatever the device locale.
        delegates: const [_PickerLocalizations.delegate],
        child: Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: buildDatePickerTheme(),
          ),
          child: _DatePickerSheet(
            initial: current ?? now,
            today: now,
            // Wide enough for a whole degree either side of today.
            first: DateTime(now.year - 2),
            last: DateTime(now.year + 6),
          ),
        ),
      ),
    );
    if (picked == null) return;
    onChanged(
      '${picked.year.toString().padLeft(4, '0')}-'
      '${picked.month.toString().padLeft(2, '0')}-'
      '${picked.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = value.isEmpty ? null : DateTime.tryParse(value);
    // The clear button is a sibling of the pick target, not a descendant of it.
    // Nesting it inside would put it under the outer button's ExcludeSemantics
    // and make it unreachable to a screen reader.
    final field = Container(
      decoration: BoxDecoration(
        color: C.field,
        border: Border.all(color: C.rule),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tap(
              onTap: () => _pick(context),
              semanticLabel: value.isEmpty
                  ? 'Pick a due date'
                  : 'Due date $value, tap to change',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 12, 4, 12),
                // Empty, the hint stays the raw form the field stands for.
                child: Text(
                  value.isEmpty
                      ? 'yyyy-mm-dd'
                      : date == null
                      ? value
                      : shortDate(date),
                  style: T.monoInput.copyWith(
                    color: value.isEmpty ? C.muted : C.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          if (value.isNotEmpty)
            Tap(
              onTap: () => onChanged(''),
              semanticLabel: 'Clear due date',
              child: const Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 10, 12),
                child: CloseGlyph(size: 15),
              ),
            ),
        ],
      ),
    );
    if (label == null) return field;
    return LabelledField(label: label!, child: field);
  }
}

/// The date picker: a sheet anchored to the bottom like the app's other
/// dialogs, with the chosen date as its headline, Material's calendar grid in
/// the middle and the app's own buttons at the foot.
///
/// The grid and the typed-entry field are Material's; only the frame around
/// them is the app's, so picking, typing and validating a date work exactly as
/// the stock dialog did.
class _DatePickerSheet extends StatefulWidget {
  const _DatePickerSheet({
    required this.initial,
    required this.today,
    required this.first,
    required this.last,
  });

  final DateTime initial;
  final DateTime today;
  final DateTime first;
  final DateTime last;

  @override
  State<_DatePickerSheet> createState() => _DatePickerSheetState();
}

class _DatePickerSheetState extends State<_DatePickerSheet> {
  final _form = GlobalKey<FormState>();
  late DateTime _selected = widget.initial;
  bool _typing = false;
  AutovalidateMode _validate = AutovalidateMode.disabled;

  void _toggleMode() => setState(() {
    if (_typing) _form.currentState!.save();
    _validate = AutovalidateMode.disabled;
    _typing = !_typing;
  });

  void _confirm() {
    if (_typing) {
      final form = _form.currentState!;
      if (!form.validate()) {
        setState(() => _validate = AutovalidateMode.always);
        return;
      }
      form.save();
    }
    Navigator.of(context).pop(_selected);
  }

  void _changed(DateTime date) => setState(() => _selected = date);

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    // The frame of every other sheet in the app (the delete confirm, the edit
    // sheet): a 3px ink rule on top, 16 in from each side, 16 above the
    // headline, 18 from the content to the button row and 20 below it.
    return Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: EdgeInsets.zero,
      backgroundColor: C.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: C.ink, width: 3)),
        ),
        child: SafeArea(
          top: false,
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 588),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    // 4 on the right: the pencil's 44px target then puts its
                    // glyph on the same 16px edge as the buttons below.
                    padding: const EdgeInsets.fromLTRB(16, 16, 4, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Eyebrow('Due date', color: C.ink),
                              Text(
                                shortDate(_selected),
                                style: T.pickerHeadline,
                              ),
                            ],
                          ),
                        ),
                        Tap(
                          onTap: _toggleMode,
                          semanticLabel: _typing
                              ? l10n.calendarModeButtonLabel
                              : l10n.inputDateModeButtonLabel,
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              _typing
                                  ? Icons.calendar_today_outlined
                                  : Icons.edit_outlined,
                              size: 20,
                              color: C.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Inset like the content, not a full-bleed divider.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Container(height: 1, color: C.rule),
                  ),
                  if (_typing)
                    Form(
                      key: _form,
                      autovalidateMode: _validate,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                        child: InputDatePickerFormField(
                          initialDate: _selected,
                          firstDate: widget.first,
                          lastDate: widget.last,
                          onDateSubmitted: _changed,
                          onDateSaved: _changed,
                          autofocus: true,
                        ),
                      ),
                    )
                  else
                    // Full width: Material insets its grid 12 and each day's
                    // square 4 more, which puts the squares on the sheet's
                    // 16px edges.
                    SizedBox(
                      // Material's month row (52) and seven 40px rows
                      // (weekdays and six weeks) rather than its 48px ones:
                      // the grid is a quick choice, not the whole screen.
                      height: _calendarHeight,
                      child: CalendarDatePicker(
                        initialDate: _selected,
                        currentDate: widget.today,
                        firstDate: widget.first,
                        lastDate: widget.last,
                        onDateChanged: _changed,
                      ),
                    ),
                  Padding(
                    // 14 here plus the 4 Material leaves under the last row
                    // of days makes the 18 the delete confirm has above its
                    // buttons.
                    padding: EdgeInsets.fromLTRB(16, _typing ? 18 : 14, 16, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      spacing: 8,
                      children: [
                        GhostButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        GhostButton(
                          label: 'Set date',
                          solid: true,
                          onPressed: _confirm,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _calendarHeight = 52 + 40.0 * 7;
}

/// The task tick box. CSS `.box`, with the check drawn to match the web app's
/// inline SVG (`M4 12l6 6L20 6`, stroke width 4 in a 24-unit box) rather than
/// substituting Material's thinner check glyph.
class CheckBoxSquare extends StatelessWidget {
  const CheckBoxSquare({super.key, required this.done, required this.onTap});

  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    semanticLabel: done ? 'Mark task unfinished' : 'Mark task finished',
    child: Container(
      width: 19,
      height: 19,
      decoration: BoxDecoration(
        color: done ? C.mark : Colors.transparent,
        border: Border.all(color: done ? C.ink : C.rule, width: 1.5),
      ),
      child: done
          ? const CustomPaint(painter: _CheckMark(), size: Size(12, 12))
          : null,
    ),
  );
}

class _CheckMark extends CustomPainter {
  const _CheckMark();

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = Paint()
      ..color = C.onMark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * k
      ..strokeCap = StrokeCap.square;
    canvas.drawPath(
      Path()
        ..moveTo(4 * k, 12 * k)
        ..lineTo(10 * k, 18 * k)
        ..lineTo(20 * k, 6 * k),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CheckMark oldDelegate) => false;
}

/// A white card surface with the design's 1px offset shadow.
class Surface extends StatelessWidget {
  const Surface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.topBorder,
  });

  final Widget child;
  final EdgeInsets padding;

  /// The 3px accent rule some panels carry — highlighter for "add", ink for
  /// "manage".
  final Color? topBorder;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: C.card,
      border: topBorder == null
          ? null
          : Border(top: BorderSide(color: topBorder!, width: 3)),
    ),
    child: child,
  );
}

/// Dropdown styled to match the flat fields. Used for choosing a subject.
class SubjectDropdown<TValue> extends StatelessWidget {
  const SubjectDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.semanticLabel,
    this.fontSize = 15,
  });

  final TValue value;
  final List<DropdownMenuItem<TValue>> items;
  final ValueChanged<TValue?> onChanged;
  final String semanticLabel;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    child: DropdownButtonFormField<TValue>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      icon: Icon(Icons.arrow_drop_down, color: C.ink, size: 20),
      dropdownColor: C.card,
      borderRadius: BorderRadius.zero,
      style: TextStyle(
        fontFamily: kSans,
        fontSize: fontSize,
        color: C.ink,
        fontVariations: const [FontVariation('wght', 400)],
      ),
      decoration: fieldDecoration(),
    ),
  );
}

/// A [Switch] with its label on the same semantics node.
///
/// A [Semantics] wrapper on its own leaves the switch's tap target as a
/// separate node with no label of its own, which a screen reader announces as
/// just "switch". Merging puts the label, the toggled state and the tap on one
/// node.
class LabelledSwitch extends StatelessWidget {
  const LabelledSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      label: label,
      child: Switch(value: value, onChanged: onChanged),
    ),
  );
}

/// The colour of a grade bar — status, so every band gets one.
///
/// Below the pass mark is red. At or above it is green, stronger the higher
/// the band, so the top band is the full green and a bare pass a lighter one
/// (never so light that it disappears against a white card).
/// Text keeps [gradeColour]'s three steps (red, ink, green); a bar has no
/// label to carry the band, so it needs the extra steps.
Color gradeBarColour(double percent, List<GradeBand> bands) {
  if (bands.length < 2) {
    final c = gradeColour(percent, bands);
    return c == C.ink ? C.green.withValues(alpha: .6) : c;
  }
  if (percent + 1e-9 < bands[1].min) return C.red;
  final passing = bands.length - 1;
  final band = bandFor(percent, bands);
  final rank = band == null ? 0 : bands.indexOf(band) - 1;
  final t = passing <= 1 ? 1.0 : rank / (passing - 1);
  return C.green.withValues(alpha: .55 + .45 * t);
}
