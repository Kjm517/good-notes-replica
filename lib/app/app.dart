import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sync/sync_providers.dart';
import 'providers.dart';
import 'router.dart';
import 'theme.dart';

class NotablyApp extends ConsumerStatefulWidget {
  const NotablyApp({super.key});

  @override
  ConsumerState<NotablyApp> createState() => _NotablyAppState();
}

class _NotablyAppState extends ConsumerState<NotablyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app is the natural moment to pick up edits made on
    // another device.
    if (state == AppLifecycleState.resumed) {
      ref.read(syncEngineProvider)?.scheduleSync(
            delay: const Duration(milliseconds: 300),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watching keeps the engine alive for the app's lifetime and starts it as
    // soon as someone signs in.
    ref.watch(syncEngineProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'Notably',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
