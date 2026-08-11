import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import 'cover_styles.dart';

/// A single grid tile for a folder / notebook / pdf.
class DocumentCard extends StatelessWidget {
  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onLongPress,
    this.onStarTap,
  });

  final Document document;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onStarTap;

  bool get _isFolder => document.type == DocumentType.folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _isFolder
                      ? _FolderThumb(document: document)
                      : _CoverThumb(document: document),
                ),
                if (onStarTap != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.black26,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onStarTap,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            document.starred
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 18,
                            color: document.starred
                                ? Colors.amber
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            document.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            _subtitle(document),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.hintColor, fontSize: 11),
          ),
        ],
      ),
    );
  }

  static String _subtitle(Document d) {
    final when = DateFormat.MMMd().add_jm().format(d.updatedAt);
    return switch (d.type) {
      DocumentType.folder => 'Folder',
      DocumentType.notebook => when,
      DocumentType.pdf => 'PDF · $when',
    };
  }
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.document});
  final Document document;

  @override
  Widget build(BuildContext context) {
    final cover = coverStyleAt(document.coverStyle);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: cover.gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Spine.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 10,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(12)),
              ),
            ),
          ),
          if (document.type == DocumentType.pdf)
            const Positioned(
              right: 8,
              bottom: 8,
              child: Icon(Icons.picture_as_pdf_rounded,
                  color: Colors.white70, size: 20),
            ),
        ],
      ),
    );
  }
}

class _FolderThumb extends StatelessWidget {
  const _FolderThumb({required this.document});
  final Document document;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Icon(Icons.folder_rounded,
          size: 72, color: scheme.primary.withValues(alpha: 0.85)),
    );
  }
}
