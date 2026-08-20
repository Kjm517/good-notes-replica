import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const kNetworkErrorTitle = 'Network error';

const kNoWifiOrMobileData =
    'No Wi-Fi or mobile data. Connect to generate a new quiz.';

/// True when Wi-Fi, mobile data, ethernet, or VPN is up.
///
/// Captive-portal Wi-Fi still looks online; quiz generation treats Gemini
/// network failures as offline too.
bool hasNetworkInterface(List<ConnectivityResult> results) =>
    results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn ||
        r == ConnectivityResult.other);

/// Live check — do not trust a cached "online" while the first snapshot loads.
Future<bool> isOnlineNow() async {
  final results = await Connectivity().checkConnectivity();
  return hasNetworkInterface(results);
}

/// True when [error] looks like a missing or broken internet path.
bool isNetworkError(Object error) {
  final raw = error.toString().toLowerCase();
  if (raw.contains('http 4') || raw.contains('http 5')) return false;
  return raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection refused') ||
      raw.contains('connection reset') ||
      raw.contains('connection timed out') ||
      raw.contains('clientexception') ||
      raw.contains('xmlhttprequest') ||
      raw.contains('failed to fetch') ||
      raw.contains('network error') ||
      raw.contains('os error') ||
      raw.contains('software caused connection abort') ||
      (raw.contains('unavailable') && raw.contains('unable to resolve'));
}

/// Quiz generation uses the same network-failure heuristic.
bool isQuizNetworkError(Object error) => isNetworkError(error);

/// Whether a network interface is up. Optimistic `true` until the first read.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield hasNetworkInterface(await connectivity.checkConnectivity());
  await for (final results in connectivity.onConnectivityChanged) {
    yield hasNetworkInterface(results);
  }
});
