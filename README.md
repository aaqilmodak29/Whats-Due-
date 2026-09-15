# What's due

A coursework tracker. It answers three questions: what's overdue, what's coming
up, and what's left to do inside each assignment.

A Flutter app in [`app/`](app), built for **Android**.

**Everything stays on the device.** There is no account, no server and no
network call except the one that checks GitHub for a new version. That is a
deliberate choice, not a missing feature — see
[Why there is no sync](#why-there-is-no-sync).

It started as a single-file web app served from GitHub Pages, and for a while
there was a Windows desktop build and a Firebase sync between them. Both have
been retired; the git history keeps them if they are ever wanted again.

---

## Running the native app

Everything below is run from the `app/` directory.

```bash
cd app
```

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
then builds and publishes a signed `whats-due-<tag>.apk` as a GitHub Release.

The app checks that feed on launch and offers the APK, so an update is a tap
rather than a file copied across by hand. It picks the attachment by extension
rather than taking the first one — releases published before the desktop build
was discontinued still carry a Windows zip, and the updater has to walk past
it. That selection is tested.

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

The app downloads the APK and hands it to the system installer. The first time,
Android also asks for permission to install from this app.

**Updating is not a reinstall.** An APK installed over the same package with the
same signing key is an update, and app data is preserved — no export and import
around it. Uninstalling is what wipes data.

### Other platforms

The iOS project is present and the code is platform-correct, but **it has not
been built or tested** — that requires a Mac with Xcode.

The Windows desktop build was removed. It worked, but it was the least-used
half of the app and carried the most machinery: a whole second release job, a
self-update helper that swapped a running program's own directory, and an
install script. Dropping it took all of that with it.

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
after a reboot. Turn them on under **Settings**; there is a **Send a
test** button so the permission chain is verifiable rather than a matter of
faith.

Calendar (`.ics`) export used to sit alongside this, because a web page cannot
schedule its own notifications. With the web build retired, that indirection is
gone.

On Android 13+ the OS asks permission the first time. If reminders are silently
not arriving, check the app is allowed to post notifications **and** allowed to
set alarms and reminders — they are two separate switches.

---

## Getting around

Three destinations in a bottom bar.

| | |
|---|---|
| **Assignments** | The landing page. Triage counts, the fortnight strip, search, due-date windows, subject chips, Manage subjects (add, rename, recolour, delete), and the Today / Open / Submitted tabs. |
| **Grades** | Marks totalled per subject, each opening to show the results behind the total, the goal, and what every grade band would still take. |
| **Settings** | Version, grading, appearance, reminders, export, import and erasing — one scroll. |

They can be swiped between as well as tapped. Nav taps animate rather than jump,
so the direction of travel is the same either way, and the bar follows the pager
rather than being a second source of truth.

A separate Home page existed briefly and was removed. Every block on it either
restated the list underneath it or was a door to somewhere the nav bar already
went, so it cost a tap on every launch and gave nothing back. The strip and the
update banner moved onto Assignments, which is where they were before and where
the thing they filter actually lives.

Settings was two pages behind footer links, so what was configurable was never
visible at once. It is one scroll now.

The Assignments view state — which tab, which filter, which day, which card is
open — is held by the shell rather than the page, so it survives switching tabs
and coming back.

---

## Dark mode

Toggled under **Settings → Appearance**, and remembered.

The same design after dark rather than a different one: the roles keep their
relationships, so a card still sits above the page and a rule still reads as a
hairline. Red and green are lifted, because the light values are too dense
against a dark ground. The highlighter does not move at all — it is the one
saturated accent in the design and it carries enough contrast either way.

Two token pairs exist precisely because they invert:

* `onInk` — what sits on a filled ink surface. Ink is near-white after dark, so
  reversing out to white would put white on white.
* `onMark` — what sits on the highlighter. Always the dark ink, because the
  highlighter itself never changes.

`C.ink` and friends are getters over a swappable [`Palette`](app/lib/theme.dart),
not constants. That is why almost nothing in the widget tree is `const` any
more: a `const` colour is baked in at compile time and would keep its light
value after a swap. It is global mutable state, which the rest of the codebase
avoids — the alternative was threading a palette through several hundred call
sites for a setting that changes a handful of times in the app's life.

Deliberately a plain switch rather than following the system: the app is read in
libraries and lecture theatres where the right answer often is not the phone's.

---

## Today, marks and grades

Two questions the deadline list cannot answer on its own.

**Today** gives each unsubmitted assignment a share of the day equal to what is
left on it divided by the days it has to run, then lists its next tasks up to
that share, worst-behind first. So a report due in ten days with twenty hours
left outranks a worksheet due in three days with one hour left — which a
deadline sort gets backwards.

Estimates are set from preset chips, not a free number field, because a student
guessing to the minute is inventing precision. With nothing estimated the plan
degrades to one next action per assignment, ordered by deadline: the app has to
be useful before any effort is entered, or nobody enters any. Unestimated tasks
are paced at a nominal 30 minutes so they cannot empty one assignment into a
single day, and that figure is never added to a displayed total.

Marks are set in two places. **What it is out of** goes in when you add the
assignment, because the spec already says so; **your score** goes in from the
card's **EDIT** sheet weeks later, when it comes back.

| | |
|---|---|
| **Marks** | what the assignment is marked out of |
| **Your score** | what you got, out of those marks |

A score higher than the marks available is flagged rather than refused — bonus
marks and marking errors both happen.

**Grades** totals those marks per subject: 34/40 and 8/10 become 42 out of 50.

That is deliberately **unweighted**. Weighting — what each assignment is worth
towards the subject — was removed pending a decision on how to handle it, so a
quiz out of 10 and a report out of 100 count here in proportion to their marks
rather than to what they are actually worth. The page says so rather than
implying the number is a predicted grade.

The `weight` field is still read and written by the storage layer even though
nothing uses it. Dropping it would have every device quietly discard whatever
had already been recorded against it on its next write.

### Letter grades

Percentages work everywhere and need nothing set up, so they are what the app
stores. Letters are a display layer over the same numbers.

The app asks once, on first run, whether your university or school also grades
in letters. Saying no costs nothing — it can be switched on later under
**Settings → Grading**, and switching it off again loses only the letters.

Bands are yours to name, two to six of them, pre-filled with Fail, Pass, Credit,
Distinction and High Distinction. Each band is stored as the **lowest percentage
that earns it**; the band above decides where it stops. So 65 is a Credit, not
the top of a Pass. The editor shows the ranges that implies and refuses a set
that leaves a gap under the lowest band or puts two bands on the same bound.

Once set, the letter appears beside every percentage: on the assignment card, in
the **EDIT** sheet live as you type a score, and on each subject in **Grades**.

Bands travel inside the coursework document, so a backup carries them — a
restore without them would leave every grade showing as a bare percentage.
Importing with **merge** does *not* adopt the incoming bands unless you have
none, because redefining them silently changes what every existing grade means.

### Goals

Two kinds, because courses ask for both.

**Per assignment** — a score out of that assignment's marks, set as you add it
or from the **EDIT** sheet. For anything that has to be passed in its own right.
Grades says whether it was met, and by how much it was missed.

**Per subject** — a percentage across the whole subject, set on its card in
**Grades**. A percentage rather than a band, so it works for people who never
turned letter grading on; with bands configured they are offered as shortcuts
onto the same field.

A subject goal is worth setting because of what it back-solves. Three
assignments worth 30, 30 and 40 make a subject out of 100. Aim for 85, score 20
on the first, and what you need is **65 from the remaining 70** — which is the
sentence the goal row prints. Once a goal cannot be lost it says *already
there*; once it cannot be reached it says so rather than printing a number you
cannot get.

Open a subject and **MARKS NEEDED** does the same for every band at once, in
marks rather than percentages, because marks are what you can go and earn.
Bands already banked read *Safe*.

All of it counts **only the assignments you have entered**. An assignment with a
marks total and no score yet is what is still to play for; one with no marks at
all is invisible to Grades entirely.

---

## Home-screen widget

Android only. Shows everything due in the next seven days — up to four rows,
each mirroring an Assignments card: urgency spine, subject, countdown, title,
task fraction. When the week is clear it says *"No assignments due in the next 7
days"*.

Overdue work is included even though it is not, strictly, due in the next week.
It is the most urgent thing there is, and an assignment silently disappearing
from the widget on the day it goes late would be the opposite of useful.

The selection, ordering, countdown wording and urgency colour are all decided in
Dart and handed over as flat strings; the Kotlin provider renders them and hides
empty rows. It holds no rules of its own on purpose — the widget is meant to be a
cut-down view of the Assignments list, and anything duplicated there would
eventually disagree with the list it mirrors.

Every row slot is written on every push, including the empty ones. Omitting a key
would leave the launcher rendering last week's deadline indefinitely.

The widget follows the **system's** dark mode through `values-night`, not the
app's own toggle: the launcher draws it, so it should sit against the home screen
rather than against whatever the app was last set to. The spine colours are
resolved against the light palette and read acceptably on either ground.

It refreshes on every edit. `updatePeriodMillis` is 30 minutes as a backstop so
the countdowns roll over at midnight without the app being opened; Android floors
that value at 30 minutes however low it is set.

Adding it: long-press the home screen → **Widgets** → *What's due*. It is 4×3
cells by default and resizable. Before the app has ever run it shows "Open to see
this week".

---

## Why there is no sync

There was sync, over Firebase, with email-and-password accounts. It is gone.

The app is meant to be handed to other people now, and sync was the only part
that needed an account, a server, and someone to be responsible for other
people's coursework sitting in their project. Removing it removed all three at
once. The public build no longer carries a Firebase API key, and nobody is ever
asked to create an account.

What it costs: one device, one copy. Moving between devices is an export and an
import, below.

**So keep a backup.** With nothing in the cloud, a saved `.json` is the only
copy that survives uninstalling, a wiped phone, or a lost one.

---

## Moving your data by hand

Sync makes this optional, but export/import still works and is the way to get
data out of the original web app, or to keep a copy before something risky.

**From the web app to a native app:**

1. Open the web app, scroll to the bottom, tap **Export JSON**
2. Tap **COPY**
3. In the native app: **Settings** → paste into the Import box → **MERGE**

`MERGE` keeps what is already there and adds anything new, matching subjects by
name so you don't end up with two identical chips, and skipping assignments you
already have — so importing the same backup twice does nothing. `REPLACE`
overwrites everything.

The importer also accepts the older bare-array format, so an ancient backup still
works.

**Backing up:** **Settings** → **Save .json file** or **Copy to
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

A fortnight of columns, one per day. A day with deadlines gets a filled block
whose height grows with the number due and whose colour comes from `urgency`;
empty days get a hairline. It exists so a crunch week is visible before it
arrives, and it always charts **all** subjects whatever filter is on — the
filter narrows the list, not the early warning.

**Paged, and aligned to Monday.** It used to start at today and run fourteen
days forward, so the Monday just gone was invisible, every page began on a
different weekday, and the weekend tints never landed in the same place twice.
Each page is two whole weeks now, Monday to Sunday twice; a swipe moves a full
fortnight, and a BACK TO TODAY appears once you have moved off the current one.
It reaches about seven years either way.

Days are coloured against *today*, not against the page, so a column in a
fortnight already gone still reads as overdue.

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

Grade bands live inside that document, under `bands`, and are omitted entirely
when letter grading is off — so a percentages-only file serialises exactly as it
did before bands existed, and a reader that predates them is unaffected.

Device settings are separate keys, because they describe the phone rather than
the coursework and should not ride along in a backup: `coursework:reminders`,
`coursework:dark`, and `coursework:onboarded` — the last being why restoring a
backup does not re-ask the first-run question.

Any future schema change should follow the same pattern the v1 → v2 step did: new
key, migrate forward, leave the old key in place as an accidental backup.

---

## What's new versus the web app

- **Editing an assignment's title and due date** after creation. The web app
  could reassign a subject but not change the title or the date; it was the most
  obvious gap in it.
- **Real scheduled notifications** (see above).
- **Sub-tasks**, one level under a task.
- **Marks**, with a Grades page per subject (see below).
- **Search and due-date windows** over the list.
- **Effort estimates and a Today plan**, which paces the day rather than
  listing deadlines.
- **An Android home-screen widget** (see below).
- **Dark mode** (see below).
- **Import and export**, in both builds.
- Native window, native install, no hosting dependency, no cache-busting
  `?v=N` dance.

Still not built: weighting (what each assignment is worth towards the subject),
recurring assignments, a link or attachment per assignment, archiving by term, sorting other than due-date ascending, and
bulk `.ics` export for a whole semester.

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
