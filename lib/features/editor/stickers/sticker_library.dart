import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../library/providers.dart';

/// A sticker the user added from their own PNG / GIF / WebP file.
///
/// The bytes live in the shared asset store (deduped by content hash), so here
/// we only keep a light reference — the asset id plus a display name — in
/// preferences. That's enough for the picker to show "your stickers" again on
/// a later launch, and it means a GIF added once can be dropped onto any page.
typedef CustomSticker = ({String assetId, String name});

/// The built-in sticker set, expressed as emoji and rendered to transparent
/// PNGs on demand (see [renderEmojiSticker]) so nothing has to be shipped as a
/// binary asset. Colour emoji come from the platform's own emoji font.
const List<String> kBuiltInStickers = [
  '⭐', '🌟', '❤️', '🔥', '✅', '❌', '❓', '❗', '💡', '📌',
  '📍', '🎯', '👍', '👏', '🙌', '🎉', '✨', '💯', '⚠️', '🏆',
  '😀', '😍', '🤔', '😎', '🥳', '😢', '🚀', '📈', '🌈', '☀️',
  '🌙', '💪', '🙏', '👀', '🧠', '📝', '🔑', '⏰', '💬', '☕',
];

/// Rasterises a single emoji glyph to a transparent square PNG at [size]px.
/// Used both to place a built-in sticker and (indirectly) to keep them out of
/// the bundle.
Future<Uint8List> renderEmojiSticker(String emoji, {int size = 256}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final painter = TextPainter(
    text: TextSpan(text: emoji, style: TextStyle(fontSize: size * 0.78)),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset((size - painter.width) / 2, (size - painter.height) / 2),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

/// The user's own stickers, persisted in SharedPreferences (most-recent first).
final stickerLibraryProvider =
    NotifierProvider<StickerLibrary, List<CustomSticker>>(StickerLibrary.new);

class StickerLibrary extends Notifier<List<CustomSticker>> {
  static const _key = 'custom_stickers';

  @override
  List<CustomSticker> build() {
    final raw = ref.watch(sharedPrefsProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          if (item is Map)
            (
              assetId: item['a'] as String? ?? '',
              name: item['n'] as String? ?? 'Sticker',
            ),
      ].where((s) => s.assetId.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist(List<CustomSticker> stickers) async {
    state = stickers;
    await ref.read(sharedPrefsProvider).setString(
          _key,
          jsonEncode([
            for (final s in stickers) {'a': s.assetId, 'n': s.name},
          ]),
        );
  }

  /// Stores [bytes] as an asset and remembers it as a reusable sticker,
  /// returning the (deduped) asset id. Re-adding the same file simply lifts the
  /// existing sticker back to the top instead of storing a second copy.
  Future<String> add(Uint8List bytes, String name) async {
    final assetId = await ref.read(assetRepositoryProvider).store(
          id: ref.read(uuidProvider).v4(),
          bytes: bytes,
          kind: 0,
          filename: name,
          mime: 'image/*',
        );
    final without = state.where((s) => s.assetId != assetId).toList();
    await _persist([(assetId: assetId, name: name), ...without]);
    return assetId;
  }

  /// Forgets a sticker. The underlying asset is left in place — it may still be
  /// referenced by stickers already placed on pages.
  Future<void> remove(String assetId) async {
    await _persist(state.where((s) => s.assetId != assetId).toList());
  }
}
