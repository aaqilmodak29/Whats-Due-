import 'package:flutter/material.dart';

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
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onPressed,
    semanticLabel: label,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: filled ? C.mark : Colors.transparent,
        border: Border.all(color: C.ink, width: 1.5),
      ),
      child: Text(
        label.toUpperCase(),
        style: T.ghost(filled ? C.onMark : C.ink),
      ),
    ),
  );
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
InputDecoration fieldDecoration({String? hint, bool mono = false}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: (mono ? T.monoInput : T.input).copyWith(color: C.muted),
      filled: true,
      fillColor: C.field,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
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

/// The white card carrying a "nothing here" explanation. Used by every list in
/// the app, which all have several distinct reasons to be empty.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.head, required this.body});

  final String head;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    color: C.card,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 26),
    child: Column(
      children: [
        Text(head, style: T.emptyHead, textAlign: TextAlign.center),
        const SizedBox(height: 5),
        Text(body, style: T.emptyBody, textAlign: TextAlign.center),
      ],
    ),
  );
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
  });

  final TextEditingController controller;
  final ValueChanged<double?> onChanged;
  final String semanticLabel;
  final String? hint;

  /// A trailing unit, e.g. `%`.
  final String? suffix;

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
        decoration: fieldDecoration(hint: hint, mono: true).copyWith(
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

/// A tappable date field standing in for the web app's `<input type="date">`.
///
/// Shows the raw `YYYY-MM-DD` in mono, matching how the browser renders a date
/// input, and hands back the same string form so nothing downstream has to
/// deal with a [DateTime].
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
    final now = DateTime.now();
    final current = value.isEmpty ? null : DateTime.tryParse(value);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      // Wide enough for a whole degree either side of today.
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 6),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: DatePickerThemeData(
            backgroundColor: C.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            todayForegroundColor: WidgetStatePropertyAll(C.ink),
          ),
        ),
        child: child!,
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
                child: Text(
                  value.isEmpty ? 'yyyy-mm-dd' : value,
                  style: T.monoInput.copyWith(
                    color: value.isEmpty ? C.muted : C.ink,
                  ),
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
