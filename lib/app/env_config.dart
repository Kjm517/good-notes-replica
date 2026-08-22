/// Compile-time configuration from `.env` via `--dart-define-from-file`.
///
/// Copy `.env.example` → `.env`, then run `./scripts/sync-env.sh` (or use
/// VS Code launch configs which sync automatically).
class EnvConfig {
  EnvConfig._();

  /// Cloudflare Worker URL for R2 file sync (PDFs/images).
  static const fileEndpoint = String.fromEnvironment(
    'NOTABLY_FILE_ENDPOINT',
    defaultValue: '',
  );

  /// Google Gemini API key for AI features (OCR, search, etc.).
  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static bool get hasFileSync => fileEndpoint.isNotEmpty;
  static bool get hasGemini => geminiApiKey.isNotEmpty;
}
