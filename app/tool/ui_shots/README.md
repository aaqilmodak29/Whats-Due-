# UI screenshots

Takes a screenshot of every main screen of What's due, for judging the UI and
comparing it before and after a change.

`test/ui_shots/shots_test.dart` drives the real app (`WhatsDueApp` over a real
`AppStore` on mocked shared preferences) at a phone's 430x932 logical size,
rendered at 2x so phone-sized type is legible in the PNG. It uses the same
sample data, pinned clock (6 Aug 2026) and bundled fonts as
`test/golden_test.dart`, plus the Material icon font from the SDK. It saves
one PNG per screen (`NN-name.png`) and `a11y.json`: Flutter's
`textContrastGuideline` and `labeledTapTargetGuideline`, counted per screen.

Nothing in the app is stubbed except what a test host lacks: the installed
version (package_info), the notifications plugin (answers as a phone with
permission granted and 14 reminders queued) and the update check (an update
to 1.9.9 is offered where the shot needs one).

It is tagged `ui_shots` and skipped unless `UI_SHOTS=1`, so `flutter test`
and CI's `flutter test --exclude-tags golden` never run it.

## Run

Needs Flutter 3.38.3 on PATH (or `FLUTTER_ROOT` set).

```bash
tool/ui_shots/run.sh /path/to/out
```

`style_count.sh` counts colours and font sizes written inline rather than
taken from `lib/theme.dart`.
