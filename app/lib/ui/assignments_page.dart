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
  /// [window] stands in for the current due window, so the window menu can
  /// count what each choice would show.
  List<Assignment> _narrow(
    List<Assignment> list, {
    bool byDay = true,
    DueWindow? window,
    bool anyWindow = false,
  }) => applyFilters(
    list
        .where(
          (a) =>
              !byDay || view.selectedDue == null || a.due == view.selectedDue,
        )
        .toList(),
    query: view.query,
    window: anyWindow ? null : (window ?? view.window),
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

    // What each due window would show on the current tab, every other filter
    // as it is: the same count the tab would carry after picking it.
    int inWindow(DueWindow? w) => _narrow(
      _showSubmitted ? store.submitted : active,
      byDay: !_showSubmitted,
      window: w,
      anyWindow: w == null,
    ).where((a) => _inSubject(a, view.filter)).length;

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

    // A panel opened from the title row takes the place of the page's
    // filters: the form sits straight under the title with the list below it,
    // and closing it puts the strip and the filters back.
    final panel = view.showAdd || view.showManage;

    // The strip is the page's fixed early warning, so once anything is
    // tracked it holds its place on every tab and through every filter. With
    // nothing tracked it would chart an empty fortnight above the empty state.
    final showStrip = hasWork && !panel;

    final narrowed = view.filter != filterAll;
    final filtered =
        narrowed ||
        query.isNotEmpty ||
        view.window != null ||
        view.selectedDue != null;

    // What the list is showing, before the day filter: the strip fades every
    // bar with none of it, so a search that matches nothing does not leave
    // red bars warning about work the list has hidden.
    final inView = filtered
        ? _narrow(
            active,
            byDay: false,
          ).where((a) => _inSubject(a, view.filter)).toSet()
        : null;

    // While either panel is open the chips step aside: the manage panel lists
    // the same subjects just above, and a second copy of them under it only
    // repeats the list. Closing it brings them back, a new subject included.
    final chips = store.subjects.isNotEmpty && !panel
        ? _subjectChips(inSubject, narrowed)
        : const <Widget>[];
    final showChips = chips.isNotEmpty;
    final showWindow = hasWork && !panel;

    return PageBody(
      controller: controller,
      title: "What's due",
      // The triage counts ride in the title row rather than on a line of their
      // own. A zero says nothing, so only counts that are there make it; how
      // much is open is on the tab. A waiting update has its own line below.
      action: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          _HeaderNotes(
            lines: [
              if (overdue > 0) '$overdue overdue',
              if (thisWeek > 0) '$thisWeek due within 7 days',
            ],
          ),
          IconSquare(
            icon: view.showAdd ? Icons.close : Icons.add,
            open: view.showAdd,
            semanticLabel: view.showAdd
                ? 'Close the add panel'
                : 'Add assignment',
            onPressed: () => onView(view.copyWith(showAdd: !view.showAdd)),
          ),
        ],
      ),
      children: [
        _UpdateLine(store: store, onUpdate: onOpenSettings),

        // Straight under the + that opened it, with the strip and the filters
        // stepped aside, so the form is the first thing on the page.
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
        if (view.showManage) ...[
          ManageSubjects(store: store),
          const SizedBox(height: 12),
        ],

        if (showStrip) ...[
          HorizonStrip(
            active: active,
            // Display only: every bar keeps its count and its tap, and the
            // ones with nothing the list is showing fade.
            focus: inView?.contains,
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

        // ---- the filters: when, then which subject ----
        // The due window is one control that opens its choices; the subjects
        // follow it and wrap onto a second line rather than running off the
        // edge, so every chip is whole and the selected one is always in
        // view. A subject with nothing in the current tab steps out (the
        // selected one never does).
        if (showWindow || showChips) ...[
          Wrap(
            spacing: 4,
            runSpacing: 6,
            children: [
              if (showWindow)
                Padding(
                  // A little more air after the window than between subjects:
                  // it is a different kind of filter.
                  padding: EdgeInsets.only(right: showChips ? 4 : 0),
                  child: _WindowControl(
                    window: view.window,
                    count: inWindow,
                    onPick: (w) => onView(
                      w == null
                          ? view.copyWith(clearWindow: true, clearOpenId: true)
                          : view.copyWith(window: w, clearOpenId: true),
                    ),
                  ),
                ),
              ...chips,
            ],
          ),
          const SizedBox(height: 10),
        ],

        // ---- tabs, with the subjects link and the search on the same rule ----
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.rule)),
          ),
          child: _SearchField(
            value: view.query,
            enabled: hasWork,
            leading: Row(
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
            ),
            trailing: _manageButton(),
            onChanged: (q) =>
                onView(view.copyWith(query: q, clearOpenId: true)),
          ),
        ),

        if (view.selectedDue != null) _dayFilterBar(),

        // ---- list ----
        const SizedBox(height: 8),
        if (shown.isEmpty)
          _FillRest(child: _empty())
        else
          Column(
            spacing: 12,
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

        // The list's end, said once: that this is all of it, and for a
        // filtered or submitted list what it is and the way back to the rest.
        if (shown.isNotEmpty)
          _ListEnd(
            head: _endHead(),
            note: _footer(elsewhere: chipPool.length - shown.length),
          ),

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

  /// All, then each subject with something in the current tab, then Unfiled.
  List<Widget> _subjectChips(int Function(String) inSubject, bool narrowed) {
    // A subject with no work anywhere yet is offered too: it is new, and
    // hiding it would make adding it look like it failed.
    bool offered(String filter) =>
        view.filter == filter ||
        inSubject(filter) > 0 ||
        (filter != filterUnfiled &&
            !store.items.any((a) => a.subjectId == filter));
    final subjects = [
      for (final s in store.subjects)
        if (offered(s.id))
          _Chip(
            label: s.name,
            count: inSubject(s.id),
            dot: s.swatch,
            on: view.filter == s.id,
            onTap: () => _select(s.id),
          ),
      if (store.active.any((a) => a.subjectId == null) &&
          offered(filterUnfiled))
        _Chip(
          label: 'Unfiled',
          count: inSubject(filterUnfiled),
          on: view.filter == filterUnfiled,
          onTap: () => _select(filterUnfiled),
        ),
    ];
    return [
      // All is only a choice when there is something to choose between, or a
      // subject to get back out of. It carries no count: how many are showing
      // is on the tab, once.
      if (subjects.isNotEmpty || narrowed)
        _Chip(
          label: 'All',
          on: view.filter == filterAll,
          onTap: () => _select(filterAll),
          semanticLabel: 'Show every subject',
        ),
      ...subjects,
    ];
  }

  Widget _manageButton() => EyebrowButton(
    label: view.showManage ? 'Hide subjects' : 'Manage subjects',
    color: C.ink,
    onPressed: () => onView(view.copyWith(showManage: !view.showManage)),
  );

  String? get _subjectName => switch (view.filter) {
    filterAll => null,
    filterUnfiled => 'Unfiled',
    final id => store.subjects.where((s) => s.id == id).firstOrNull?.name,
  };

  /// The end-of-list line: this is everything the filters let through.
  String _endHead() {
    final subject = _subjectName;
    if (subject != null) return "That's everything in $subject";
    return _showSubmitted
        ? "That's everything submitted"
        : "That's everything due";
  }

  /// What a filtered or submitted list is, and the way back to all of it —
  /// the chip already on screen, named rather than duplicated. The counts
  /// are on the summary line and the tabs, so this does not repeat them.
  /// [elsewhere] is how many more the tab holds in other subjects.
  String? _footer({required int elsewhere}) {
    if (_subjectName != null) {
      final where = _showSubmitted ? 'submitted' : 'open';
      return elsewhere > 0
          ? '$elsewhere more $where in other subjects. Tap All above to see '
                'every subject.'
          : 'Tap All above to see every subject.';
    }
    if (_showSubmitted) {
      return 'Submitted work stays here. Tap a card to move it back to Open.';
    }
    return null;
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
      return EmptyState(
        icon: Icons.search_off,
        head: 'Nothing here',
        body: 'Nothing matches “$query”.',
        action: 'Clear search',
        onAction: () => onView(view.copyWith(query: '')),
      );
    }
    if (view.window != null) {
      return EmptyState(
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
    return EmptyState(
      icon: first ? Icons.checklist_outlined : Icons.inbox_outlined,
      head: head,
      body: body,
      action: first ? 'Add an assignment' : null,
      primary: true,
      onAction: () => onView(view.copyWith(showAdd: true)),
    );
  }
}

/// The end of a list that has something in it: a short rule and one quiet
/// line saying this is all of it, then, for a filtered or submitted list, the
/// sentence on what it is and the way back. Centred, like the empty state, so
/// the list closes rather than trailing off into bare paper.
class _ListEnd extends StatelessWidget {
  const _ListEnd({required this.head, this.note});

  final String head;
  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
    child: Column(
      children: [
        Container(width: 24, height: 1, color: C.ink),
        const SizedBox(height: 10),
        Text(
          head.toUpperCase(),
          style: T.count(C.ink),
          textAlign: TextAlign.center,
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(
            note!,
            // Ink, not muted: muted sans on the paper ground fails contrast.
            style: T.emptyBody.copyWith(color: C.ink),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    ),
  );
}

/// Sets [child] in whatever height is left between where it starts and the
/// bottom of the page, so an empty state sits in the middle of the free space
/// rather than hugging the filters with bare paper below it. Optically
/// centred: a little above the true middle, where a centred block reads as
/// centred rather than as sinking.
///
/// The page is one scrolling list, which gives its children no height to
/// centre in, so this measures its own offset once laid out and sizes itself
/// to the rest of the viewport. Taller content simply grows past it.
class _FillRest extends StatefulWidget {
  const _FillRest({required this.child});

  final Widget child;

  @override
  State<_FillRest> createState() => _FillRestState();
}

class _FillRestState extends State<_FillRest> {
  double _height = 0;

  /// The list's own bottom padding, which the free space does not include.
  static const _pagePadding = 32.0;

  void _measure(Duration _) {
    if (!mounted) return;
    final box = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    if (box is! RenderBox || !box.attached || scrollable == null) return;
    final viewport = scrollable.context.findRenderObject();
    if (viewport is! RenderBox) return;
    final position = scrollable.position;
    final top =
        box.localToGlobal(Offset.zero, ancestor: viewport).dy +
        position.pixels;
    final rest = position.viewportDimension - top - _pagePadding;
    final next = rest < 0 ? 0.0 : rest;
    if ((next - _height).abs() > 1) setState(() => _height = next);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_measure);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _height),
      child: Align(alignment: const Alignment(0, -0.2), child: widget.child),
    );
  }
}

/// The due-window control: the window in force as one chip, which opens the
/// same choices as a menu anchored under it, each with how many it would show.
/// Filled ink when a window is narrowing the list, like an active chip.
class _WindowControl extends StatelessWidget {
  const _WindowControl({
    required this.window,
    required this.count,
    required this.onPick,
  });

  final DueWindow? window;
  final int Function(DueWindow?) count;

  /// Null for any time.
  final ValueChanged<DueWindow?> onPick;

  static const _any = -1;

  Future<void> _open(BuildContext context) async {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(
      Offset(0, box.size.height + 4),
      ancestor: overlay,
    );
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        topLeft & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      color: C.card,
      elevation: 0,
      shape: RoundedRectangleBorder(side: BorderSide(color: C.ink, width: 1.5)),
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      constraints: const BoxConstraints(minWidth: 200),
      items: [
        _item(_any, 'Any time', 'Show work due any time', window == null),
        for (final w in DueWindow.values)
          _item(w.index, w.label, w.semanticLabel, window == w),
      ],
    );
    if (picked == null) return;
    // Picking the window already in force clears it, as tapping an active
    // chip did.
    final w = picked == _any ? null : DueWindow.values[picked];
    onPick(w == window ? null : w);
  }

  PopupMenuItem<int> _item(int value, String label, String said, bool on) {
    final n = count(value == _any ? null : DueWindow.values[value]);
    return PopupMenuItem<int>(
      value: value,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Semantics(
        label: said,
        selected: on,
        child: ExcludeSemantics(
          child: Container(
            color: on ? C.ink : null,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    style: T.chip(on ? C.onInk : C.ink),
                  ),
                ),
                Text('$n', style: T.chip(on ? C.onInk : C.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = window != null;
    final label = window?.label ?? 'Any time';
    return Builder(
      builder: (context) => Tap(
        onTap: () => _open(context),
        semanticLabel: on
            ? 'Due within ${window!.label}, change the due window'
            : 'Due any time, change the due window',
        child: Container(
          // A chip like the subject ones beside it, with the chevron that
          // says it opens rather than toggles.
          color: on ? C.ink : C.card,
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Text(label.toUpperCase(), style: T.chip(on ? C.onInk : C.ink)),
              Icon(
                Icons.expand_more,
                size: 13,
                color: on ? C.onInk : C.ink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The title row's triage counts, right-aligned against the +.
class _HeaderNotes extends StatelessWidget {
  const _HeaderNotes({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    // The title keeps its one line: on a narrow phone the counts wrap
    // instead, inside what the wordmark and the + leave over.
    final room = MediaQuery.sizeOf(context).width - 32 - 170 - 54;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: room < 80 ? 80 : room),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: 2,
        children: [
          for (final l in lines)
            Text(
              l.toUpperCase(),
              style: T.count(C.ink),
              textAlign: TextAlign.right,
            ),
        ],
      ),
    );
  }
}

/// A waiting update, on a slim line of its own under the title: a marker dot
/// and a link into Settings, where the install happens. The highlighter is
/// only the dot, so the line never competes with the + or the page's counts.
class _UpdateLine extends StatelessWidget {
  const _UpdateLine({required this.store, required this.onUpdate});

  final AppStore store;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store.updater,
    builder: (context, _) {
      final release = store.updater.release;
      if (release == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Tap(
            onTap: onUpdate,
            semanticLabel:
                'Version ${release.version} is available, tap to install',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  // The highlighter on its own vanishes against the paper,
                  // so the dot carries an ink ring.
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: C.mark,
                      shape: BoxShape.circle,
                      border: Border.all(color: C.ink),
                    ),
                  ),
                  Text(
                    'Version ${release.version} is ready'.toUpperCase(),
                    style: T.count(C.ink),
                  ),
                  Text('Update'.toUpperCase(), style: T.link),
                ],
              ),
            ),
          ),
        ),
      );
    },
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
  });

  final String label;
  final int? count;

  final bool on;
  final VoidCallback onTap;
  final Color? dot;

  /// Overrides the spoken text, for the chip that carries no count.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Tap(
    onTap: onTap,
    semanticLabel: semanticLabel ?? 'Filter by $label, $count shown',
    child: Container(
      color: on ? C.ink : C.card,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 5,
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

/// The tab rule: the tabs, then the subjects link and the list search.
///
/// Folded to a search glyph until it is used, so the tab rule has room for
/// the tabs and the subjects link; focused or holding a query it opens to the
/// rest of the rule, and the link steps aside until it folds again.
///
/// Stateful to hold its own controller: rebuilding a [TextField] with a
/// freshly constructed one on every keystroke resets the cursor to the start,
/// which makes the field unusable after the second character.
class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.value,
    required this.onChanged,
    required this.leading,
    required this.trailing,
    this.enabled = true,
  });

  /// The tabs. On the narrowest phones they scroll rather than overflow.
  final Widget leading;

  final String value;
  final ValueChanged<String> onChanged;

  /// The subjects link, shown while the search is folded.
  final Widget trailing;

  /// With nothing tracked there is nothing to search, so only the link shows.
  final bool enabled;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _controller = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  static const _folded = 34.0;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(_SearchField old) {
    super.didUpdateWidget(old);
    // Cleared from elsewhere on the page, e.g. the empty state's link.
    if (widget.value != _controller.text) _controller.text = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => _row(c.maxWidth),
  );

  Widget _row(double width) {
    final open =
        widget.enabled && (_focus.hasFocus || _controller.text.isNotEmpty);
    final link = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: widget.trailing,
    );
    // The tabs take their own width first, up to all but a sliver for the
    // link and the search; only past that do they scroll.
    Widget tabs(double max) => ConstrainedBox(
      constraints: BoxConstraints(maxWidth: max < 0 ? 0 : max),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: widget.leading,
      ),
    );
    // The tabs are the rule's point, so they keep their full width and the
    // link gives way: scaled down rather than sitting on top of a tab where
    // the room runs out (very narrow phones, large text).
    final fitLink = Expanded(
      child: Align(
        alignment: Alignment.bottomRight,
        child: FittedBox(fit: BoxFit.scaleDown, child: link),
      ),
    );
    if (!widget.enabled) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          tabs(width - 12 - 48),
          const SizedBox(width: 12),
          fitLink,
        ],
      );
    }
    // Its own semantics node, sized to the field: left to merge upwards it
    // took the whole tab rule as its bounds, and the contrast check then read
    // the paper either side of it as the text's background.
    final field = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(container: true, child: _field(open)),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (open) ...[
          // The tabs keep their own width and the field runs from them to
          // the right edge, flush with the cards below.
          tabs(width - 12 - 120),
          const SizedBox(width: 12),
          Expanded(child: field),
        ] else ...[
          tabs(width - 12 - 48 - 12 - _folded),
          const SizedBox(width: 12),
          fitLink,
          const SizedBox(width: 12),
          SizedBox(width: _folded, child: field),
        ],
      ],
    );
  }

  Widget _field(bool open) => TextField(
    controller: _controller,
    focusNode: _focus,
    style: T.input,
    textInputAction: TextInputAction.search,
    onChanged: (q) {
      widget.onChanged(q);
      setState(() {});
    },
    // No wrapping Semantics here. An ExcludeSemantics around the field takes
    // the clear button's label with it, leaving a control a screen reader
    // cannot name — the hint is what the field announces anyway, folded or
    // not, so it stays set and is only painted once there is room for it.
    decoration: fieldDecoration(hint: 'Search assignments').copyWith(
      // Unfilled, with an ink outline: part of the tab rule rather than a
      // white box on it, outlined like the app's other secondary controls,
      // and the typed text reads against the paper.
      filled: false,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: C.ink),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      hintMaxLines: 1,
      hintStyle: open ? null : T.input.copyWith(color: Colors.transparent),
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
