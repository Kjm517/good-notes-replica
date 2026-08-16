import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design.dart';
import '../../library/providers.dart';
import '../stickers/sticker_library.dart';

/// Bottom sheet for choosing a sticker to drop on the page.
///
/// Two rails: the user's own stickers (with an "Add" tile for importing a PNG,
/// GIF or WebP) and a built-in emoji set. Picking one hands its bytes back via
/// [onPick] and closes the sheet; the editor then places it on the current
/// page. GIFs stay animated because they render through `Image.memory`.
class StickerPickerSheet extends ConsumerStatefulWidget {
  const StickerPickerSheet({super.key, required this.onPick});

  final void Function(Uint8List bytes, String name) onPick;

  static Future<void> show(
    BuildContext context, {
    required void Function(Uint8List bytes, String name) onPick,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StickerPickerSheet(onPick: onPick),
    );
  }

  @override
  ConsumerState<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends ConsumerState<StickerPickerSheet> {
  bool _busy = false;

  Future<void> _pickBuiltIn(String emoji) async {
    if (_busy) return;
    setState(() => _busy = true);
    final bytes = await renderEmojiSticker(emoji);
    if (!mounted) return;
    widget.onPick(bytes, 'Sticker');
    Navigator.of(context).pop();
  }

  Future<void> _pickCustom(CustomSticker sticker) async {
    if (_busy) return;
    setState(() => _busy = true);
    final bytes =
        await ref.read(assetRepositoryProvider).getBytes(sticker.assetId);
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _busy = false);
      return;
    }
    widget.onPick(bytes, sticker.name);
    Navigator.of(context).pop();
  }

  Future<void> _addCustom() async {
    if (_busy) return;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'gif', 'webp', 'jpg', 'jpeg'],
      withData: true,
    );
    final file = result?.files.firstOrNull;
    final raw = file?.bytes;
    if (raw == null || !mounted) return;
    setState(() => _busy = true);
    final bytes = Uint8List.fromList(raw);
    final name = file!.name;
    await ref.read(stickerLibraryProvider.notifier).add(bytes, name);
    if (!mounted) return;
    widget.onPick(bytes, name);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final custom = ref.watch(stickerLibraryProvider);
    final media = MediaQuery.of(context);
    final columns = media.size.width >= 600 ? 8 : 5;

    return Container(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.74),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: t.line,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 8, 4),
            child: Row(
              children: [
                Text('Stickers',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontSize: 18)),
                const Spacer(),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
              children: [
                _SectionLabel(text: 'YOUR STICKERS'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    _AddTile(onTap: _busy ? null : _addCustom),
                    for (final sticker in custom)
                      _CustomTile(
                        sticker: sticker,
                        onTap: () => _pickCustom(sticker),
                        onRemove: () => ref
                            .read(stickerLibraryProvider.notifier)
                            .remove(sticker.assetId),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionLabel(text: 'STICKERS'),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    for (final emoji in kBuiltInStickers)
                      _EmojiTile(
                        emoji: emoji,
                        onTap: () => _pickBuiltIn(emoji),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTokens.sectionLabel(context.tokens.textFaint));
  }
}

/// The "import your own" tile that opens the file picker.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.inner),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(Radii.inner),
          border: Border.all(color: t.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 22, color: t.textSecondary),
            const SizedBox(height: 2),
            Text('Add',
                style: TextStyle(fontSize: 10.5, color: t.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// A tile in the built-in emoji rail.
class _EmojiTile extends StatelessWidget {
  const _EmojiTile({required this.emoji, required this.onTap});
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.inner),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(Radii.inner),
        ),
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }
}

/// A tile for one of the user's saved stickers; long-press to remove it.
class _CustomTile extends ConsumerWidget {
  const _CustomTile({
    required this.sticker,
    required this.onTap,
    required this.onRemove,
  });

  final CustomSticker sticker;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  Future<void> _confirmRemove(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove sticker?'),
        content: const Text(
            'It will disappear from your stickers. Stickers already placed on '
            'pages stay put.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes == true) onRemove();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      onLongPress: () => _confirmRemove(context),
      borderRadius: BorderRadius.circular(Radii.inner),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.fill,
          borderRadius: BorderRadius.circular(Radii.inner),
          border: Border.all(color: t.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: FutureBuilder<Uint8List?>(
            future: ref.read(assetRepositoryProvider).getBytes(sticker.assetId),
            builder: (context, snap) {
              final bytes = snap.data;
              if (bytes == null) {
                return Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: snap.connectionState == ConnectionState.done
                        ? Icon(Icons.broken_image_outlined,
                            size: 16, color: t.textFaint)
                        : const CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return Image.memory(bytes,
                  fit: BoxFit.contain, gaplessPlayback: true);
            },
          ),
        ),
      ),
    );
  }
}
