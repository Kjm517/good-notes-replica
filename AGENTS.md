# Notably — GoodNotes-style note-taking app

Cross-platform (Android/iOS/web) note-taking app built with **Flutter**, replicating GoodNotes. The owner is adding one custom feature: **adjustable / extendable page margins** — the codebase is structured so that is an additive change, not a rewrite.

## Stack
- **Flutter** (Material 3), **Riverpod** for state, **go_router** for navigation.
- **drift** (SQLite) for local persistence; binary assets on disk via `path_provider`.
- **perfect_freehand** for pressure-variable ink geometry, rendered via `CustomPainter`.
- Planned: `pdfx` (PDF), `google_mlkit_digital_ink_recognition` (OCR search), Neon (Postgres) sync behind a thin REST API.

## Commands
- Run (Chrome, loads `.env`): `./scripts/run-chrome.sh` or `./scripts/run-chrome.ps1`
- Run: `flutter run -d <device>` (Android device/emulator recommended for stylus).
- Analyze: `flutter analyze`
- Tests: `flutter test test/core_logic_test.dart test/widget_test.dart`
  - Note: DB-backed widget tests are NOT run under `flutter test` — `sqlite3_flutter_libs` (native) isn't available there and unsettled spinners hang `pumpAndSettle`. Keep tests either pure-Dart or DB-injected.
- Web: use the Chrome script above so `--dart-define-from-file=.dart_defines.json` is always passed. `sqlite3.wasm` + `drift_worker.js` live in `web/`.

## Architecture (feature-first)
```
lib/
  app/         theme, router, root providers (database, prefs, theme mode)
  core/
    db/        drift tables + AppDatabase (+ generated database.g.dart)
    ink/       InkStroke model (+ Float32 point packing)
    models/    enums, MarginSpec (the custom-feature seam), page geometry
  features/
    library/   shelf, folders, notebooks, trash, search, cover styles
    editor/
      canvas/  PageCanvas (pan/zoom + draw/erase), ink painters
      ink/     StrokeRenderer (perfect_freehand -> Path)
      pages/   PaperPainter (templates + margin guides)
      state/   EditorController (Notifier: tools, undo/redo, persistence)
      widgets/ toolbar, page settings + margins sheet, thumbnails drawer
    settings/  theme mode
```

## Key conventions / gotchas
- Drift row classes are renamed to avoid Flutter clashes: table `NotePages` -> row `NotePage` (vs Flutter's `Page`); table `CanvasElements` -> row `CanvasElement` (vs Flutter's `Element`).
- After editing `lib/core/db/tables.dart` or `database.dart`, regenerate: `dart run build_runner build`.
- Generated `database.g.dart` is `part of database.dart`, so any type it references (enums, `MarginSpec`, `MarginSpecConverter`) must be imported into `database.dart` itself.
- Do NOT import `package:drift/native.dart` in app code — it pulls in `dart:ffi` and breaks the web build. Tests inject `NativeDatabase.memory()` via the `AppDatabase([executor])` constructor.
- **MarginSpec** (`core/models/margin_spec.dart`) is the extension point for the adjustable-margins feature: it's per-page (stored on `NotePages.marginSpec` as JSON), rendered by `PaperPainter`, and edited via `PageSettingsSheet` -> `EditorController.setMargins`.
- Ink model: strokes store points as packed little-endian Float32 triples (x, y, pressure). Per-page in-memory strokes live in `EditorController`; undo/redo is per-page.

## Milestones
M0 scaffold ✓ · M1 library ✓ · M2 editor/paper/pages/margins (core done) · M3 ink engine (core done) · M4 selection & shapes · M5 text & images · M6 PDF · M7 export/share · M8 OCR search · M9 Neon sync · M10 settings/polish · M11 adjustable-margins feature handoff.
