import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import 'assignments_page.dart';
import 'atoms.dart';
import 'grades_page.dart';
import 'settings_page.dart';

enum AppTab { assignments, grades, settings }

/// The three destinations, and the one Scaffold under all of them.
///
/// Assignments is the landing page. A separate Home page existed briefly and
/// was removed: every block on it either restated the list below it or was a
/// door to somewhere the nav bar already went, so it cost a tap on launch and
/// gave nothing back.
///
/// The Assignments view state lives here rather than inside that page so it
/// survives switching tabs and coming back, and so the Today tab can open the
/// card behind a planned task.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store});

  final AppStore store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.assignments;
  AssignmentsView _assignments = const AssignmentsView();

  /// One controller per destination, so each keeps its own scroll position
  /// across tab switches.
  final _controllers = {
    for (final t in AppTab.values) t: ScrollController(),
  };

  AppStore get store => widget.store;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    // IndexedStack rather than a swap: every destination stays alive, so its
    // scroll offset and any half-typed field survive a trip to another tab.
    body: IndexedStack(
      index: _tab.index,
      children: [
        AssignmentsPage(
          store: store,
          view: _assignments,
          controller: _controllers[AppTab.assignments]!,
          onView: (v) => setState(() => _assignments = v),
          onOpenSettings: () => setState(() => _tab = AppTab.settings),
        ),
        GradesPage(
          store: store,
          controller: _controllers[AppTab.grades]!,
        ),
        SettingsPage(
          store: store,
          controller: _controllers[AppTab.settings]!,
        ),
      ],
    ),
    bottomNavigationBar: _NavBar(
      current: _tab,
      onSelect: (t) => setState(() => _tab = t),
    ),
  );
}

/// The bottom bar.
///
/// Hand-built rather than Material's [NavigationBar]: that comes with rounded
/// indicator pills, a tinted surface and its own motion, all of which fight the
/// flat, square-cornered, ink-on-paper design used everywhere else.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.current, required this.onSelect});

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  static const _items = <(AppTab, IconData, String)>[
    (AppTab.assignments, Icons.checklist_outlined, 'Assignments'),
    (AppTab.grades, Icons.insights_outlined, 'Grades'),
    (AppTab.settings, Icons.settings_outlined, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: C.card,
      border: Border(top: BorderSide(color: C.rule)),
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          for (final (tab, icon, label) in _items)
            Expanded(
              child: Tap(
                onTap: () => onSelect(tab),
                semanticLabel: tab == current
                    ? '$label, current page'
                    : 'Go to $label',
                child: Container(
                  padding: const EdgeInsets.only(top: 8, bottom: 7),
                  decoration: BoxDecoration(
                    border: Border(
                      // The highlighter underline marks the active tab, the
                      // same way it marks the active chip and list tab.
                      top: BorderSide(
                        color: tab == current ? C.mark : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 21,
                        color: tab == current ? C.ink : C.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label.toUpperCase(),
                        style: T.eyebrow(tab == current ? C.ink : C.muted)
                            .copyWith(fontSize: 9),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
