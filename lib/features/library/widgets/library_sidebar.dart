import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design.dart';
import '../../../core/db/database.dart';
import '../../../core/models/enums.dart';
import '../../../core/storage/storage_quota.dart';
import '../../settings/entitlements.dart';
import '../providers.dart';

/// Width the sidebar occupies when shown. The library only mounts it above
/// [kSidebarBreakpoint], where there's room for it beside a 4-column grid.
const double kSidebarWidth = 236;

/// Below this the library switches to the phone layout: chips instead of a
/// sidebar, two columns instead of four.
const double kSidebarBreakpoint = AppBreakpoints.librarySidebar;

/// Persistent navigation rail for the desktop library.
///
/// Sections are app-wide shelves; Collections below them are the user's real
/// root folders, so the sidebar doubles as a folder jump list rather than a
/// second, redundant navigation model.
class LibrarySidebar extends ConsumerWidget {
  const LibrarySidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final section = ref.watch(librarySectionProvider);
    final foldersAsync = ref.watch(folderChildrenProvider(null));
    final folders = (foldersAsync.asData?.value ?? const <Document>[])
        .where((d) => d.type == DocumentType.folder)
        .toList();

    return Container(
      width: kSidebarWidth,
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Brand(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                children: [
                  for (final s in LibrarySection.values)
                    _NavRow(
                      icon: _iconFor(s),
                      label: s.label,
                      selected: section == s,
                      onTap: () =>
                          ref.read(librarySectionProvider.notifier).state = s,
                    ),
                  // Trash is a screen, not a filter: it needs restore and
                  // empty actions the library grid doesn't provide.
                  _NavRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Trash',
                    selected: false,
                    onTap: () => context.push('/trash'),
                  ),
                  if (folders.isNotEmpty) ...[
                    _SectionCaption(label: 'Collections'),
                    for (final f in folders)
                      _NavRow(
                        // A colour dot rather than a folder icon: the whole
                        // group is folders, so the icon carried no signal.
                        swatch: _folderColor(f.id),
                        label: f.title,
                        selected: false,
                        onTap: () => context.push('/folder/${f.id}'),
                      ),
                  ],
                ],
              ),
            ),
            const _StorageMeter(),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(LibrarySection s) => switch (s) {
    LibrarySection.all => Icons.description_outlined,
    LibrarySection.recent => Icons.schedule_rounded,
    LibrarySection.starred => Icons.star_outline_rounded,
  };

  /// Stable per-folder colour derived from its id, so a collection keeps the
  /// same dot across sessions and devices without storing anything.
  static Color _folderColor(String id) {
    const palette = [
      Color(0xFF3A6EA5),
      Color(0xFF2F7D6B),
      Color(0xFFB1543A),
      Color(0xFF7B5EA7),
      Color(0xFFC08A2E),
    ];
    return palette[id.hashCode.abs() % palette.length];
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: t.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.draw_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Notably',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              letterSpacing: -0.2,
              color: t.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCaption extends StatelessWidget {
  const _SectionCaption({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 22, 12, 10),
      child: Text(
        label.toUpperCase(),
        style: AppTokens.sectionLabel(t.textFaint),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    this.icon,
    this.swatch,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData? icon;
  final Color? swatch;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.accentText : t.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? t.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: [
                if (icon != null)
                  Icon(icon, size: 19, color: fg)
                else
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: swatch,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sidebar meter: active-library bytes vs the account storage quota.
class _StorageMeter extends ConsumerWidget {
  const _StorageMeter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final bytes = ref.watch(libraryStorageProvider).asData?.value ?? 0;
    final quota = ref.watch(storageQuotaBytesProvider);
    final fraction = (bytes / quota).clamp(0.0, 1.0);
    final usedGb = bytes / (1024 * 1024 * 1024);
    final quotaGb = quota / (1024 * 1024 * 1024);

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 22),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Storage',
                style: TextStyle(fontSize: 12, color: t.textMuted),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${usedGb.toStringAsFixed(1)} / ${quotaGb.toStringAsFixed(0)} GB',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: AppTokens.mono(size: 12, color: t.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: t.fill,
              valueColor: AlwaysStoppedAnimation<Color>(t.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Human-readable byte count (1 decimal place from MB up).
String formatBytes(int bytes) => formatStorageBytes(bytes);
