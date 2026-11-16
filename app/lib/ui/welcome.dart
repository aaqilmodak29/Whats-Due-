import 'package:flutter/material.dart';

import '../bands.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';
import 'band_colours.dart';
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

  /// One column, title to answers, centred on the screen: the answers follow
  /// straight on from what they decide, with no dead paper between the two.
  /// It scrolls when the band editor makes it taller than the screen.
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Eyebrow('Coursework'),
                  const SizedBox(height: 3),
                  Text("What's due", style: T.h1),
                  const SizedBox(height: 20),
                  _question(),
                  const SizedBox(height: 10),
                  if (_configuring) _bands() else _ladder(),
                  const SizedBox(height: 18),
                  ..._actions(),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// The answers, or once yes is answered, the one way on.
  List<Widget> _actions() => _configuring
      ? [
          GhostButton(
            label: 'Start tracking',
            filled: true,
            expand: true,
            onPressed: _done,
          ),
        ]
      : [
          GhostButton(
            label: 'Yes, set them up',
            filled: true,
            expand: true,
            onPressed: _yes,
          ),
          const SizedBox(height: 8),
          GhostButton(
            label: 'No, percentages',
            expand: true,
            onPressed: _done,
          ),
          const SizedBox(height: 10),
          Text(
            'You can change this later in Settings.',
            style: T.body,
            textAlign: TextAlign.center,
          ),
        ];

  Widget _question() => Surface(
    topBorder: C.ink,
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
    Widget line(String answer, String? band) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        spacing: 10,
        children: [
          SizedBox(width: 30, child: Text(answer, style: T.count(C.ink))),
          Expanded(child: Text('Lab report', style: T.body)),
          // The rule Grades follows: the band word in its colour, the
          // percentage plain.
          Text.rich(
            TextSpan(
              children: [
                if (band != null)
                  TextSpan(
                    text: '${band.toUpperCase()} · ',
                    style: T.count(bandColour(76, kDefaultBands)),
                  ),
                TextSpan(text: '76%', style: T.count(C.ink)),
              ],
            ),
          ),
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
          line('YES', bandFor(76, kDefaultBands)?.name),
          Container(height: 1, color: C.rule),
          line('NO', null),
        ],
      ),
    );
  }

  /// What was answered, once it has been: a statement, not a control. The
  /// choice is changed later in Settings, which the same line says.
  Widget _answer() => Semantics(
    label: 'Letter grades, chosen. You can change this later in Settings.',
    excludeSemantics: true,
    child: Row(
      spacing: 6,
      children: [
        Icon(Icons.check, size: 15, color: C.ink),
        Text('LETTER GRADES', style: T.count(C.ink)),
        Text('·', style: T.count(C.ink)),
        Expanded(
          child: Text(
            'change later in Settings',
            style: T.emptyBody.copyWith(color: C.ink),
          ),
        ),
      ],
    ),
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
                  // The same colour and the same floor Grades shows.
                  BandSwatch(colourOfBand(bands[i], bands), height: 10),
                  Expanded(child: Text(bands[i].name, style: T.body)),
                  Text(bandFloor(bands[i]), style: T.count(C.ink)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

