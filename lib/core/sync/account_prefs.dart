import 'dart:convert';

import '../../features/editor/state/tool_settings.dart';
import '../models/enums.dart';

/// Local [UserPrefs] row id (remote record id is the auth uid).
const String kUserPrefsRowId = 'me';

/// Soft cap for inline Supabase ink; larger pages go to R2.
const int kInkInlineMaxBytes = 900 * 1024;

/// A sticker the user added from their own PNG / GIF / WebP file.
typedef CustomSticker = ({String assetId, String name});

/// Account-scoped prefs synced through [UserPrefs] / Supabase `user_prefs`.
class AccountPrefs {
  const AccountPrefs({
    this.stickers = const [],
    this.toolSettings = const {},
  });

  final List<CustomSticker> stickers;

  /// Sparse map — missing tools fall back to [defaultToolSettings].
  final Map<ToolType, ToolSettings> toolSettings;

  Map<String, Object?> toMap() => {
        'stickers': [
          for (final s in stickers) {'a': s.assetId, 'n': s.name},
        ],
        'tools': {
          for (final e in toolSettings.entries)
            '${e.key.index}': {
              'c': e.value.color,
              'w': e.value.width,
              's': e.value.style.index,
              't': e.value.tip.index,
            },
        },
      };

  String toJson() => jsonEncode(toMap());

  factory AccountPrefs.fromJson(String raw) {
    if (raw.isEmpty) return const AccountPrefs();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AccountPrefs.fromMap(map);
    } catch (_) {
      return const AccountPrefs();
    }
  }

  factory AccountPrefs.fromMap(Map<String, dynamic> map) {
    final stickers = <CustomSticker>[];
    final rawStickers = map['stickers'];
    if (rawStickers is List) {
      for (final item in rawStickers) {
        if (item is! Map) continue;
        final assetId = item['a'] as String? ?? '';
        if (assetId.isEmpty) continue;
        stickers.add((
          assetId: assetId,
          name: item['n'] as String? ?? 'Sticker',
        ));
      }
    }

    final tools = <ToolType, ToolSettings>{};
    final rawTools = map['tools'];
    if (rawTools is Map) {
      for (final entry in rawTools.entries) {
        final index = int.tryParse('${entry.key}');
        if (index == null || index < 0 || index >= ToolType.values.length) {
          continue;
        }
        final tool = ToolType.values[index];
        final value = entry.value;
        if (value is! Map) continue;
        final defaults = defaultToolSettings()[tool];
        tools[tool] = ToolSettings(
          color: (value['c'] as num?)?.toInt() ?? defaults?.color ?? 0xFF1A1A1A,
          width: (value['w'] as num?)?.toDouble() ?? defaults?.width ?? 3,
          style: StrokeStyle.values[
              ((value['s'] as num?)?.toInt() ?? 0)
                  .clamp(0, StrokeStyle.values.length - 1)],
          tip: StrokeTip.values[
              ((value['t'] as num?)?.toInt() ?? 0)
                  .clamp(0, StrokeTip.values.length - 1)],
        );
      }
    }

    return AccountPrefs(stickers: stickers, toolSettings: tools);
  }

  AccountPrefs copyWith({
    List<CustomSticker>? stickers,
    Map<ToolType, ToolSettings>? toolSettings,
  }) =>
      AccountPrefs(
        stickers: stickers ?? this.stickers,
        toolSettings: toolSettings ?? this.toolSettings,
      );

  /// Merges sparse synced tools onto the built-in defaults.
  Map<ToolType, ToolSettings> resolvedToolSettings() {
    final out = defaultToolSettings();
    out.addAll(toolSettings);
    return out;
  }
}
