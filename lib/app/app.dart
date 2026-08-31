import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notification_providers.dart';
import '../core/sync/sync_providers.dart';
import '../core/sync/user_telemetry.dart';
import '../core/sync/background_keep_alive.dart';
import '../features/auth/providers.dart';
import '../features/settings/paymongo_billing.dart';
import '../features/settings/premium_providers.dart';
import '../features/settings/revenuecat_billing.dart';
import '../features/settings/entitlements.dart';
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
  bool _nativeSplashRemoved = false;

  StreamSubscription<Uri>? _billingLinkSub;
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BackgroundKeepAlive.bindNative();
    if (!kIsWeb) _initBillingDeepLink();

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
    unawaited(_billingLinkSub?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Listens for `io.supabase.notably://billing-callback/` — the app returns
  /// here after a PayMongo checkout opened in the system browser.
  ///
  /// The link itself carries no payment claim; it is only a signal to go
  /// re-ask the worker (which re-asks PayMongo) what actually happened. Both
  /// the cold-start link (app was closed while paying) and the live stream
  /// (app was merely backgrounded) are covered.
  void _initBillingDeepLink() {
    final appLinks = AppLinks();

    appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleBillingLink(uri);
    });

    _billingLinkSub = appLinks.uriLinkStream.listen(
      _handleBillingLink,
      onError: (Object e) => debugPrint('Billing deep link error: $e'),
    );
  }

  void _handleBillingLink(Uri uri) {
    if (uri.host != 'billing-callback') return;
    unawaited(_settleBillingReturn());
  }

  Future<void> _settleBillingReturn() async {
    await ref.read(payMongoEntitlementRefreshProvider)();
    if (!mounted) return;
    final router = ref.read(routerProvider);
    final isPremium = ref.read(payMongoPremiumActiveProvider);
    router.go('/settings');
    final messenger = _scaffoldMessengerKey.currentState;
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          isPremium
              ? 'Payment received — Premium is active.'
              : 'Back in Notably — checking your payment…',
        ),
      ),
    );
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
    ref.watch(pushRegistrationProvider);
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

    // Supabase restores a persisted session asynchronously. Keep the *native*
    // launch screen (notably_logo_splash) covering the UI until that finishes —
    // do not paint a second Flutter splash on top of it (that looked like two
    // launch screens). Local-only builds have nothing to wait for.
    final holdSplash = supabaseReady && authState.isLoading && !_splashExpired;
    if (!holdSplash && !_nativeSplashRemoved) {
      _nativeSplashRemoved = true;
      // After this frame so the router is already under the splash.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FlutterNativeSplash.remove();
      });
    }

    return MaterialApp.router(
      title: 'Notably',
      scaffoldMessengerKey: _scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
      // Black under the native splash so a mid-handoff frame never flashes white.
      builder: (context, child) {
        if (!holdSplash) return child ?? const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF000000)),
            if (child != null) Opacity(opacity: 0, child: child),
          ],
        );
      },
    );
  }
}
