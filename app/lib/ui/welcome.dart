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
                    const SizedBox(height: 6),
                    Text('Changeable later under Settings.', style: T.note),

                    if (!_configuring) ...[
                      const SizedBox(height: 16),
                      Row(
                        spacing: 8,
                        children: [
                          Expanded(
                            child: GhostButton(
                              label: 'Yes, set them up',
                              filled: true,
                              onPressed: () {
                                store.setBands(kDefaultBands);
                                setState(() => _configuring = true);
                              },
                            ),
                          ),
                          Expanded(
                            child: GhostButton(
                              label: 'No, percentages',
                              onPressed: _done,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              if (_configuring) ...[
                const SizedBox(height: 14),
                Surface(
                  topBorder: C.ink,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Eyebrow('Your bands', color: C.ink),
                      const SizedBox(height: 4),
                      Text(
                        'The lowest percentage that earns each.',
                        style: T.note,
                      ),
                      const SizedBox(height: 10),
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
}
