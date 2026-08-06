import 'package:flutter/material.dart';

import 'reminders.dart';
import 'store.dart';
import 'theme.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Notifications come up before the store, because loading the store
  // immediately schedules reminders off whatever it read.
  await Reminders.init();

  final store = AppStore();
  await store.init();

  runApp(WhatsDueApp(store: store));
}

class WhatsDueApp extends StatelessWidget {
  const WhatsDueApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: "What's due",
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    // One listenable at the root rebuilds the whole tree on any mutation. The
    // lists are tens of items, so this is imperceptible, and it keeps the web
    // app's `mutate → save → render` model intact.
    home: ListenableBuilder(
      listenable: store,
      builder: (context, _) => HomePage(store: store),
    ),
  );
}
