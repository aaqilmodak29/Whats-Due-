import 'package:flutter/material.dart';

import '../bands.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';
import 'band_colours.dart';

/// Letter grading: on or off, and what the bands are.
///
/// The app works in percentages by default and always will — bands are a
/// display layer over the same numbers, not a different way of storing them.
/// Turning them off loses nothing but the letters.
///
/// Collapsed by default. Five band rows is the tallest thing on Settings and
/// it is set up once a degree, so it folds away behind the one line saying
/// what it is currently doing.
class GradingSection extends StatefulWidget {
  const GradingSection({super.key, required this.store});

  final AppStore store;

  @override
  State<GradingSection> createState() => _GradingSectionState();
}

class _GradingSectionState extends State<GradingSection> {
  bool _open = false;

  AppStore get store => widget.store;

  String get _state =>
      store.usesLetterGrades ? 'LETTER GRADES ON' : 'PERCENTAGES ONLY';

  /// Unframed: Settings sets it in one card with Appearance, divided by a
  /// rule, so two one-line sections do not each take a whole card.
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Tap(
        onTap: () => setState(() => _open = !_open),
        semanticLabel:
            'Grading, $_state, tap to ${_open ? 'collapse' : 'expand'}',
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            spacing: 6,
            children: [
              Expanded(child: Eyebrow('Grading', color: C.ink)),
              // Only while shut: open, the row below says the same thing.
              if (!_open) Text(_state, style: T.count(C.ink)),
              Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: C.ink,
              ),
            ],
          ),
        ),
      ),

      if (_open) ...[
        Row(
          children: [
            Expanded(child: Text(_state, style: T.count(C.ink))),
            LabelledSwitch(
              label: 'Letter grades',
              value: store.usesLetterGrades,
              onChanged: (on) => store.setBands(on ? kDefaultBands : const []),
            ),
          ],
        ),
        if (store.usesLetterGrades) ...[
          const SizedBox(height: 6),
          BandEditor(store: store),
        ],
      ],
    ],
  );
}

/// The band list: a name and a lower bound each.
///
/// Edited in place rather than behind a dialog. The bands only make sense
/// relative to one another — whether 65 is a Credit depends entirely on where
/// Distinction starts — so they have to be visible together while being
/// changed.
class BandEditor extends StatefulWidget {
  const BandEditor({super.key, required this.store});

  final AppStore store;

  @override
  State<BandEditor> createState() => _BandEditorState();
}

class _BandEditorState extends State<BandEditor> {
  AppStore get store => widget.store;
  List<GradeBand> get bands => store.bands;

  /// One controller per row, keyed by position. Rebuilding them every frame
  /// would reset the cursor on every keystroke.
  final _names = <int, TextEditingController>{};
  final _mins = <int, TextEditingController>{};

  @override
  void dispose() {
    for (final c in [..._names.values, ..._mins.values]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _name(int i, String seed) =>
      _names.putIfAbsent(i, () => TextEditingController(text: seed));

  TextEditingController _min(int i, double seed) =>
      _mins.putIfAbsent(i, () => TextEditingController(text: trimBound(seed)));

  /// Rewrites the whole list, because a bound change can reorder it.
  void _replace(int i, GradeBand band) {
    final next = [...bands]..[i] = band;
    store.setBands(next);
  }

  void _add() {
    final top = bands.isEmpty ? 50.0 : bands.last.min;
    store.setBands([
      ...bands,
      GradeBand(name: 'Band ${bands.length + 1}', min: (top + 5).clamp(0, 100)),
    ]);
    _forget();
  }

  void _remove(int i) {
    store.setBands([...bands]..removeAt(i));
    _forget();
  }

  /// Controllers are positional, so anything that shifts positions has to drop
  /// them — otherwise row two keeps row three's text.
  void _forget() {
    for (final c in [..._names.values, ..._mins.values]) {
      c.dispose();
    }
    _names.clear();
    _mins.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final problem = bandProblem(bands);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            spacing: 8,
            children: [
              const SizedBox(width: _rule - 8),
              Expanded(child: Eyebrow('Band', color: C.ink)),
              SizedBox(width: _from, child: Eyebrow('From', color: C.ink)),
            ],
          ),
        ),
        // Highest first, the order the bands are read in everywhere else.
        for (var i = bands.length - 1; i >= 0; i--) _row(i, bands[i]),
        Row(
          spacing: 12,
          children: [
            if (bands.length < kMaxBands)
              GhostButton(label: 'Add a band', quiet: true, onPressed: _add),
            GhostButton(
              label: 'Reset',
              quiet: true,
              onPressed: () {
                store.setBands(kDefaultBands);
                _forget();
              },
            ),
          ],
        ),
        if (problem != null) ...[
          const SizedBox(height: 6),
          Text(problem, style: T.emptyBody.copyWith(color: C.red)),
        ],
      ],
    );
  }

  /// The band's colour down the left of its row, plus the gap after it.
  static const _rule = 12.0;

  /// The bound's field and its unit.
  static const _from = 84.0;

  /// The name is set in Inter, whose line runs about 2px taller than the
  /// mono the bound is typed in; this much less padding top and bottom puts
  /// the two fields on one height.
  static const _nameTrim = 1.1;

  Widget _row(int i, GradeBand b) {
    final removable = bands.length > kMinBands;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        spacing: 8,
        children: [
          // The same colour the band has on Grades and in the goal sheet.
          BandSwatch(colourOfBand(b, bands), width: _rule - 8, height: 35),
          Expanded(
            child: TextField(
              controller: _name(i, b.name),
              style: T.body,
              textInputAction: TextInputAction.done,
              decoration: fieldDecoration(hint: 'Name', dense: true).copyWith(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8 - _nameTrim,
                ),
                // Remove sits inside the name, so every row keeps the same
                // two columns. The bottom band is the floor everything else
                // stands on: it catches every mark beneath the next one up, so
                // it has no remove button.
                suffixIcon: i == 0
                    ? null
                    : Opacity(
                        opacity: removable ? 1 : .3,
                        child: Tap(
                          onTap: removable ? () => _remove(i) : null,
                          semanticLabel: 'Remove the ${b.name} band',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            // Ink, not the usual muted grey: inside the field
                            // it would otherwise read as the field's text
                            // colour, and fail contrast.
                            child: CloseGlyph(size: 16, color: C.ink),
                          ),
                        ),
                      ),
                suffixIconConstraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
              onChanged: (v) => _replace(i, b.copyWith(name: v)),
            ),
          ),
          SizedBox(
            width: _from,
            child: Row(
              spacing: 6,
              children: [
                Expanded(
                  child: NumberField(
                    controller: _min(i, b.min),
                    hint: '50',
                    dense: true,
                    semanticLabel: 'Lowest percentage for ${b.name}',
                    onChanged: (v) => _replace(i, b.copyWith(min: v ?? 0)),
                  ),
                ),
                // The unit outside the box, in ink: inside it, it was a
                // faint grey that read as a placeholder.
                ExcludeSemantics(child: Text('%', style: T.monoInput)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
