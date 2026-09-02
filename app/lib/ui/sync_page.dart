import 'package:flutter/material.dart';

import '../store.dart';
import '../sync/sync_engine.dart';
import '../theme.dart';
import 'atoms.dart';

/// Sign-in, sync status, and conflict resolution.
class SyncSection extends StatefulWidget {
  const SyncSection({super.key, required this.store});

  final AppStore store;

  @override
  State<SyncSection> createState() => _SyncSectionState();
}

class _SyncSectionState extends State<SyncSection> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;

  SyncEngine? get sync => widget.store.sync;

  @override
  void initState() {
    super.initState();
    _email.text = sync?.email ?? '';
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final engine = sync;
    if (engine == null) return;
    if (_email.text.trim().isEmpty || _password.text.isEmpty) return;
    setState(() => _busy = true);
    await engine.signIn(
      _email.text,
      _password.text,
      signUp: _signUp,
    );
    if (!mounted) return;
    _password.clear();
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final engine = sync;

    // Keeps its own listenable: the engine reports progress and failures
    // outside the store's mutate-save-notify cycle, so the surrounding page
    // does not rebuild when a push finishes.
    return ListenableBuilder(
      listenable: engine ?? Listenable.merge([]),
      builder: (context, _) => Column(
        children: [
          if (engine == null || !engine.isConfigured)
            _notConfigured()
          else if (engine.status == SyncStatus.conflict)
            _conflictPanel(engine)
          else if (!engine.isSignedIn)
            _signInPanel(engine)
          else
            _signedInPanel(engine),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- not set up

  Widget _notConfigured() => _Section(
    accent: C.rule,
    title: 'Not configured',
    children: [
      Text(
        'This build has no Firebase project attached, so sync is switched off '
        'and the app works entirely on this device. Export and import still '
        'move data by hand.\n\n'
        'See SYNC-SETUP.md in the repository for the five-minute setup.',
        style: T.note,
      ),
    ],
  );

  // ---------------------------------------------------------------- signed in

  Widget _signedInPanel(SyncEngine engine) {
    final last = engine.lastSyncedAt;
    final (label, colour) = switch (engine.status) {
      SyncStatus.syncing => ('SYNCING…', C.ink),
      SyncStatus.error => ('SYNC FAILED', C.red),
      _ when engine.hasPendingChanges => ('CHANGES PENDING', C.ink),
      _ => ('UP TO DATE', C.green),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(
          accent: engine.status == SyncStatus.error ? C.red : C.mark,
          title: 'Status',
          children: [
            Text(label, style: T.count(colour)),
            const SizedBox(height: 8),
            Text(
              'Signed in as ${engine.email}\n'
              'This device is "${engine.deviceId}"\n'
              '${last == null ? 'Never synced yet' : 'Last synced ${_ago(last)}'}',
              style: T.note,
            ),
            if (engine.message != null) ...[
              const SizedBox(height: 8),
              Text(
                engine.message!,
                style: T.note.copyWith(
                  color: engine.status == SyncStatus.error ? C.red : C.muted,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GhostButton(
                  label: 'Sync now',
                  filled: engine.hasPendingChanges,
                  onPressed: engine.status == SyncStatus.syncing
                      ? () {}
                      : () => engine.syncNow(),
                ),
                GhostButton(
                  label: 'Sign out',
                  onPressed: () => engine.signOut(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Section(
          accent: C.ink,
          title: 'How it works',
          children: [
            Text(
              'The whole list syncs as one document, newest wins. It pushes a '
              'few seconds after you change something, and pulls when the app '
              'starts or comes back to the foreground.\n\n'
              'Editing on two devices without a sync in between is the one case '
              'this cannot merge. It will stop and ask you which to keep rather '
              'than quietly discarding either.',
              style: T.note,
            ),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------------------- signed out

  Widget _signInPanel(SyncEngine engine) => _Section(
    accent: C.mark,
    title: _signUp ? 'Create an account' : 'Sign in',
    children: [
      Text(
        _signUp
            ? 'Make an account once, then sign in with it on your phone, your '
                  'desktop and the web build. All three then share one list.'
            : 'Sign in with the same account on every device to share one list.',
        style: T.note,
      ),
      const SizedBox(height: 12),
      LabelledField(
        label: 'Email',
        child: TextField(
          controller: _email,
          style: T.input,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: fieldDecoration(hint: 'you@example.com'),
        ),
      ),
      const SizedBox(height: 12),
      LabelledField(
        label: 'Password',
        child: TextField(
          controller: _password,
          style: T.input,
          obscureText: true,
          decoration: fieldDecoration(hint: 'At least 6 characters'),
          onSubmitted: (_) => _submit(),
        ),
      ),
      if (engine.message != null) ...[
        const SizedBox(height: 10),
        Text(engine.message!, style: T.note.copyWith(color: C.red)),
      ],
      const SizedBox(height: 14),
      PrimaryButton(
        label: _busy
            ? 'Working…'
            : _signUp
            ? 'Create account'
            : 'Sign in',
        onPressed: _busy ? null : _submit,
      ),
      const SizedBox(height: 10),
      Center(
        child: EyebrowButton(
          label: _signUp
              ? 'Already have an account? Sign in'
              : 'No account yet? Create one',
          onPressed: () => setState(() => _signUp = !_signUp),
        ),
      ),
    ],
  );

  // ----------------------------------------------------------------- conflict

  Widget _conflictPanel(SyncEngine engine) {
    final c = engine.conflict!;
    return _Section(
      accent: C.red,
      title: 'Both copies changed',
      children: [
        Text(
          'This device and another one were both edited since the last sync, so '
          'keeping one means losing the other\'s changes. Nothing has been '
          'overwritten yet — pick which to keep.',
          style: T.note,
        ),
        const SizedBox(height: 14),
        _side(
          title: 'THIS DEVICE (${engine.deviceId})',
          detail:
              '${c.localItems} assignment${c.localItems == 1 ? '' : 's'}\n'
              'edited ${_ago(c.localUpdatedAt)}',
        ),
        const SizedBox(height: 10),
        _side(
          title: 'OTHER DEVICE (${c.remoteDeviceId})',
          detail:
              '${c.remoteItems} assignment${c.remoteItems == 1 ? '' : 's'}\n'
              'edited ${_ago(c.remoteUpdatedAt)}',
        ),
        const SizedBox(height: 16),
        Text(
          'Save a backup from the Backup screen first if you would rather not '
          'lose either.',
          style: T.note,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            GhostButton(
              label: 'Keep this device',
              filled: true,
              onPressed: () => engine.resolveKeepLocal(),
            ),
            GhostButton(
              label: 'Take the other',
              onPressed: () => engine.resolveTakeRemote(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _side({required String title, required String detail}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(border: Border.all(color: C.rule)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(title, color: C.ink),
        const SizedBox(height: 5),
        Text(detail, style: T.note),
      ],
    ),
  );

  String _ago(DateTime when) {
    final d = DateTime.now().difference(when);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) {
      return '${d.inMinutes} minute${d.inMinutes == 1 ? '' : 's'} ago';
    }
    if (d.inHours < 24) {
      return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
    }
    return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    required this.accent,
  });

  final String title;
  final List<Widget> children;
  final Color accent;

  @override
  Widget build(BuildContext context) => Surface(
    topBorder: accent,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(title, color: C.ink),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}
