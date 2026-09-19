import 'package:flutter/material.dart';

import '../bands.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';

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

  @override
  Widget build(BuildContext context) => Surface(
    topBorder: C.ink,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Tap(
          onTap: () => setState(() => _open = !_open),
          semanticLabel:
              'Grading, $_state, tap to ${_open ? 'collapse' : 'expand'}',
          child: Row(
            spacing: 6,
            children: [
              Expanded(child: Eyebrow('Grading', color: C.ink)),
              // Only while shut: open, the row below says the same thing.
              if (!_open) Text(_state, style: T.eyebrow(C.muted)),
              Icon(
                _open ? Icons.expand_less : Icons.expand_more,
                size: 16,
                color: C.rule,
              ),
            ],
          ),
        ),

        if (_open) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text(_state, style: T.count(C.ink))),
              Semantics(
                // container: true, or the label merges into the Switch's own
                // node and never reaches the semantics tree as its own entry.
                container: true,
                label: 'Letter grades',
                toggled: store.usesLetterGrades,
                child: Switch(
                  value: store.usesLetterGrades,
                  activeThumbColor: C.onMark,
                  activeTrackColor: C.mark,
                  onChanged: (on) =>
                      store.setBands(on ? kDefaultBands : const []),
                ),
              ),
            ],
          ),
          if (store.usesLetterGrades) BandEditor(store: store),
        ],
      ],
    ),
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
        for (var i = 0; i < bands.length; i++) _row(i, bands[i]),
        const SizedBox(height: 10),
        Row(
          spacing: 8,
          children: [
            if (bands.length < kMaxBands)
              GhostButton(label: 'Add a band', onPressed: _add),
            GhostButton(
              label: 'Reset',
              onPressed: () {
                store.setBands(kDefaultBands);
                _forget();
              },
            ),
          ],
        ),
        if (problem != null) ...[
          const SizedBox(height: 8),
          Text(problem, style: T.note.copyWith(color: C.red)),
        ] else ...[
          const SizedBox(height: 8),
          Text(_ranges(), style: T.note),
        ],
      ],
    );
  }

  /// Spells the bounds back out as the ranges they imply, because that is how
  /// a handbook states them and how the bounds are easiest to check.
  String _ranges() {
    final parts = <String>[];
    for (var i = 0; i < bands.length; i++) {
      final upper = i + 1 < bands.length ? bands[i + 1].min : null;
      parts.add(
        upper == null
            ? '${bands[i].name} ${trimBound(bands[i].min)}+'
            : '${bands[i].name} ${trimBound(bands[i].min)}–'
                  '${trimBound(upper - 1)}',
      );
    }
    return parts.join(' · ');
  }

  Widget _row(int i, GradeBand b) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      spacing: 8,
      children: [
        Expanded(
          child: TextField(
            controller: _name(i, b.name),
            style: T.body,
            textInputAction: TextInputAction.done,
            decoration: fieldDecoration(hint: 'Name'),
            onChanged: (v) => _replace(i, b.copyWith(name: v)),
          ),
        ),
        SizedBox(
          width: 86,
          child: NumberField(
            controller: _min(i, b.min),
            suffix: '%',
            hint: '50',
            semanticLabel: 'Lowest percentage for ${b.name}',
            onChanged: (v) => _replace(i, b.copyWith(min: v ?? 0)),
          ),
        ),
        Opacity(
          opacity: bands.length > kMinBands ? 1 : .3,
          child: Tap(
            onTap: bands.length > kMinBands ? () => _remove(i) : null,
            semanticLabel: 'Remove the ${b.name} band',
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: CloseGlyph(size: 16),
            ),
          ),
        ),
      ],
    ),
  );
}
