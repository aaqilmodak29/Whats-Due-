import 'dart:async';

import 'package:flutter/material.dart';

import 'reminders.dart';
import 'store.dart';
import 'theme.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Notifications come up before the store, because loading the store
  // immediately schedules reminders off whatever it read.
  await Reminders.init();

  final store = AppStore();
  await store.init();

  // Reminders default to on, so nobody ever touches the switch — and the switch
  // was the only thing that asked for permission. On Android 13+ that meant
  // POST_NOTIFICATIONS was never requested, scheduling succeeded, and not one
  // notification was ever shown. Ask on launch instead, when they are enabled.
  if (store.remindersEnabled) {
    unawaited(Reminders.requestPermission());
  }

  runApp(WhatsDueApp(store: store));
}

class WhatsDueApp extends StatefulWidget {
  const WhatsDueApp({super.key, required this.store});

  final AppStore store;

  @override
  State<WhatsDueApp> createState() => _WhatsDueAppState();
}

class _WhatsDueAppState extends State<WhatsDueApp> {
  @override
  void initState() {
    super.initState();
    // Quietly, so a flaky connection at startup says nothing rather than
    // greeting you with an error you did not ask for.
    widget.store.updater.check();
  }

  @override
  Widget build(BuildContext context) =>
      // One listenable at the root rebuilds the whole tree on any mutation. The
      // lists are tens of items, so this is imperceptible, and it keeps the web
      // app's `mutate → save → render` model intact.
      //
      // The MaterialApp is inside the builder, not outside it: `buildTheme()`
      // reads the palette in force, so a theme built once would keep its
      // original colours after a swap.
      ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => MaterialApp(
          title: "What's due",
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          home: AppShell(store: widget.store),
        ),
      );
}
