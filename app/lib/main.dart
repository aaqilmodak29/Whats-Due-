import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reminders.dart';
import 'store.dart';
import 'sync/sync_engine.dart';
import 'theme.dart';
import 'ui/home_page.dart';

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

  // Sync is attached after the store has loaded, so the first pull compares
  // against real local state rather than an empty one. If no Firebase project is
  // configured the engine reports itself disabled and the app is local-only.
  final prefs = await SharedPreferences.getInstance();
  store.sync = SyncEngine(
    prefs: prefs,
    readLocal: store.payloadJson,
    writeLocal: store.adoptRemote,
    countItems: store.countItemsIn,
  );

  runApp(WhatsDueApp(store: store));
}

class WhatsDueApp extends StatefulWidget {
  const WhatsDueApp({super.key, required this.store});

  final AppStore store;

  @override
  State<WhatsDueApp> createState() => _WhatsDueAppState();
}

class _WhatsDueAppState extends State<WhatsDueApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pull on launch, so a device picks up whatever the others did while it was
    // closed before the user starts editing.
    widget.store.sync?.syncNow();
    // Quietly, so a flaky connection at startup says nothing rather than
    // greeting you with an error you did not ask for.
    widget.store.updater.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the foreground is the moment a stale copy is most likely,
    // and the cheapest point to catch it.
    if (state == AppLifecycleState.resumed) {
      widget.store.sync?.syncNow();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: "What's due",
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    // One listenable at the root rebuilds the whole tree on any mutation. The
    // lists are tens of items, so this is imperceptible, and it keeps the web
    // app's `mutate → save → render` model intact.
    home: ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => HomePage(store: widget.store),
    ),
  );
}
