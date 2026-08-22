import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/design.dart';
import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/sync/sync_providers.dart';
import '../document_transfer.dart';
import '../providers.dart';
import 'cover_styles.dart';

/// A single grid tile for a folder / notebook / pdf.
///
/// The cover sits inside a bordered card rather than floating on its own
/// shadow: at four-across on a desktop the loose shadows read as visual noise,
/// and a hairline border keeps the grid calm.
class DocumentCard extends ConsumerWidget {
  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onLongPress,
    this.onStarTap,
    this.onMore,
  });

  final Document document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onStarTap;
  final VoidCallback? onMore;

  bool get _isFolder => document.type == DocumentType.folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    // Folders have no pages; only fetch a count for documents that show one.
    final pageCount = _isFolder
        ? null
        : ref.watch(documentPageCountProvider(document.id)).asData?.value;
    final pendingUpload =
        ref.watch(pendingUploadDocumentsProvider).asData?.value ?? const {};
    final missingLocal =
        ref.watch(missingLocalFileDocumentsProvider).asData?.value ?? const {};
    final paused = ref.watch(syncPausedProvider);
    final status = ref.watch(syncStatusProvider);
    final transfer = documentTransferState(
      documentId: document.id,
      pendingUpload: pendingUpload,
      missingLocal: missingLocal,
      status: status,
      paused: paused,
    );
    final locked = transfer.locked;
    final badgeLabel = transfer.badgeLabel(status);
    final transferIcon = switch (transfer.kind) {
      DocumentTransferKind.downloading => Icons.cloud_download_outlined,
      DocumentTransferKind.uploading => Icons.cloud_upload_outlined,
      DocumentTransferKind.none => null,
    };

    return Opacity(
      opacity: locked ? 0.45 : 1,
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: locked ? null : onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.card),
              border: Border.all(color: t.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _isFolder
                          ? _FolderThumb(document: document)
                          : _CoverThumb(document: document),
                      if (onStarTap != null && !locked)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _StarButton(
                            starred: document.starred,
                            onTap: onStarTap!,
                          ),
                        ),
                      if (document.type == DocumentType.pdf)
                        const Positioned(
                            left: 8, bottom: 8, child: _PdfBadge()),
                      if (badgeLabel != null)
                        ColoredBox(
                          color: locked
                              ? t.canvas.withValues(alpha: 0.35)
                              : Colors.transparent,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: t.surface.withValues(alpha: 0.92),
                                  borderRadius:
                                      BorderRadius.circular(Radii.inner),
                                  border: Border.all(color: t.line),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      transferIcon ?? Icons.cloud_outlined,
                                      size: 14,
                                      color: t.textSecondary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      badgeLabel,
                                      style: AppTokens.mono(
                                        size: 11,
                                        color: t.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              document.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: t.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              badgeLabel ?? _subtitle(document, pageCount),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTokens.mono(
                                  size: 11, color: t.textFaint),
                            ),
                          ],
                        ),
                      ),
                      if (onMore != null)
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: onMore,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.more_horiz_rounded,
                                size: 19, color: t.textFaint),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _subtitle(Document d, int? pages) {
    final when = DateFormat.MMMd().format(d.updatedAt);
    // "· N pp" once the count has loaded; omitted rather than showing "0 pp"
    // while the query is still in flight.
    final pp = (pages != null && pages > 0) ? ' · $pages pp' : '';
    return switch (d.type) {
      DocumentType.folder => 'Folder',
      DocumentType.notebook => 'Notebook$pp · $when',
      DocumentType.pdf => 'PDF$pp · $when',
    };
  }
}

/// Star toggle on the cover. Sits on a translucent chip so it stays legible
/// over both a white scan and a dark notebook cover.
class _StarButton extends StatelessWidget {
  const _StarButton({required this.starred, required this.onTap});

  final bool starred;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.white.withValues(alpha: 0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 24,
          height: 24,
          child: Icon(
            starred ? Icons.star_rounded : Icons.star_border_rounded,
            size: 15,
            color: starred ? t.star : const Color(0xFFC8CCD6),
          ),
        ),
      ),
    );
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.document});
  final Document document;

  @override
  Widget build(BuildContext context) {
    // Rendered once at import and cached on the row, so the library never
    // has to open the source PDF to draw a card.
    final encoded = document.coverThumb;
    if (encoded != null && encoded.isNotEmpty) {
      // Real first-page preview (PDF cover / imported image).
      return ColoredBox(
        color: Colors.white,
        child: Image.memory(
          base64Decode(encoded),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: 360,
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      );
    }

    // Fallback: notebook cover gradient (also shown while the thumb loads).
    final cover = coverStyleAt(document.coverStyle);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: cover.gradient),
      child: Row(
        children: [
          // The spine: a darker strip that reads as a bound notebook.
          Container(width: 10, color: Colors.black.withValues(alpha: 0.18)),
        ],
      ),
    );
  }
}

class _PdfBadge extends StatelessWidget {
  const _PdfBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: context.tokens.pdfBadge,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text('PDF',
          style: AppTokens.mono(
            size: 9.5,
            weight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.4,
          )),
    );
  }
}

class _FolderThumb extends StatelessWidget {
  const _FolderThumb({required this.document});
  final Document document;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ColoredBox(
      color: t.fill,
      child: Center(
        child: Icon(Icons.folder_rounded,
            size: 60, color: t.accent.withValues(alpha: 0.55)),
      ),
    );
  }
}
