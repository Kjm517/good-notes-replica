import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/db/database.dart';
import '../../../core/platform/save_file.dart';
import '../export/export_service.dart';
import '../providers.dart';

/// Which pages to include in an export.
enum ExportRange { allPages, currentPage }

/// Export / print panel: PDF or PNG, all pages or just this one.
class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({
    super.key,
    required this.documentId,
    required this.title,
    required this.sizeFor,
  });

  final String documentId;
  final String title;
  final Size Function(NotePage) sizeFor;

  static Future<void> show(
    BuildContext context, {
    required String documentId,
    required String title,
    required Size Function(NotePage) sizeFor,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExportSheet(
        documentId: documentId,
        title: title,
        sizeFor: sizeFor,
      ),
    );
  }

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  ExportRange _range = ExportRange.allPages;
  bool _busy = false;
  double _progress = 0;
  String _status = '';

  List<NotePage> _pagesToExport() {
    final state = ref.read(editorControllerProvider(widget.documentId));
    if (_range == ExportRange.currentPage) {
      final page = state.currentPage;
      return page == null ? const [] : [page];
    }
    return state.pages;
  }

  Future<Uint8List?> _buildPdf() async {
    final service = ExportService(ref.read(pageBackgroundServiceProvider));
    final strokeRepo = ref.read(strokeRepositoryProvider);
    final pages = _pagesToExport();
    if (pages.isEmpty) return null;
    return service.buildPdf(
      pages: pages,
      sizeFor: widget.sizeFor,
      strokesFor: strokeRepo.getStrokes,
      onProgress: (f, label) {
        if (mounted) setState(() { _progress = f; _status = label; });
      },
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() { _busy = true; _progress = 0; _status = 'Preparing…'; });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _safeName =>
      widget.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim().isEmpty
          ? 'notably'
          : widget.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim();

  /// True on iOS/Android, where a file saved to app-private storage would be
  /// invisible to the user — the share sheet is the only useful destination.
  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<void> _exportPdf() => _run(() async {
        final bytes = await _buildPdf();
        if (bytes == null) return;
        if (_isMobile) {
          await Printing.sharePdf(bytes: bytes, filename: '$_safeName.pdf');
          if (mounted) Navigator.of(context).pop();
          return;
        }
        final where = await saveBytes(bytes, '$_safeName.pdf', 'application/pdf');
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Saved $where')));
        }
      });

  Future<void> _exportPng() => _run(() async {
        final service = ExportService(ref.read(pageBackgroundServiceProvider));
        final strokeRepo = ref.read(strokeRepositoryProvider);
        final pages = _pagesToExport();
        for (var i = 0; i < pages.length; i++) {
          final page = pages[i];
          final png = await service.renderPage(
            page: page,
            baseSize: widget.sizeFor(page),
            strokes: await strokeRepo.getStrokes(page.id),
          );
          if (png == null) continue;
          await saveBytes(png, '$_safeName-page${i + 1}.png', 'image/png');
          if (mounted) {
            setState(() {
              _progress = (i + 1) / pages.length;
              _status = 'Saved page ${i + 1} of ${pages.length}';
            });
          }
        }
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Exported ${pages.length} image(s)')));
        }
      });

  Future<void> _print() => _run(() async {
        final bytes = await _buildPdf();
        if (bytes == null) return;
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: _safeName,
        );
        if (mounted) Navigator.of(context).pop();
      });

  Future<void> _share() => _run(() async {
        final bytes = await _buildPdf();
        if (bytes == null) return;
        await Printing.sharePdf(bytes: bytes, filename: '$_safeName.pdf');
        if (mounted) Navigator.of(context).pop();
      });

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorControllerProvider(widget.documentId));
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Export & Print',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Annotations are flattened into the output.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).hintColor),
          ),
          const SizedBox(height: 16),
          SegmentedButton<ExportRange>(
            segments: [
              const ButtonSegment(
                value: ExportRange.currentPage,
                icon: Icon(Icons.insert_drive_file_outlined, size: 16),
                label: Text('This page'),
              ),
              ButtonSegment(
                value: ExportRange.allPages,
                icon: const Icon(Icons.collections_bookmark_outlined, size: 16),
                label: Text('All ${state.pages.length}'),
              ),
            ],
            selected: {_range},
            onSelectionChanged:
                _busy ? null : (s) => setState(() => _range = s.first),
          ),
          if (_range == ExportRange.allPages && state.pages.length > 200)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Heads up: ${state.pages.length} pages will take a while and '
                'produce a large file.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ),
          const SizedBox(height: 16),
          if (_busy) ...[
            LinearProgressIndicator(
              value: _progress <= 0 ? null : _progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: Text(_isMobile ? 'Export as PDF (share)' : 'Export as PDF'),
              subtitle: _isMobile
                  ? const Text('Opens the share sheet so you can pick a target')
                  : null,
              onTap: _exportPdf,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined),
              title: const Text('Export as image (PNG)'),
              onTap: _exportPng,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.print_rounded),
              title: const Text('Print'),
              onTap: _print,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.ios_share_rounded),
              title: const Text('Share'),
              onTap: _share,
            ),
          ],
        ],
      ),
    );
  }
}
