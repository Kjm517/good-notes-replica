import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/models/enums.dart';
import 'package:notably/core/sync/account_prefs.dart';
import 'package:notably/features/editor/state/tool_settings.dart';

void main() {
  test('AccountPrefs round-trips stickers and tool settings', () {
    final prefs = AccountPrefs(
      stickers: const [(assetId: 'a1', name: 'Heart')],
      toolSettings: {
        ToolType.pen: const ToolSettings(color: 0xFF112233, width: 4.5),
      },
    );
    final restored = AccountPrefs.fromJson(prefs.toJson());
    expect(restored.stickers.single.assetId, 'a1');
    expect(restored.stickers.single.name, 'Heart');
    expect(restored.toolSettings[ToolType.pen]?.color, 0xFF112233);
    expect(restored.toolSettings[ToolType.pen]?.width, 4.5);
    expect(restored.resolvedToolSettings()[ToolType.highlighter], isNotNull);
  });
}
