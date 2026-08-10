# What's due

A coursework tracker. It answers three questions: what's overdue, what's coming
up, and what's left to do inside each assignment.

A Flutter app in [`app/`](app), built for **Windows desktop and Android**. Both
share one list through Firebase — see [Sync](#sync) and
[`SYNC-SETUP.md`](SYNC-SETUP.md). Without a Firebase project configured the app
is local-only and still fully usable.

It started as a single-file web app served from GitHub Pages. That has been
retired: the desktop and phone builds do everything it did and can fire real
notifications, which a web page fundamentally cannot. The original `index.html`
remains in the git history if it is ever wanted.

---

## Running the native app

Everything below is run from the `app/` directory.

```bash
cd app
```

### Windows desktop

⚠️ **One-time setup:** Flutter needs Windows **Developer Mode** enabled before it
can build any project that uses plugins — it creates symlinks, which otherwise
requires administrator rights on every build. Open **Settings → System → For
developers** and turn on **Developer Mode**, or run:

```bash
start ms-settings:developers
```

Then:

```bash
flutter run -d windows
```

To produce a distributable build:

```bash
flutter build windows --release --dart-define-from-file=../.env
```

The result is a folder, not a single file — the `.exe` needs the DLLs beside it:

```
app/build/windows/x64/runner/Release/
```

### Installing it

**Copy that folder out of `build/` before running it.** The installed copy lives
at `%LOCALAPPDATA%\WhatsDue` — the conventional per-user location on Windows,
and one that needs no administrator rights:

```powershell
$dest = "$env:LOCALAPPDATA\WhatsDue"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item app\build\windows\x64\runner\Release\* $dest -Recurse -Force
```

Run `whats_due.exe` from there, and right-click → **Pin to Start**.

Running it in place from `build/` appears to work and then quietly doesn't. That
directory is disposable: `flutter clean` deletes it, every rebuild overwrites it,
and it is gitignored — so moving the project leaves the app behind. Not
hypothetical: the app was installed there, updated itself to 1.0.5 in place, and
disappeared when the repository was moved, because `app/build` was not part of
what moved.

A copy outside the repository is independent of all that, and it is what the
in-app updater then swaps when a new version arrives.

### Android

```bash
flutter build apk --release --split-per-abi
```

That writes one APK per CPU architecture. **For any phone from the last several
years you want the `arm64-v8a` one:**

```
app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk    (~18 MB)
app/build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk  (~15 MB, older 32-bit phones)
app/build/app/outputs/flutter-apk/app-x86_64-release.apk       (~19 MB, emulators)
```

Dropping `--split-per-abi` produces a single `app-release.apk` that works
everywhere but is ~49 MB, since it carries all three.

Get it onto the phone by whichever route you prefer — USB copy, Google Drive,
emailing it to yourself. On the phone, tap the APK and allow installing from
that source when prompted.

To run it while plugged in over USB with debugging on:

```bash
flutter run -d android
```

Release builds are signed with `android-release.keystore` (gitignored; see
[Releases and updates](#releases-and-updates)). Android still shows an "unknown
developer" warning on first install, since the key is self-signed rather than
Play-issued.

### Releases and updates

Tag a version and CI does the rest:

```bash
git tag v1.1.0 && git push origin v1.1.0
```

[`release.yml`](.github/workflows/release.yml) runs analyze and the test suite,
then builds both platforms and publishes them as a GitHub Release:

| Asset | |
|---|---|
| `whats-due-<tag>.apk` | signed, built on Linux |
| `whats-due-<tag>-windows.zip` | the Release folder's contents, built on a Windows runner |

The Windows job runs after the Android one rather than beside it, so the two
uploads cannot race to create the same release.

Each app checks that feed on launch and offers whichever asset it can actually
install, so a change no longer means copying anything anywhere by hand. Picking
the first attachment instead of the matching one would have the desktop download
an APK it can do nothing with, which is why that selection is tested.

Two things must line up or the update will not install, and both are handled by
that workflow:

* **The signing key must match.** Android refuses an update signed by a
  different key. Flutter's default debug key is generated per machine, so a CI
  build and a local build would produce APKs that cannot replace each other.
  Signing uses `android-release.keystore`, which is gitignored and mirrored into
  CI as a secret.
* **`versionCode` must increase**, so the build number comes from the CI run
  number rather than `pubspec.yaml`.

**Back up `android-release.keystore` and its password.** Losing them means never
being able to ship an update that installs over an existing one — the only way
back is uninstalling, which erases local data.

Both platforms update themselves. Android hands the APK to the system installer;
Windows unpacks the zip and hands the swap to a PowerShell helper, because a
process cannot overwrite its own executable while it is running. The app closes
and reopens on the new version — the close is expected, not a crash.

The helper waits for the app to exit, copies the current install aside, replaces
it, verifies the executable is there, and relaunches. On any failure it restores
the backup and starts the old version instead, so the worst case is the previous
version coming back rather than a half-written directory. Backups land in
`%TEMP%\whats-due-backup-<timestamp>` and can be deleted once an update sticks.

Everything it does is written to `%TEMP%\whats-due-update.log`. Read that first
if an update does not complete — the first version of the helper logged nothing,
and a silent failure was indistinguishable from a crash.

It swaps whichever directory the running `.exe` lives in, which is the other
reason to install outside `build/`.

### iOS

The iOS project is present and the code is platform-correct, but **it has not
been built or tested** — that requires a Mac with Xcode. On a Mac,
`flutter build ios` should be the whole story.

---

## Reminders

Six notifications per dated, unsubmitted assignment, scheduled on the device
with no server and no account. Deadlines are assumed to fall at 23:59, which is
what submission portals almost always use — that is why the last reminder is at
21:00 and every earlier one at 09:00, landing at the start of a day rather than
the end.

For a deadline of **15 October**:

| Fires | |
|---|---|
| 1 Oct 09:00 | two weeks out |
| 8 Oct 09:00 | one week out |
| 12 Oct 09:00 | three days out |
| 14 Oct 09:00 | the day before |
| 15 Oct 09:00 | the morning of |
| 15 Oct 21:00 | roughly three hours out |

**Assignments due at the same moment become one notification**, not several.
That matters most in the week it is least wanted: five deadlines on one day
would otherwise mean five toasts at 09:00. A lone reminder keeps a specific
headline; a group sharing one milestone reads "3 assignments due tomorrow"; a
mixed group lists each with its own urgency, soonest first.

Milestones already past are skipped rather than fired late, so adding something
due in two days schedules three reminders, not six.

The schedule lives in [`reminder_schedule.dart`](app/lib/reminder_schedule.dart)
as a pure function over assignments and a clock, so it is tested directly rather
than through the notification plugin.

Reminders are re-derived from scratch whenever anything changes, and re-armed
after a reboot. Turn them on under **Backup & reminders**; there is a **Send a
test** button so the permission chain is verifiable rather than a matter of
faith.

Calendar (`.ics`) export used to sit alongside this, because a web page cannot
schedule its own notifications. With the web build retired, that indirection is
gone.

On Android 13+ the OS asks permission the first time. If reminders are silently
not arriving, check the app is allowed to post notifications **and** allowed to
set alarms and reminders — they are two separate switches.

On Windows the notification plugin registers an AppUserModelID in the registry
on first run, so toasts work for the unpackaged build without a Start Menu
shortcut. Its MSIX caveat applies only to querying and cancelling
*already-shown* notifications, not to scheduling.

---

## Sync

Both builds of `app/` share one list through Firebase. Setup is a one-time
five-minute job in the Firebase console — see [`SYNC-SETUP.md`](SYNC-SETUP.md).

**The whole list is one document, newest wins.** Not per-item merging. For one
user with tens of items the entire `{subjects, items}` blob is a few kilobytes,
and treating it as one unit buys a large simplification: a deletion is just an
item absent from a newer document, so there are no tombstones, no per-item
timestamps, and no merge algorithm to get subtly wrong.

The cost, stated plainly: edit on two devices without a sync in between and one
side's edits lose. That case is **detected, not silently resolved** — the app
stops, shows both sides with item counts and edit times, and asks which to keep.

It pushes a few seconds after a change (debounced, so ticking six checkboxes is
one write) and pulls on launch and on foreground. The footer link doubles as the
status indicator.

### Why REST and not the FlutterFire plugins

`cloud_firestore` supports Windows, but its Windows implementation pulls in the
Firebase C++ SDK. This project had already lost a Windows build to a missing ATL
header from a far smaller native plugin, and whole-document sync needs exactly
two operations — read a document, write a document. Firestore's offline cache and
real-time listeners are the main reasons to take the native SDK, and the local
store already *is* the offline cache.

So sync is the Firestore and Firebase Auth REST APIs over `http`: no native
dependencies, one identical code path on Windows and Android, no
`google-services.json`, no `flutterfire configure`, and no C++ SDK to break a
desktop build.

Sign-in is email/password rather than Google Sign-In because the account has to
work on Windows, and `google_sign_in` has no Windows implementation.

The project ID and web API key in [`app/lib/sync/firebase_config.dart`](app/lib/sync/firebase_config.dart)
are **public identifiers, not secrets** — a Firebase web API key ships in the
JavaScript of every Firebase web app. Access control lives entirely in
[`firestore.rules`](firestore.rules), which allows a signed-in user to touch
exactly one document, their own.

## Moving your data by hand

Sync makes this optional, but export/import still works and is the way to get
data out of the original web app, or to keep a copy before something risky.

**From the web app to a native app:**

1. Open the web app, scroll to the bottom, tap **Export JSON**
2. Tap **COPY**
3. In the native app: **Backup & reminders** → paste into the Import box → **MERGE**

`MERGE` keeps what is already there and adds anything new, matching subjects by
name so you don't end up with two identical chips, and skipping assignments you
already have — so importing the same backup twice does nothing. `REPLACE`
overwrites everything.

The importer also accepts the older bare-array format, so an ancient backup still
works.

**Backing up:** **Backup & reminders** → **Save .json file** or **Copy to
clipboard**. Worth doing before uninstalling anything, and before switching
phones. Uninstalling the app erases its data.

---

## Architecture

The Flutter port is a deliberate port, not a rewrite. The decisions that were
load-bearing in the web app are load-bearing here, and several are documented in
the code where someone is most likely to try to "simplify" them.

```
app/lib/
  main.dart              entry point; one listenable at the root
  theme.dart             colour and type tokens
  models.dart            Subject, Assignment, Task; date arithmetic
  store.dart             load, save, migrate, import, export
  reminders.dart         scheduled local notifications
  ics.dart               calendar export
  sync/
    firebase_config.dart project id and API key (public identifiers)
    auth.dart            Firebase Auth over REST; email/password
    remote_store.dart    reads and writes the one Firestore document
    sync_engine.dart     pull, compare, push, conflict detection
  ui/
    home_page.dart       header, stats, chips, tabs, list
    horizon.dart         the 14-day strip
    assignment_card.dart one assignment, collapsed and expanded
    add_panel.dart       new assignment, with inline subject creation
    edit_sheet.dart      editing title and due date
    manage_subjects.dart rename, recolour, delete
    backup_page.dart     import, export, reminder settings
    sync_page.dart       sign-in, sync status, conflict resolution
    atoms.dart           shared widgets
```

### Render model

One `ChangeNotifier` at the root. Every mutation is `mutate → save → notify`, and
the whole tree rebuilds. No diffing, no per-widget state, no reactive layer. The
lists are tens of items, so a full rebuild is imperceptible, and it removes an
entire category of state-sync bugs. This mirrors the web app's single `render()`
function on purpose. Don't introduce a state-management framework to "fix" it.

### Dates are strings

`due` is a `String` in `YYYY-MM-DD` form, never a `DateTime`. Parsing
`"2026-08-19"` as a date yields UTC midnight, which shifts the day backwards for
anyone behind UTC — visible year-round in Melbourne (UTC+10/11). Every comparison
is a string sort or explicit component parsing.

`daysUntil` rounds rather than truncating, because a day either side of a
daylight-saving boundary is 23 or 25 hours long and truncation would report the
wrong day. There is a test that walks 400 consecutive days to hold this.

### Two colour channels, two meanings

The easiest thing in this UI to accidentally break:

- **The left spine of a card encodes urgency** — red at ≤2 days, ink at ≤6, muted
  beyond, green when submitted.
- **The dot beside the subject name encodes which subject.**

They must never be merged. Colouring the spine by subject would destroy
at-a-glance triage, which is the app's entire reason to exist.

Urgency thresholds live in exactly one function, `urgency()` in `models.dart`.

### The horizon strip

14 columns for the next 14 days. A day with deadlines gets a block whose height
grows with the number due and whose colour comes from `urgency()`; empty days get
a hairline. It exists so a crunch week is visible before it arrives.

It always shows **all** subjects, whatever filter is active. That is deliberate:
the filter narrows the list, not the early warning.

### Type

Two families, sharply separated by role: **sans** (Inter) for titles and task
text, **mono** (IBM Plex Mono) for every piece of data and every label. The
mono-for-data convention is what makes it read like a timetable rather than a
to-do app.

Both are bundled as assets rather than resolved from the system. The web app
could lean on `Helvetica Neue` and `SF Mono` being present on one specific phone;
a build that has to look identical on Windows, Android and the web cannot.

### Storage

`shared_preferences`, under the key `coursework:v2` — the same key and the same
JSON shape the web app writes, which is what makes a backup from one importable
into the other. Deleting a subject unfiles its assignments rather than cascading
a delete: losing a subject should never lose work.

Any future schema change should follow the same pattern the v1 → v2 step did: new
key, migrate forward, leave the old key in place as an accidental backup.

---

## What's new versus the web app

- **Editing an assignment's title and due date** after creation. The web app
  could reassign a subject but not change the title or the date; it was the most
  obvious gap in it.
- **Real scheduled notifications** (see above).
- **Import and export**, in both builds.
- Native window, native install, no hosting dependency, no cache-busting
  `?v=N` dance.

Still not built, in either: grade weighting, effort estimates, recurring
assignments, sync, search, sorting other than due-date ascending, and bulk
`.ics` export for a whole semester.

---

## Development

```bash
cd app
flutter analyze
```

```bash
cd app
flutter test
```

144 tests. CI runs everything except the goldens:

```bash
cd app
flutter test --exclude-tags golden
```

| | |
|---|---|
| `logic_test.dart` | Date arithmetic across DST, urgency thresholds, undated sort order, JSON round-trips |
| `store_test.dart` | Loading, saving, v1 migration, import merge/replace semantics |
| `sync_test.dart` | Payload format, adopting a remote copy — that deletions propagate, that a corrupt payload cannot destroy local work, and that a pulled copy is never mistaken for a local edit |
| `reminder_schedule_test.dart` | The six milestones, month and leap-year rollover, past milestones skipped, grouping and headline wording |
| `reminders_permission_test.dart` | That permission is requested *before* scheduling. Scheduling without it succeeds and shows nothing, so there is no error to catch |
| `manifest_test.dart` | Android permissions and receivers, which only take effect in a built APK and had already broken the app without failing a single test |
| `updater_test.dart` | Version comparison, release-note summarising, and picking the build for this platform rather than the first attachment |
| `windows_update_test.dart` | The generated update script: ordering, quoting, and restoring the backup on failure |
| `ui_test.dart` | The real widget tree over seeded storage, and a build at five viewport sizes from a 360px phone to a 2560px desktop |
| `golden_test.dart`, `update_golden_test.dart` | Rendered snapshots of the design |

They are aimed at the places where a plausible-looking change does real damage
rather than at coverage for its own sake. Several exist because the bug they
guard shipped once already, and the comment above each says which.

### Goldens

`test/goldens/` holds rendered PNGs of the phone and desktop layouts. Regenerate
after an intentional design change:

```bash
cd app
flutter test --update-goldens --tags golden
```

Goldens are selected by tag rather than by filename. CI excludes them the same
way, with `--exclude-tags golden`, because listing every *other* file by hand had
already silently left two new test files out of CI — one of them the guard for a
bug that was live at the time.

Font rasterisation differs between platforms, so these were captured on Windows
and will show diffs if regenerated elsewhere. Treat a diff as "open the image and
look", not automatically as a failure.

The golden test loads the bundled fonts and the SDK icon font explicitly. Without
that, a widget test renders every glyph in a fallback font and the snapshot can't
distinguish a working glyph from a missing one — which is exactly how the one
real font bug here was found: neither Inter nor IBM Plex Mono covers U+2715
(`✕`), so every close and delete button was a missing-glyph box. They are
Material icons now.

Toolchain used: Flutter 3.38.3 stable, Visual Studio Build Tools 2022 for
Windows, Android SDK 36.
