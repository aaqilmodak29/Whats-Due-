import 'package:flutter/material.dart';

import '../models.dart';
import '../planner.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';

/// What to work on now, rather than what is due when.
///
/// The rest of the app answers "what's due"; this answers the question a
/// student actually opens the app with. It is a view over the same tasks — no
/// separate list, nothing to keep in sync — so ticking something here is the
/// same edit as ticking it on its card.
class TodayView extends StatelessWidget {
  const TodayView({super.key, required this.store, required this.onOpen});

  final AppStore store;

  /// Jumps to an assignment's card, for when the next action is not enough
  /// context and the whole brief is wanted.
  final ValueChanged<Assignment> onOpen;

  @override
  Widget build(BuildContext context) {
    final plan = todayPlan(store.items);
    if (plan.isEmpty) return _empty(plan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _headline(plan),
        const SizedBox(height: 10),
        Column(
          spacing: 9,
          children: [
            for (final p in plan.tasks) _row(context, p),
          ],
        ),
        if (plan.undated > 0) ...[
          const SizedBox(height: 12),
          Text(
            '${plan.undated} unfinished ${plan.undated == 1 ? 'assignment has' : 'assignments have'} '
                    'no due date, so ${plan.undated == 1 ? 'it is' : 'they are'} not paced here.'
                .toUpperCase(),
            style: T.eyebrow(),
          ),
        ],
      ],
    );
  }

  /// The day's total, and how much of it is guesswork.
  ///
  /// The unestimated count is never folded into the total: quietly padding it
  /// with assumed minutes would make the figure look precise while being made
  /// up, and a plan you cannot trust is worse than no plan.
  Widget _headline(DayPlan plan) {
    final estimated = plan.estimatedMinutes > 0;
    final head = estimated
        ? 'About ${formatMinutes(plan.estimatedMinutes)} today'
        : '${plan.tasks.length} ${plan.tasks.length == 1 ? 'thing' : 'things'} to pick up';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
      decoration: BoxDecoration(
        color: C.card,
        border: Border(top: BorderSide(color: C.mark, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Today'),
          const SizedBox(height: 4),
          Text(head, style: T.title()),
          const SizedBox(height: 6),
          Text(
            plan.unestimated == 0
                ? 'Spread from what is left on each assignment and the days it '
                      'has to run.'
                : '${plan.unestimated} of these ${plan.unestimated == 1 ? 'has' : 'have'} no '
                      'estimate yet, so the real total is higher. Open a task '
                      'to set one.',
            style: T.emptyBody,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, PlannedTask p) {
    final a = p.assignment;
    final n = daysUntil(a.due);
    final subject = store.subjectOf(a);

    return Container(
      decoration: BoxDecoration(
        color: C.card,
        border: Border(left: BorderSide(color: urgency(n), width: 6)),
        boxShadow: const [
          BoxShadow(color: Color(0x1A16202E), offset: Offset(0, 1)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      child: Row(
        spacing: 10,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: CheckBoxSquare(
              done: false,
              onTap: () => p.subtask == null
                  ? store.toggleTask(a, p.task)
                  : store.toggleSubtask(p.subtask!),
            ),
          ),
          Expanded(
            child: Tap(
              onTap: () => onOpen(a),
              semanticLabel:
                  '${p.label}, from ${a.title}, ${countdown(n).toLowerCase()}'
                  '${p.minutes == null ? '' : ', ${formatMinutes(p.minutes!)}'}'
                  ', tap to open the assignment',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.label, style: T.task(done: false)),
                  const SizedBox(height: 4),
                  Row(
                    spacing: 6,
                    children: [
                      if (subject != null) Dot(subject.swatch, size: 6),
                      Flexible(
                        child: Text(
                          // The task alone is not enough context: "Draft the
                          // abstract" could belong to any of four units.
                          p.subtask == null
                              ? a.title.toUpperCase()
                              : '${p.task.text} · ${a.title}'.toUpperCase(),
                          style: T.eyebrow(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(countdown(n), style: T.count(urgency(n))),
              if (p.minutes != null) ...[
                const SizedBox(height: 3),
                Text(formatMinutes(p.minutes!), style: T.frac),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty(DayPlan plan) {
    final (head, body) = plan.undated > 0
        ? (
            'Nothing to pace',
            'The work you have left has no due date, so there is nothing to '
                'spread across today. Add dates and it will show up here.',
          )
        : store.active.isEmpty
        ? (
            'Nothing on',
            'No open assignments. Add one and today\'s plan builds itself from '
                'its tasks.',
          )
        : (
            'No tasks yet',
            'Your open assignments have no tasks to work on. Break one down '
                'and the next step shows up here.',
          );

    return Container(
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
}
