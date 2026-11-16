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

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
            children: [
              const Eyebrow('Coursework'),
              const SizedBox(height: 3),
              Text("What's due", style: T.h1),
              const SizedBox(height: 18),

              Surface(
                topBorder: C.mark,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow('One question', color: C.ink),
                    const SizedBox(height: 10),
                    Text(
                      'Does your university grade in letters, like Pass, '
                      'Credit and Distinction?',
                      style: T.body,
                    ),
                    const SizedBox(height: 14),
                    if (!_configuring) ...[
                      _preview(),
                      const SizedBox(height: 16),
                      GhostButton(
                        label: 'Yes, set them up',
                        filled: true,
                        expand: true,
                        onPressed: () {
                          store.setBands(kDefaultBands);
                          setState(() => _configuring = true);
                        },
                      ),
                      const SizedBox(height: 8),
                      GhostButton(
                        label: 'No, percentages',
                        expand: true,
                        onPressed: _done,
                      ),
                    ] else
                      // The answer stays on screen once given.
                      _answer(),
                    const SizedBox(height: 12),
                    Text(
                      'You can change this later in Settings.',
                      style: T.emptyBody,
                    ),
                  ],
                ),
              ),

              if (!_configuring) ...[
                const SizedBox(height: 14),
                _ladder(),
              ],

              if (_configuring) ...[
                const SizedBox(height: 14),
                Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('Your bands', color: C.ink),
                      const SizedBox(height: 4),
                      Text(
                        'The lowest percentage that earns each. Edit any '
                        'name or bound to match your handbook.',
                        style: T.emptyBody,
                      ),
                      const SizedBox(height: 12),
                      BandEditor(store: store),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                PrimaryButton(label: 'Start tracking', onPressed: _done),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  /// The difference the answer makes, on one example mark.
  Widget _preview() {
    Widget line(String answer, String grade, Color colour) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        spacing: 10,
        children: [
          SizedBox(width: 30, child: Text(answer, style: T.count(C.muted))),
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

  /// What was answered, once it has been.
  Widget _answer() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(border: Border.all(color: C.ink, width: 1.5)),
    child: Row(
      spacing: 8,
      children: [
        Icon(Icons.check, size: 16, color: C.ink),
        Expanded(
          child: Text('YES — LETTER GRADES', style: T.ghost(C.ink)),
        ),
      ],
    ),
  );

  /// The bands a yes starts from, so the choice is made knowing what it sets
  /// up. Every one is editable on the next step.
  Widget _ladder() {
    const bands = kDefaultBands;
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('What yes sets up', color: C.ink),
          const SizedBox(height: 4),
          Text(
            'The usual Australian bands. Rename or move any of them next.',
            style: T.emptyBody,
          ),
          const SizedBox(height: 10),
          for (var i = bands.length - 1; i >= 0; i--)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                spacing: 10,
                children: [
                  Container(
                    width: 14,
                    height: 8,
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
