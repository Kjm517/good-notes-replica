import 'package:flutter/widgets.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/models/image_element.dart';

void main() {
  group('ImageElementData', () {
    const source = Size(400, 200);

    test('defaults to the full image', () {
      const d = ImageElementData(assetId: 'a');
      final r = d.sourceRect(source);
      expect(r.left, 0);
      expect(r.top, 0);
      expect(r.width, 400);
      expect(r.height, 200);
    });

    test('crop fractions map onto source pixels', () {
      const d = ImageElementData(
        assetId: 'a',
        cropLeft: 0.25,
        cropTop: 0.5,
        cropRight: 0.75,
        cropBottom: 1,
      );
      final r = d.sourceRect(source);
      expect(r.left, 100);
      expect(r.top, 100);
      expect(r.right, 300);
      expect(r.bottom, 200);
      expect(r.width, 200);
      expect(r.height, 100);
    });

    test('cropped aspect ratio reflects the visible window', () {
      const full = ImageElementData(assetId: 'a');
      expect(full.croppedAspect(source), 2.0);
      // Half the width, full height -> 200x200 -> square.
      const half = ImageElementData(assetId: 'a', cropRight: 0.5);
      expect(half.croppedAspect(source), 1.0);
    });

    test('round-trips through JSON with the crop intact', () {
      const d = ImageElementData(
        assetId: 'asset-1',
        cropLeft: 0.1,
        cropTop: 0.2,
        cropRight: 0.8,
        cropBottom: 0.9,
        opacity: 0.5,
      );
      final restored = ImageElementData.fromJson(d.toJson());
      expect(restored, d);
      expect(restored.assetId, 'asset-1');
      expect(restored.opacity, 0.5);
    });

    test('copyWith keeps the asset id', () {
      const d = ImageElementData(assetId: 'keep-me');
      expect(d.copyWith(cropLeft: 0.3).assetId, 'keep-me');
      expect(d.copyWith(cropLeft: 0.3).cropLeft, 0.3);
    });
  });
}
