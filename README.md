# What's due

A coursework tracker. It answers three questions: what's overdue, what's coming
up, and what's left to do inside each assignment.

There are now two builds in this repository, and they are both first-class:

| | |
|---|---|
| [`index.html`](index.html) | The original single-file web app. Zero build step, zero dependencies. Still live on GitHub Pages, still holds real data. |
| [`app/`](app) | A Flutter port that runs as a native Windows desktop app, a native Android app, and a web build. Local storage, real scheduled notifications. |

Only source is committed. The web build is compiled and deployed by
[a GitHub Action](.github/workflows/deploy-web.yml) on push.

Nothing is hosted on a server and nothing syncs. Data lives on the device it was
entered on. See [Moving your data](#moving-your-data).

---

## Which one should I use?

Use the **native app** if you want real reminder notifications — the thing the
web version could never do (see [Reminders](#reminders)).

Keep the **web app** because it works on anything with a browser and needs no
install. It is unchanged apart from a new `EXPORT JSON` button, which is how
data gets out of it.

They are not connected. Editing in one does not change the other.

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
flutter build windows --release
```

The result is a folder, not a single file — the `.exe` needs the DLLs beside it:

```
app/build/windows/x64/runner/Release/
```

Copy that whole folder anywhere and run `whats_due.exe`. To pin it to the Start
menu, right-click the `.exe` → **Pin to Start**.

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

**The APK is signed with Flutter's debug key**, deliberately: this app is never
going near the Play Store, and a real upload key would be one more secret to
lose. The consequence is that Android shows an "unknown developer" warning on
first install, and you cannot later switch to a properly signed build without
uninstalling first — which erases the data. Export a backup before you ever do
that.

### Web

You do not build this by hand. [`.github/workflows/deploy-web.yml`](.github/workflows/deploy-web.yml)
builds it on every push to `main` and deploys both apps to GitHub Pages:

| URL | |
|---|---|
| `https://aaqilmodak29.github.io/Whats-Due-/` | The original single-file app, copied verbatim |
| `https://aaqilmodak29.github.io/Whats-Due-/flutter-web/` | The Flutter build |

**Pages must be set to deploy from GitHub Actions** — Settings → Pages → Source
→ *GitHub Actions*. Serving from a branch instead would mean committing the
build output, which is what this replaced.

The workflow runs `flutter analyze` and the test suite before it builds, so a
broken commit fails the deploy rather than publishing.

To look at a change locally first:

```bash
pwsh tools/preview-web.ps1
```

Pages caches for roughly ten minutes, so append a fresh `?v=N` after deploying
rather than clearing site data — **clearing site data would destroy the web
app's stored assignments.**

### iOS

The iOS project is present and the code is platform-correct, but **it has not
been built or tested** — that requires a Mac with Xcode. On a Mac,
`flutter build ios` should be the whole story.

---

## Reminders

This is the one real capability difference between the two builds.

A web page cannot schedule its own future notifications: the Notification
Triggers API never shipped broadly, and genuine push would mean standing up a
service worker, a push subscription and a server. So the web app exports an
`.ics` calendar file per assignment and lets the phone's own calendar deliver the
notification.

The native app does the real thing. Three notifications per dated, unsubmitted
assignment, scheduled on the device with no server and no account:

| When | |
|---|---|
| 7 days before, 09:00 | One week out |
| 2 days before, 09:00 | Two days out |
| 18:00 the evening before | Last call |

They are re-derived from scratch whenever anything changes, and re-armed after a
reboot. Turn them on under **Backup & reminders**; there is a **Send a test**
button there so the permission chain is verifiable rather than a matter of faith.

`.ics` export is kept as well, on every assignment's `REMIND ME` button. The two
are complementary: notifications live in the app, calendar events live in your
calendar and survive uninstalling the app.

On Android 13+ the OS asks permission the first time. If reminders are silently
not arriving, check the app is allowed to post notifications **and** allowed to
set alarms and reminders — they are two separate switches.

---

## Moving your data

Storage is device-local in both builds, with no sync. A backup is the only way to
move anything.

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
  ui/
    home_page.dart       header, stats, chips, tabs, list
    horizon.dart         the 14-day strip
    assignment_card.dart one assignment, collapsed and expanded
    add_panel.dart       new assignment, with inline subject creation
    edit_sheet.dart      editing title and due date
    manage_subjects.dart rename, recolour, delete
    backup_page.dart     import, export, reminder settings
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

67 tests, in four files:

| | |
|---|---|
| `test/logic_test.dart` | Date arithmetic across DST, urgency thresholds, undated sort order, `.ics` escaping and floating local time, JSON round-trips |
| `test/store_test.dart` | Loading, saving, v1 migration, and import merge/replace semantics |
| `test/ui_test.dart` | The real widget tree over seeded storage: filtering, tabs, tasks, editing, subject deletion, and a build at five viewport sizes from a 360px phone to a 2560px desktop |
| `test/golden_test.dart` | Rendered snapshots of the design |

They are aimed at the places where a plausible-looking change does real damage
rather than at coverage for its own sake.

### Goldens

`test/goldens/` holds rendered PNGs of the phone and desktop layouts. Regenerate
after an intentional design change:

```bash
cd app
flutter test --update-goldens test/golden_test.dart
```

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
