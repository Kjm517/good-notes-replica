/// Turns a rendered page into the pixel buffer [findFigureRegions] works on.
///
/// Kept apart from the finder so the arithmetic stays testable without a
/// device: `dart:ui` needs a binding, a plain `Uint8List` does not.
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// Width the page is examined at.
///
/// Finding *where* a picture is needs shape rather than fine detail, but not
/// too little of it: on a textbook page a figure occupies a quarter of the
/// sheet, so at 240px it is only ~60px across and the edge count that decides
/// "drawing or flat panel" is measured on a blur. 400 keeps that judgement
/// honest and still decodes quickly enough to run over hundreds of pages.
const int kFigureScanWidth = 400;

class ScannedPage {
  const ScannedPage({
    required this.rgba,
    required this.width,
    required this.height,
  });

  final Uint8List rgba;
  final int width;
  final int height;
}

/// Reads [image] as raw RGBA, downscaling first when it is large.
Future<ScannedPage?> scanPage(ui.Image image) async {
  ui.Image? scaled;
  try {
    final source = image.width > kFigureScanWidth
        ? (scaled = await _downscale(image, kFigureScanWidth))
        : image;
    final data = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    return ScannedPage(
      rgba: data.buffer.asUint8List(),
      width: source.width,
      height: source.height,
    );
  } catch (e) {
    debugPrint('Could not scan page for figures: $e');
    return null;
  } finally {
    scaled?.dispose();
  }
}

Future<ui.Image> _downscale(ui.Image image, int targetWidth) async {
  final height = (image.height * targetWidth / image.width).round().clamp(1, 4096);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(targetWidth, height);
  } finally {
    picture.dispose();
  }
}

/// Cuts [region] out of a rendered page as PNG bytes.
///
/// This is the "extract the image" step: the figure becomes an asset in its
/// own right, which is what lets it be hashed, cached, sent to a vision model
/// on its own, and shown to the student. Sending the whole page instead costs
/// several times as much for a picture that occupies a fifth of it.
///
/// [maxSide] keeps the payload small. A vision model reads a diagram fine at
/// this size, and every pixel past it is money.
Future<Uint8List?> cropFigureBytes(
  ui.Image page,
  ({double x, double y, double w, double h}) region, {
  int maxSide = 768,
}) async {
  final srcLeft = (region.x * page.width).clamp(0.0, page.width.toDouble());
  final srcTop = (region.y * page.height).clamp(0.0, page.height.toDouble());
  final srcWidth =
      (region.w * page.width).clamp(1.0, page.width - srcLeft);
  final srcHeight =
      (region.h * page.height).clamp(1.0, page.height - srcTop);

  final scale = srcWidth > srcHeight
      ? maxSide / srcWidth
      : maxSide / srcHeight;
  final outWidth = (srcWidth * math.min(scale, 1.0)).round().clamp(1, maxSide);
  final outHeight = (srcHeight * math.min(scale, 1.0)).round().clamp(1, maxSide);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // White underneath: a PDF page is paper, and a transparent crop turns black
  // in most viewers and confuses a vision model about what it is looking at.
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  canvas.drawImageRect(
    page,
    ui.Rect.fromLTWH(srcLeft, srcTop, srcWidth, srcHeight),
    ui.Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final picture = recorder.endRecording();
  ui.Image? cropped;
  try {
    cropped = await picture.toImage(outWidth, outHeight);
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } catch (e) {
    debugPrint('Could not crop figure: $e');
    return null;
  } finally {
    picture.dispose();
    cropped?.dispose();
  }
}
