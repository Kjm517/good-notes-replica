import 'package:flutter/material.dart';

import '../../../app/design.dart';

/// What the user picked in the create sheet.
enum CreateAction { notebook, folder, importPdf, importImages, scan }

/// The "Create" bottom sheet.
///
/// Returns the chosen [CreateAction] and does nothing else — the caller owns
/// the work, so this stays a pure presentation widget that both the phone FAB
/// and the desktop "New" button can share.
class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key});

  static Future<CreateAction?> show(BuildContext context) {
    final desktop =
        MediaQuery.sizeOf(context).width >= AppBreakpoints.librarySidebar;
    if (desktop) {
      return showDialog<CreateAction>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.sheet),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: const CreateSheet(),
          ),
        ),
      );
    }
    return showModalBottomSheet<CreateAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => const CreateSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              'Create',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 19),
            ),
          ),
          const SizedBox(height: 4),
          _Tile(
            icon: Icons.menu_book_rounded,
            iconColor: t.accentText,
            iconBackground: t.accentSoft,
            title: 'New notebook',
            subtitle: 'Blank pages, your template',
            action: CreateAction.notebook,
          ),
          _Tile(
            icon: Icons.create_new_folder_rounded,
            iconColor: t.textSecondary,
            iconBackground: t.fill,
            title: 'New folder',
            subtitle: 'Group documents together',
            action: CreateAction.folder,
          ),
          _Tile(
            icon: Icons.picture_as_pdf_rounded,
            iconColor: t.pdfBadge,
            iconBackground: t.fill,
            title: 'Import PDF or slides',
            subtitle: 'Annotate a PDF · slides need a PDF export',
            action: CreateAction.importPdf,
          ),
          _Tile(
            icon: Icons.image_rounded,
            iconColor: const Color(0xFF2F9D7B),
            iconBackground: t.fill,
            title: 'Import images',
            subtitle: 'One page per image',
            action: CreateAction.importImages,
          ),
          _Tile(
            icon: Icons.document_scanner_rounded,
            iconColor: const Color(0xFFC08A2E),
            iconBackground: t.fill,
            title: 'Scan document',
            subtitle: 'Use the camera to capture pages',
            action: CreateAction.scan,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final CreateAction action;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, action),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: t.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: t.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
