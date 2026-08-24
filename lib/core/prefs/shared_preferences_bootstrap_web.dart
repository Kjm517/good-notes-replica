import 'package:shared_preferences_web/shared_preferences_web.dart';

/// Web (including WASM) may not auto-register federated plugins — wire
/// [SharedPreferencesStorePlatform] to localStorage before [SharedPreferences.getInstance].
Future<void> ensureSharedPreferencesPlatform() async {
  SharedPreferencesPlugin.registerWith(null);
}
