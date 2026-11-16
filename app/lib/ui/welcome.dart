import 'package:flutter/material.dart';

import '../bands.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';
import 'band_editor.dart';

/// The one question asked on first run: does your institution grade in letters?
///
/// Asked once, answerable either way in a tap, and reversible from Settings
/// afterwards — so saying no costs nothing. It exists because the alternative
/// is a feature nobody discovers: bands change what every grade in the app
/// looks like, and there is no natural moment later to go looking for them.
class Welcome extends StatefulWidget {
  const Welcome({super.key, required this.store});

  final AppStore store;

  @override
  State<Welcome> createState() => _WelcomeState();
}

class _WelcomeState extends State<Welcome> {
  bool _configuring = false;

  AppStore get store => widget.store;

  void _done() => store.markOnboarded();

  void _yes() {
    store.setBands(kDefaultBands);
    setState(() => _configuring = true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          // The answers sit at the foot of the screen, under the thumb, with
          // what they decide above them: the page reads top to bottom and
          // ends on the choice rather than on empty paper.
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 44, 16, 16),
                  children: [
                    const Eyebrow('Coursework'),
                    const SizedBox(height: 3),
                    Text("What's due", style: T.h1),
                    const SizedBox(height: 24),
                    _question(),
                    const SizedBox(height: 14),
                    if (_configuring) _bands() else _ladder(),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: C.rule)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  spacing: 8,
                  children: [
                    if (_configuring)
                      GhostButton(
                        label: 'Start tracking',
                        filled: true,
                        expand: true,
                        onPressed: _done,
                      )
                    else ...[
                      GhostButton(
                        label: 'Yes, set them up',
                        filled: true,
                        expand: true,
                        onPressed: _yes,
                      ),
                      GhostButton(
                        label: 'No, percentages',
                        expand: true,
                        onPressed: _done,
                      ),
                    ],
                    Text(
                      'You can change this later in Settings.',
                      style: T.body,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _question() => Surface(
    topBorder: C.mark,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('One question', color: C.ink),
        const SizedBox(height: 10),
        Text(
          'Does your university grade in letters, like Pass, '
          'Credit and Distinction?',
          style: T.title(),
        ),
        const SizedBox(height: 16),
        // Before answering, what each answer would do; after, the answer
        // itself, still changeable.
        if (_configuring) _answer() else _preview(),
      ],
    ),
  );

  Widget _bands() => Surface(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow('Your bands', color: C.ink),
        const SizedBox(height: 4),
        Text(
          'The lowest percentage that earns each. Edit any name or bound to '
          'match your handbook.',
          style: T.body,
        ),
        const SizedBox(height: 12),
        BandEditor(store: store),
      ],
    ),
  );

  /// The difference the answer makes, on one example mark.
  Widget _preview() {
    Widget line(String answer, String grade, Color colour) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        spacing: 10,
        children: [
          SizedBox(width: 30, child: Text(answer, style: T.count(C.ink))),
          Expanded(child: Text('Lab report', style: T.body)),
          Text(grade, style: T.count(colour)),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: C.field,
        border: Border.all(color: C.rule),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text('HOW A MARK OF 38/50 SHOWS', style: T.count(C.ink)),
          ),
          line('YES', 'DISTINCTION · 76%', C.ink),
          Container(height: 1, color: C.rule),
          line('NO', '76%', C.ink),
        ],
      ),
    );
  }

  /// What was answered, once it has been: the two answers as a pair with
  /// yes filled in. The other answer is a plain label, not a button; the
  /// choice is changed later in Settings, as the footer says.
  Widget _answer() => Row(
    children: [
      Expanded(
        child: Semantics(
          label: 'Letter grades, chosen',
          excludeSemantics: true,
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: C.ink,
              border: Border.all(color: C.ink, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Icon(Icons.check, size: 15, color: C.onInk),
                Text('LETTER GRADES', style: T.ghost(C.onInk)),
              ],
            ),
          ),
        ),
      ),
      Expanded(
        child: Semantics(
          label: 'Percentages, not chosen',
          excludeSemantics: true,
          child: Container(
            height: 38,
            alignment: Alignment.center,
            child: Text('PERCENTAGES', style: T.ghost(C.ink)),
          ),
        ),
      ),
    ],
  );

  /// The bands a yes starts from, so the choice is made knowing what it sets
  /// up. Every one is editable on the next step.
  Widget _ladder() {
    const bands = kDefaultBands;
    return Surface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('What yes sets up', color: C.ink),
          const SizedBox(height: 4),
          Text(
            'The usual Australian bands. Rename or move any of them next.',
            style: T.body,
          ),
          const SizedBox(height: 10),
          for (var i = bands.length - 1; i >= 0; i--)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                spacing: 10,
                children: [
                  Container(
                    width: 16,
                    height: 10,
                    color: gradeBarColour(bands[i].min, bands),
                  ),
                  Expanded(child: Text(bands[i].name, style: T.body)),
                  Text(
                    i + 1 < bands.length
                        ? '${trimBound(bands[i].min)}–'
                              '${trimBound(bands[i + 1].min - 1)}%'
                        : '${trimBound(bands[i].min)}%+',
                    style: T.count(C.ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
