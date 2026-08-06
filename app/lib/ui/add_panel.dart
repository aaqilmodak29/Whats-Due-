import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import 'atoms.dart';

/// The "new assignment" panel, revealed by the + button in the header.
///
/// A subject can be created inline while adding, which is the only place the
/// web app let you mint one — keeping that flow means the common case (a new
/// unit, first assignment) is one pass rather than two.
class AddPanel extends StatefulWidget {
  const AddPanel({super.key, required this.store, required this.onCreated});

  final AppStore store;

  /// Called with the new assignment so the list can expand it.
  final ValueChanged<Assignment> onCreated;

  @override
  State<AddPanel> createState() => _AddPanelState();
}

/// Sentinel value for the "+ New subject…" option in the dropdown.
const _newSubject = '__new';

class _AddPanelState extends State<AddPanel> {
  final _title = TextEditingController();
  final _subjectName = TextEditingController();
  final _titleFocus = FocusNode();
  final _subjectFocus = FocusNode();

  String _subjectId = '';
  String _due = '';
  late String _picked = widget.store.nextColor;

  @override
  void initState() {
    super.initState();
    _titleFocus.requestFocus();
  }

  @override
  void dispose() {
    _title.dispose();
    _subjectName.dispose();
    _titleFocus.dispose();
    _subjectFocus.dispose();
    super.dispose();
  }

  void _create() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _titleFocus.requestFocus();
      return;
    }

    var subjectId = _subjectId.isEmpty ? null : _subjectId;
    if (_subjectId == _newSubject) {
      final name = _subjectName.text.trim();
      if (name.isEmpty) {
        _subjectFocus.requestFocus();
        return;
      }
      subjectId = widget.store.addSubject(name, _picked).id;
    }

    final created = widget.store.addAssignment(
      title: title,
      subjectId: subjectId,
      due: _due,
    );

    setState(() {
      _title.clear();
      _subjectName.clear();
      _due = '';
      _subjectId = subjectId ?? '';
      _picked = widget.store.nextColor;
    });
    widget.onCreated(created);
  }

  @override
  Widget build(BuildContext context) {
    final creatingSubject = _subjectId == _newSubject;

    return Surface(
      topBorder: C.mark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('New assignment'),
          const SizedBox(height: 12),
          LabelledField(
            label: 'Assignment',
            child: TextField(
              controller: _title,
              focusNode: _titleFocus,
              style: T.input,
              textInputAction: TextInputAction.done,
              decoration: fieldDecoration(hint: 'e.g. Comparative essay'),
              onSubmitted: (_) => _create(),
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final subject = LabelledField(
                label: 'Subject',
                child: SubjectDropdown<String>(
                  value: _subjectId,
                  semanticLabel: 'Subject',
                  onChanged: (v) {
                    setState(() => _subjectId = v ?? '');
                    if (v == _newSubject) _subjectFocus.requestFocus();
                  },
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Unfiled')),
                    for (final s in widget.store.subjects)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                    const DropdownMenuItem(
                      value: _newSubject,
                      child: Text('+ New subject…'),
                    ),
                  ],
                ),
              );
              final date = DateField(
                label: 'Due date',
                value: _due,
                onChanged: (v) => setState(() => _due = v),
              );
              // Narrow phones cannot fit a dropdown and a date side by side
              // without truncating subject names, so stack below ~360px.
              if (constraints.maxWidth < 360) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 10,
                  children: [subject, date],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 8,
                children: [
                  Expanded(child: subject),
                  Expanded(child: date),
                ],
              );
            },
          ),
          if (creatingSubject) ...[
            const SizedBox(height: 12),
            LabelledField(
              label: 'Name the subject',
              child: TextField(
                controller: _subjectName,
                focusNode: _subjectFocus,
                style: T.input,
                textInputAction: TextInputAction.done,
                decoration: fieldDecoration(hint: 'e.g. Organic Chemistry'),
                onSubmitted: (_) => _create(),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in kPalette)
                  Tap(
                    onTap: () => setState(() => _picked = c),
                    semanticLabel: 'Use this colour',
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: hexToColor(c),
                        border: Border.all(
                          color: c == _picked ? C.ink : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          PrimaryButton(label: 'Track it', onPressed: _create),
        ],
      ),
    );
  }
}
