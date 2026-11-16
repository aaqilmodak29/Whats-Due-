import 'package:flutter/material.dart';

import '../filters.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'add_panel.dart';
import 'assignment_card.dart';
import 'atoms.dart';
import 'horizon.dart';
import 'manage_subjects.dart';
import 'update_section.dart';

/// Filter sentinels, matching the web app's `filter` values.
const filterAll = 'all';
const filterUnfiled = 'none';

/// Which list the tab strip is showing.
enum AssignmentTab { open, submitted }

/// Everything about how the Assignments page is currently being looked at.
///
/// Held by the shell rather than by the page, so that a view of it — a day
/// picked from the horizon strip, a subject filter, a card left open — survives
/// switching destinations and coming back. Immutable, with [copyWith], to keep
/// those transitions explicit.
class AssignmentsView {
  const AssignmentsView({
    this.tab = AssignmentTab.open,
    this.filter = filterAll,
    this.selectedDue,
    this.openId,
    this.showManage = false,
    this.showAdd = false,
    this.query = '',
    this.window,
  });

  final AssignmentTab tab;
  final String filter;

  /// `YYYY-MM-DD` when a day in the horizon strip is being filtered on.
  final String? selectedDue;

  /// The expanded card, if any.
  final String? openId;

  final bool showManage;
  final bool showAdd;

  /// Free text matched against assignment titles.
  final String query;

  /// How far out to look, or null for no limit.
  final DueWindow? window;

  AssignmentsView copyWith({
    AssignmentTab? tab,
    String? filter,
    String? selectedDue,
    String? openId,
    bool? showManage,
    bool? showAdd,
    String? query,
    DueWindow? window,
    bool clearSelectedDue = false,
    bool clearOpenId = false,
    bool clearWindow = false,
  }) => AssignmentsView(
    tab: tab ?? this.tab,
    filter: filter ?? this.filter,
    selectedDue: clearSelectedDue ? null : (selectedDue ?? this.selectedDue),
    openId: clearOpenId ? null : (openId ?? this.openId),
    showManage: showManage ?? this.showManage,
    showAdd: showAdd ?? this.showAdd,
    query: query ?? this.query,
    window: clearWindow ? null : (window ?? this.window),
  );
}

/// The working surface: every assignment, filtered and grouped.
class AssignmentsPage extends StatelessWidget {
  const AssignmentsPage({
    super.key,
    required this.store,
    required this.view,
    required this.onView,
    required this.controller,
    required this.onOpenSettings,
  });

  final AppStore store;
  final AssignmentsView view;
  final ScrollController controller;
  final ValueChanged<AssignmentsView> onView;

  /// Both the update banner and the sync warning are pointers into Settings.
  final VoidCallback onOpenSettings;

  bool get _showSubmitted => view.tab == AssignmentTab.submitted;

  /// Every filter but the subject one: search, due window and, on the Open
  /// tab, the day picked on the strip. Shared by the list and every count on
  /// the page, so a number never describes something other than what shows.
  List<Assignment> _narrow(List<Assignment> list, {bool byDay = true}) =>
      applyFilters(
        list
            .where(
              (a) =>
                  !byDay ||
                  view.selectedDue == null ||
                  a.due == view.selectedDue,
            )
            .toList(),
        query: view.query,
        window: view.window,
      );

  bool _inSubject(Assignment a, String filter) => switch (filter) {
    filterAll => true,
    filterUnfiled => a.subjectId == null,
    _ => a.subjectId == filter,
  };

  @override
  Widget build(BuildContext context) {
    final active = store.active;

    // The day filter belongs to the Open list; Submitted is never narrowed by
    // it (switching tabs drops it), so its count must not be either.
    final openPool = _narrow(active);
    final submittedPool = _narrow(store.submitted, byDay: false);
    final open = openPool.where((a) => _inSubject(a, view.filter)).toList();
    final submitted = submittedPool
        .where((a) => _inSubject(a, view.filter))
        .toList();
    final shown = _showSubmitted ? submitted : open;

    // What the subject chips count: the current tab, every other filter on.
    final chipPool = _showSubmitted ? submittedPool : openPool;
    int inSubject(String filter) =>
        chipPool.where((a) => _inSubject(a, filter)).length;

    final overdue = open.where((a) {
      final n = daysUntil(a.due);
      return n != null && n < 0;
    }).length;
    final thisWeek = open.where((a) {
      final n = daysUntil(a.due);
      return n != null && n >= 0 && n <= 7;
    }).length;

    // Nothing tracked at all: search and due windows would have nothing to
    // narrow, so they stay out of the way until there is.
    final hasWork = store.items.isNotEmpty;
    final query = view.query.trim();

    // The strip earns its height by charting what is coming. With nothing
    // tracked, or a search that matched nothing, it would chart an empty
    // fortnight above an empty list, so it steps aside until there is. It
    // charts open work only, so the Submitted tab (which a tap on it would
    // leave anyway) does not carry it either.
    final showStrip =
        hasWork && !_showSubmitted && !(query.isNotEmpty && shown.isEmpty);

    // A subject filter says how much of the whole it is showing, so the ALL
    // chip's larger count reads as the total rather than a contradiction.
    final narrowed = view.filter != filterAll;

    return PageBody(
      controller: controller,
      title: "What's due",
      // On Submitted the triage counts describe a list that is not showing,
      // so the line names what is. Both follow the filters, like the tabs.
      // Nothing tracked at all: a line of zeroes would only restate the
      // empty state below it.
      eyebrow: !hasWork
          ? null
          : _showSubmitted
          ? '${submitted.length} submitted · ${open.length} open'
          : [
              if (overdue > 0) '$overdue overdue',
              '$thisWeek due within 7 days',
              narrowed
                  ? '${open.length} of ${openPool.length} open'
                  : '${open.length} open',
            ].join(' · '),
      // Ink, not red or muted: both fail contrast as 10px mono on the paper
      // ground. Urgency is carried by the cards' rails and countdowns.
      eyebrowColor: C.ink,
      action: IconSquare(
        icon: view.showAdd ? Icons.close : Icons.add,
        open: view.showAdd,
        semanticLabel: view.showAdd ? 'Close the add panel' : 'Add assignment',
        onPressed: () => onView(view.copyWith(showAdd: !view.showAdd)),
      ),
      children: [
        UpdateBanner(updater: store.updater, onTap: onOpenSettings),

        // Straight under the + that opened it, ahead of the strip and the
        // filters, so the form is the first thing on the page rather than
        // something found below a chart.
        if (view.showAdd) ...[
          AddPanel(
            store: store,
            onCreated: (created) => onView(
              view.copyWith(
                showAdd: false,
                openId: created.id,
                tab: AssignmentTab.open,
                clearSelectedDue: true,
                // Landing on a filter that excludes the new card would look
                // like the add silently failing.
                filter:
                    view.filter != filterAll &&
                        view.filter != (created.subjectId ?? filterUnfiled)
                    ? filterAll
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Back on the page it filters, so tapping a day no longer means
        // crossing a page boundary to see the result.
        if (showStrip) ...[
          HorizonStrip(
            active: active,
            selectedDue: view.selectedDue,
            onSelect: (due) => onView(
              view.copyWith(
                tab: AssignmentTab.open,
                selectedDue: due,
                clearSelectedDue: due == null,
                clearOpenId: true,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ---- filters: when, then which subject ----
        // The due windows are plain words with the active one filled. They
        // scroll rather than wrap, and all six fit a 430px phone.
        if (hasWork)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 2,
              children: [
                _Chip(
                  label: 'Any time',
                  plain: true,
                  on: view.window == null,
                  onTap: () => onView(
                    view.copyWith(clearWindow: true, clearOpenId: true),
                  ),
                  semanticLabel: 'Show work due any time',
                ),
                for (final w in DueWindow.values)
                  _Chip(
                    label: w.label,
                    plain: true,
                    on: view.window == w,
                    onTap: () => onView(
                      view.window == w
                          ? view.copyWith(clearWindow: true, clearOpenId: true)
                          : view.copyWith(window: w, clearOpenId: true),
                    ),
                    semanticLabel: w.semanticLabel,
                  ),
              ],
            ),
          ),
        // Subjects wrap rather than scroll: a scrolling row always cut its
        // last chip off mid-word at the screen edge. The way to edit them
        // closes the run, beside the chips it changes.
        if (store.subjects.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Chip(
                label: 'All',
                count: inSubject(filterAll),
                on: view.filter == filterAll,
                onTap: () => _select(filterAll),
              ),
              for (final s in store.subjects)
                _Chip(
                  label: s.name,
                  count: inSubject(s.id),
                  dot: s.swatch,
                  on: view.filter == s.id,
                  onTap: () => _select(s.id),
                ),
              if (active.any((a) => a.subjectId == null))
                _Chip(
                  label: 'Unfiled',
                  count: inSubject(filterUnfiled),
                  on: view.filter == filterUnfiled,
                  onTap: () => _select(filterUnfiled),
                ),
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _manageButton(),
              ),
            ],
          ),
        ],
        if (view.showManage) ...[
          const SizedBox(height: 10),
          ManageSubjects(store: store),
        ],

        // ---- tabs, with the search riding on the same rule ----
        SizedBox(height: hasWork || store.subjects.isNotEmpty ? 10 : 0),
        LayoutBuilder(
          builder: (context, box) {
            final search = _SearchField(
              value: view.query,
              onChanged: (q) =>
                  onView(view.copyWith(query: q, clearOpenId: true)),
            );
            // Beside the tabs where there is room for both; on a narrow phone,
            // or when the tab rule also has to carry the subjects link, it
            // takes its own line above them rather than squeeze either.
            final inline =
                hasWork && store.subjects.isNotEmpty && box.maxWidth >= 380;
            final tabs = Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 16,
              children: [
                // The counts are of what each tab would show with the current
                // filters, not of everything.
                _Tab(
                  label: 'Open (${open.length})',
                  on: view.tab == AssignmentTab.open,
                  onTap: () => _show(AssignmentTab.open),
                ),
                _Tab(
                  label: 'Submitted (${submitted.length})',
                  on: _showSubmitted,
                  onTap: () => _show(AssignmentTab.submitted),
                ),
              ],
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasWork && !inline) ...[search, const SizedBox(height: 10)],
                Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: C.rule)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (inline) ...[
                        tabs,
                        const SizedBox(width: 14),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: search,
                          ),
                        ),
                      ] else
                        // Scrolls rather than overflows on the narrowest
                        // phones; at 360px and up both tabs fit.
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: tabs,
                          ),
                        ),
                      // With no subjects there is no chip row to close, so the
                      // way to add one rides on the tab rule instead.
                      if (store.subjects.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 6),
                          child: _manageButton(),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),

        if (view.selectedDue != null) _dayFilterBar(),

        // ---- list ----
        const SizedBox(height: 10),
        if (shown.isEmpty)
          _empty()
        else
          Column(
            spacing: 8,
            children: [
              for (final a in shown)
                AssignmentCard(
                  key: ValueKey(a.id),
                  assignment: a,
                  store: store,
                  expanded: view.openId == a.id,
                  onToggleExpanded: () => onView(
                    view.openId == a.id
                        ? view.copyWith(clearOpenId: true)
                        : view.copyWith(openId: a.id),
                  ),
                ),
            ],
          ),

        // A short list otherwise ends in bare paper, which reads as one that
        // failed to load. The line under it says what it is a part of, from
        // the same counts as the tabs and chips.
        if (shown.isNotEmpty && (_showSubmitted || narrowed)) ...[
          const SizedBox(height: 14),
          Text(
            _footer(shown.length, _showSubmitted ? submittedPool : openPool),
            // Ink, not muted: muted sans on the paper ground fails contrast.
            style: T.emptyBody.copyWith(color: C.ink),
            textAlign: TextAlign.center,
          ),
        ],

        if (store.storageBlocked) ...[
          const SizedBox(height: 16),
          Text(
            'Storage is blocked here, so changes won\'t survive a restart.'
                .toUpperCase(),
            style: T.eyebrow(C.red),
          ),
        ],
      ],
    );
  }

  Widget _manageButton() => EyebrowButton(
    label: view.showManage ? 'Hide subjects' : 'Manage subjects',
    color: C.ink,
    onPressed: () => onView(view.copyWith(showManage: !view.showManage)),
  );

  /// What a filtered or submitted list is out of, and the way back to all of
  /// it — the chip already on screen, named rather than duplicated.
  String _footer(int count, List<Assignment> pool) {
    final what = _showSubmitted ? 'submitted' : 'open';
    final subject = switch (view.filter) {
      filterAll => null,
      filterUnfiled => 'Unfiled',
      final id => store.subjects.where((s) => s.id == id).firstOrNull?.name,
    };
    if (subject == null) {
      return _showSubmitted
          ? 'Submitted work stays here. Tap a card to move it back to Open.'
          : '$count $what.';
    }
    return '$count of ${pool.length} $what, $subject only. '
        'Tap All above to see every subject.';
  }

  void _select(String filter) =>
      onView(view.copyWith(filter: filter, clearOpenId: true));

  void _show(AssignmentTab tab) => onView(
    view.copyWith(
      tab: tab,
      clearOpenId: true,
      // The horizon strip only charts unsubmitted, dated work, so a day filter
      // carried into Submitted would show an empty list.
      clearSelectedDue: tab != AssignmentTab.open,
    ),
  );

  /// Shows what the strip is filtering on, and how to get out of it. Without
  /// this a tap on a bar looks like most of the list vanishing for no reason.
  Widget _dayFilterBar() {
    final count = store.active.where((a) => a.due == view.selectedDue).length;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Tap(
        onTap: () => onView(view.copyWith(clearSelectedDue: true)),
        semanticLabel: 'Clear the day filter',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: C.card,
            border: Border.all(color: C.ink),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${longDate(view.selectedDue!)} · $count due'.toUpperCase(),
                  style: T.count(C.ink),
                ),
              ),
              const SizedBox(width: 8),
              Text('SHOW ALL', style: T.ghost(C.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    final query = view.query.trim();
    if (query.isNotEmpty) {
      return _Empty(
        icon: Icons.search_off,
        head: 'Nothing here',
        body: 'Nothing matches “$query”.',
        action: 'Clear search',
        onAction: () => onView(view.copyWith(query: '')),
      );
    }
    if (view.window != null) {
      return _Empty(
        icon: Icons.event_available_outlined,
        head: 'Nothing here',
        body: 'Nothing due within ${view.window!.label.toLowerCase()}.',
        action: 'Any due date',
        onAction: () => onView(view.copyWith(clearWindow: true)),
      );
    }
    final (head, body) = switch ((
      view.selectedDue != null,
      view.filter != filterAll,
      _showSubmitted,
    )) {
      // A day filter is the most recent thing the user did, so name it first.
      (true, true, _) => (
        'Nothing here',
        'Nothing in this subject is due that day.',
      ),
      (true, false, _) => ('Nothing here', 'Nothing due that day.'),
      (false, true, _) => ('Nothing here', 'Nothing in this subject yet.'),
      (false, false, false) => (
        'Nothing tracked yet',
        'Track your first piece of coursework, then break it into tasks.',
      ),
      (false, false, true) => (
        'Nothing submitted yet',
        'Work shows up here once you mark it submitted.',
      ),
    };
    // With nothing tracked at all, the empty list is the page's whole job,
    // so it carries the way to start: the same panel the + opens.
    final first = !view.showAdd && store.items.isEmpty;
    return _Empty(
      icon: first ? Icons.checklist_outlined : Icons.inbox_outlined,
      head: head,
      body: body,
      action: first ? 'Add an assignment' : null,
      primary: true,
      onAction: () => onView(view.copyWith(showAdd: true)),
    );
  }
}

/// The "nothing here" message, with the one control that undoes whatever
/// emptied the list when there is a single obvious one. The same action as
/// the control that set it, offered where the eye already is.
///
/// Set on the page rather than in a white card: a lone box over bare paper
/// read as a list that failed to load. Unboxed, under an icon and with room
/// above it, it reads as the page saying there is nothing to show.
class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.head,
    required this.body,
    this.action,
    this.onAction,
    this.primary = false,
  });

  final IconData icon;
  final String head;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  /// Lime, for the one case where this is the page's main call to action.
  final bool primary;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
    child: Column(
      children: [
        Icon(icon, size: 40, color: C.ink),
        const SizedBox(height: 14),
        Text(head, style: T.emptyHead, textAlign: TextAlign.center),
        const SizedBox(height: 5),
        Text(
          body,
          style: T.emptyBody.copyWith(color: C.ink),
          textAlign: TextAlign.center,
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          GhostButton(label: action!, filled: primary, onPressed: onAction!),
        ],
      ],
    ),
  );
}

/// A filter chip. Off, it is a plain label on the card colour; on, it is
/// filled ink, so the active filter reads from across the room rather than by
/// a 2px underline.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.on,
    required this.onTap,
    this.count,
    this.dot,
    this.semanticLabel,
    this.plain = false,
  });

  final String label;
  final int? count;

  /// No fill when off: a word on the page rather than a chip.
  final bool plain;
  final bool on;
  final VoidCallback onTap;
  final Color? dot;

  /// Overrides the spoken text. A due window reads as `7 DAYS`, which on its
  /// own is indistinguishable from a countdown.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    semanticLabel: semanticLabel ?? 'Filter by $label, $count shown',
    child: Container(
      color: on ? C.ink : (plain ? null : C.card),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          if (dot != null) Dot(dot!),
          Text(
            [label.toUpperCase(), ?count?.toString()].join(' '),
            style: T.chip(on ? C.onInk : C.ink),
          ),
        ],
      ),
    ),
  );
}

/// CSS `.tab`.
class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    semanticLabel: label,
    child: Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: on ? C.ink : Colors.transparent, width: 2),
        ),
      ),
      child: Text(label.toUpperCase(), style: T.tab(on ? C.ink : C.muted)),
    ),
  );
}

/// The title search.
///
/// Stateful only to hold its own controller: rebuilding a [TextField] with a
/// freshly constructed one on every keystroke resets the cursor to the start,
/// which makes the field unusable after the second character.
class _SearchField extends StatefulWidget {
  const _SearchField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    // Cleared from elsewhere on the page, e.g. the empty state's button.
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    style: T.input,
    textInputAction: TextInputAction.search,
    onChanged: widget.onChanged,
    // No wrapping Semantics here. An ExcludeSemantics around the field takes
    // the clear button's label with it, leaving a control a screen reader
    // cannot name — the hint is what the field announces anyway.
    decoration: fieldDecoration(hint: 'Search assignments').copyWith(
      // Compact, to sit on the tab rule beside the tabs rather than take a
      // full-width row of its own above them.
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      hintMaxLines: 1,
      prefixIcon: Icon(Icons.search, size: 17, color: C.ink),
      prefixIconConstraints: const BoxConstraints(minWidth: 30),
      suffixIcon: _controller.text.isEmpty
          ? null
          : Tap(
              onTap: () {
                _controller.clear();
                widget.onChanged('');
                setState(() {});
              },
              semanticLabel: 'Clear the search',
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: CloseGlyph(size: 16),
              ),
            ),
      suffixIconConstraints: const BoxConstraints(minWidth: 28),
    ),
  );
}
