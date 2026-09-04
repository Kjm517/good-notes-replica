import 'package:flutter/material.dart';

import '../../../app/design.dart';

/// What the user picked in the create sheet.
enum CreateAction { notebook, folder, importPdf, importImages, scan }

/// The "Create" bottom sheet.
///
/// Returns the chosen [CreateAction] and does nothing else — the caller owns
/// the work, so this stays a pure presentation widget that both the phone FAB
/// and the desktop "New" button can share.
///
/// The one exception is [onTapAction], which runs *synchronously* on the tap
/// before the sheet starts closing. WebKit (every browser on iPad) only opens
/// a file dialog while the originating tap is still on the call stack, so an
/// import has to start its picker here — by the time `show` returns, the
/// dismiss animation has ended the gesture and `input.click()` is ignored
/// with no error. Callers that do not pick files can leave it null.
class CreateSheet extends StatelessWidget {
  const CreateSheet({super.key, this.onTapAction});

  /// Runs on the tap itself, before the sheet pops. See the class doc.
  final void Function(CreateAction action)? onTapAction;

  static Future<CreateAction?> show(
    BuildContext context, {
    void Function(CreateAction action)? onTapAction,
  }) {
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
            child: CreateSheet(onTapAction: onTapAction),
          ),
        ),
      );
    }
    return showModalBottomSheet<CreateAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (_) => CreateSheet(onTapAction: onTapAction),
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
            onTapAction: onTapAction,
            icon: Icons.menu_book_rounded,
            iconColor: t.accentText,
            iconBackground: t.accentSoft,
            title: 'New notebook',
            subtitle: 'Blank pages, your template',
            action: CreateAction.notebook,
          ),
          _Tile(
            onTapAction: onTapAction,
            icon: Icons.create_new_folder_rounded,
            iconColor: t.textSecondary,
            iconBackground: t.fill,
            title: 'New folder',
            subtitle: 'Group documents together',
            action: CreateAction.folder,
          ),
          _Tile(
            onTapAction: onTapAction,
            icon: Icons.picture_as_pdf_rounded,
            iconColor: t.pdfBadge,
            iconBackground: t.fill,
            title: 'Import PDF or slides',
            subtitle: 'Annotate a PDF · slides need a PDF export',
            action: CreateAction.importPdf,
          ),
          _Tile(
            onTapAction: onTapAction,
            icon: Icons.image_rounded,
            iconColor: const Color(0xFF2F9D7B),
            iconBackground: t.fill,
            title: 'Import images',
            subtitle: 'One page per image',
            action: CreateAction.importImages,
          ),
          _Tile(
            onTapAction: onTapAction,
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
    required this.onTapAction,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final void Function(CreateAction action)? onTapAction;
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
        onTap: () {
          // Synchronous, before the pop: the file dialog must be opened while
          // this tap is still the active user gesture (see the class doc).
          onTapAction?.call(action);
          Navigator.pop(context, action);
        },
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
