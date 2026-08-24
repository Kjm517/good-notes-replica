import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/sync/sync_providers.dart';
import '../core/sync/user_telemetry.dart';
import '../core/sync/background_keep_alive.dart';
import '../features/auth/providers.dart';
import '../features/settings/paymongo_billing.dart';
import '../features/settings/revenuecat_billing.dart';
import '../features/settings/entitlements.dart';
import 'design.dart';
import 'supabase_bootstrap.dart';
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
  /// How long the session-restore splash may hold the app back.
  static const _splashTimeout = Duration(seconds: 8);

  Timer? _splashTimer;
  bool _splashExpired = false;
  bool _trialExpiredPopupShown = false;
  bool _heartbeatSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BackgroundKeepAlive.bindNative();

    // Auth restore is a network round trip on some devices and can stall on a
    // broken or offline Play services install. Falling through to the router
    // keeps a stalled restore from looking like a frozen launch — the redirect
    // re-runs by itself once the session does resolve.
    _splashTimer = Timer(_splashTimeout, () {
      if (mounted) setState(() => _splashExpired = true);
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app is the natural moment to pick up edits made on
    // another device.
    if (state == AppLifecycleState.resumed) {
      ref.read(customerInfoProvider.notifier).refresh();
      unawaited(ref.read(payMongoEntitlementRefreshProvider)());
      ref
          .read(syncEngineProvider)
          ?.scheduleSync(delay: const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watching keeps the engine alive for the app's lifetime and starts it as
    // soon as someone signs in.
    ref.watch(revenueCatSyncProvider);
    ref.watch(payMongoSyncProvider);
    ref.watch(syncEngineProvider);
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (prev, next) {
      final user = next.asData?.value;
      if (user != null) {
        unawaited(UserTelemetry.heartbeat(displayName: user.displayName));
      }
    });
    if (!_heartbeatSent) {
      final user = authState.asData?.value;
      if (user != null) {
        _heartbeatSent = true;
        unawaited(UserTelemetry.heartbeat(displayName: user.displayName));
      }
    }

    ref.listen<AsyncValue<UserEntitlement>>(entitlementProvider, (prev, next) {
      next.whenData((ent) {
        if (_trialExpiredPopupShown || !ent.trialExpired) return;
        if (supabaseReady && authState.isLoading && !_splashExpired) return;
        _trialExpiredPopupShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (Navigator.maybeOf(context) == null) return;
          unawaited(TrialExpiredDialog.show(context));
        });
      });
    });

    // Supabase restores a persisted session asynchronously, so right after
    // launch "signed out" and "not loaded yet" look identical. Hold on a quiet
    // splash until the state resolves, or a signed-in user flashes through
    // the sign-in screen on every cold start. Local-only runs skip this —
    // there's no session to restore there.
    if (supabaseReady && authState.isLoading && !_splashExpired) {
      return MaterialApp(
        title: 'Notably',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: const _SplashScreen(),
      );
    }

    return MaterialApp.router(
      title: 'Notably',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

/// Quiet brand splash shown while Supabase restores the session — the app mark
/// on the canvas colour, deliberately without a spinner.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.tokens.canvas,
      body: const Center(child: AppMark(size: 96)),
    );
  }
}
