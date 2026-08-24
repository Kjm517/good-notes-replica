import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'url_strategy.dart';

/// Boots the app with every error funnel wired up first.
///
/// A release build has no console and no red screen. An exception thrown out of
/// `main` before `runApp` tears the root isolate down, so the launcher simply
/// bounces back to the home screen — from the outside that is indistinguishable
/// from a native crash, and there is nothing to report. Since startup touches
/// per-device surfaces that can each fail on a phone but not on an emulator
/// (platform channels, app storage, Play services, Firebase), the boot sequence
/// runs inside a guard that turns any such failure into a screen the user can
/// read and send back.
///
/// [bootstrap] does the async setup and returns the root widget; only errors
/// raised before the first frame replace the UI, so a stray async failure later
/// on can never blank out a running app.
Future<void> runGuarded(Future<Widget> Function() bootstrap) async {
  var started = false;

  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      configureWebUrlStrategy();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        debugPrint('Flutter error: ${details.exception}');
      };

      // Uncaught async errors from platform channels and streams land here.
      // Swallowing them keeps a background failure (a sync tick, a font fetch)
      // from being escalated by the engine.
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('Uncaught error: $error\n$stack');
        return true;
      };

      // Release builds paint a bare grey box when a widget fails to build,
      // which reads as "the app is broken". Say what happened instead.
      ErrorWidget.builder = (details) => _InlineError(details: details);

      try {
        final app = await bootstrap();
        started = true;
        runApp(app);
      } catch (error, stack) {
        debugPrint('Startup failed: $error\n$stack');
        runApp(StartupFailureApp(error: error, stack: stack));
      }
    },
    (error, stack) {
      debugPrint('Unhandled zone error: $error\n$stack');
      if (!started) {
        started = true;
        runApp(StartupFailureApp(error: error, stack: stack));
      }
    },
  );
}

/// Shown when the app could not finish starting.
///
/// Deliberately plain: no app theme, no Google Fonts, no design tokens, because
/// any of those could be what failed. Material defaults only.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({required this.error, this.stack, super.key});

  final Object error;
  final StackTrace? stack;

  String get _report => '$error\n\n$stack';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notably',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    'Notably could not start',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Something on this device failed while the app was '
                    'loading. The details below identify what.',
                  ),
                  const SizedBox(height: 20),
                  SelectableText(
                    '$error',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: _report)),
                        icon: const Icon(Icons.copy_all_outlined),
                        label: const Text('Copy details'),
                      ),
                    ],
                  ),
                  if (stack != null) ...[
                    const SizedBox(height: 20),
                    SelectableText(
                      '$stack',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Replacement for the release-mode grey error box.
///
/// Builds without Material, MediaQuery or a theme, because it has to render
/// wherever the failing widget sat in the tree.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          kReleaseMode
              ? 'Something went wrong here.'
              : 'Error: ${details.exception}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
