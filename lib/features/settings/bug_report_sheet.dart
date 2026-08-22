import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/design.dart';
import 'settings_widgets.dart';

const kBugReportEmail = 'kajama517@gmail.com';

enum BugCategory { crash, sync, annotation, aiQuiz, other }

class BugReportSheet extends StatefulWidget {
  const BugReportSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const BugReportSheet(),
    );
  }

  @override
  State<BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends State<BugReportSheet> {
  BugCategory _category = BugCategory.annotation;
  final _subject = TextEditingController();
  final _description = TextEditingController();
  var _attachDiagnostics = true;
  final _attachments = <PlatformFile>[];
  static const _maxAttachments = 5;
  static const _maxBytes = 25 * 1024 * 1024;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    if (_attachments.length >= _maxAttachments) return;
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: kIsWeb,
    );
    if (result == null) return;
    setState(() {
      for (final f in result.files) {
        if (_attachments.length >= _maxAttachments) break;
        final size = f.size;
        if (size > _maxBytes) continue;
        _attachments.add(f);
      }
    });
  }

  String _deviceLabel() {
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  String _categoryLabel(BugCategory c) => switch (c) {
        BugCategory.crash => 'Crash',
        BugCategory.sync => 'Sync',
        BugCategory.annotation => 'Annotation',
        BugCategory.aiQuiz => 'AI quiz',
        BugCategory.other => 'Other',
      };

  Future<void> _send() async {
    final subject = _subject.text.trim();
    final body = _description.text.trim();
    if (subject.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a subject and description first.')),
      );
      return;
    }

    final diag = _attachDiagnostics
        ? '\n\n—\nNotably 1.0.0 · ${_deviceLabel()}\n'
            'Category: ${_categoryLabel(_category)}\n'
        : '\n\n—\nNotably 1.0.0 · ${_deviceLabel()}\n';

    final attachmentNote = _attachments.isEmpty
        ? ''
        : '\nAttachments (${_attachments.length}): '
            '${_attachments.map((f) => f.name).join(', ')}\n';

    final uri = Uri(
      scheme: 'mailto',
      path: kBugReportEmail,
      query: [
        'subject=${Uri.encodeComponent('Notably bug: $subject')}',
        'body=${Uri.encodeComponent('$body$attachmentNote$diag')}',
      ].join('&'),
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        await Clipboard.setData(
          ClipboardData(text: '$subject\n\n$body$attachmentNote$diag'),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied report to clipboard · $kBugReportEmail')),
        );
      }
    } catch (_) {
      await Clipboard.setData(
        ClipboardData(text: '$subject\n\n$body$attachmentNote$diag'),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied report · $kBugReportEmail')),
      );
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Report a bug',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: t.text,
            ),
          ),
          const SizedBox(height: 16),
          Text('What went wrong?', style: _labelStyle(t)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final c in BugCategory.values)
                _CategoryChip(
                  label: _categoryLabel(c),
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Subject', style: _labelStyle(t)),
          const SizedBox(height: 8),
          TextField(
            controller: _subject,
            decoration: _fieldDecoration(t, hint: 'Brief summary'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Description', style: _labelStyle(t)),
              const Spacer(),
              Text(
                '${_description.text.length} / 1000',
                style: AppTokens.mono(size: 10, color: t.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            maxLines: 4,
            maxLength: 1000,
            onChanged: (_) => setState(() {}),
            decoration: _fieldDecoration(t, hint: 'What happened? Steps to reproduce?'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('Attachments', style: _labelStyle(t)),
              const Spacer(),
              Text(
                '${_attachments.length} / $_maxAttachments · max 25 MB',
                style: AppTokens.mono(size: 10, color: t.textFaint),
              ),
            ],
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in _attachments) _AttachmentThumb(file: f, onRemove: () {
                  setState(() => _attachments.remove(f));
                }),
                if (_attachments.length < _maxAttachments)
                  _AddAttachmentTile(onTap: _pickFiles),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SettingsGroupCard(
            children: [
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                secondary: Icon(Icons.bug_report_outlined, color: t.textSecondary),
                title: const Text('Attach diagnostics', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  'Device, app version, crash log',
                  style: AppTokens.mono(size: 10, color: t.textFaint),
                ),
                value: _attachDiagnostics,
                activeTrackColor: t.accent,
                onChanged: (v) => setState(() => _attachDiagnostics = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _send,
            icon: const Icon(Icons.send_rounded),
            label: const Text('Send report'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _labelStyle(AppTokens t) =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: t.textSecondary);

  InputDecoration _fieldDecoration(AppTokens t, {required String hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: t.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(color: t.lineStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(color: t.lineStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.control),
        borderSide: BorderSide(color: t.accent, width: 1.5),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(t.accent.withValues(alpha: 0.24), t.surface)
              : t.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? t.accent : t.lineStrong,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 14, color: t.accentText),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? t.text : t.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.file, required this.onRemove});

  final PlatformFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final isImage = file.extension?.toLowerCase() == 'png' ||
        file.extension?.toLowerCase() == 'jpg' ||
        file.extension?.toLowerCase() == 'jpeg';
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: t.fill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.lineStrong),
                    image: isImage && file.bytes != null
                        ? DecorationImage(
                            image: MemoryImage(file.bytes!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: !isImage
                      ? Icon(Icons.description_outlined, color: t.textFaint, size: 28)
                      : null,
                ),
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: CircleAvatar(
                      radius: 9,
                      backgroundColor: Colors.black.withValues(alpha: 0.85),
                      child: Icon(Icons.close_rounded, size: 12, color: t.text),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${file.name} · ${_formatSize(file.size)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTokens.mono(size: 9, color: t.textFaint),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _AddAttachmentTile extends StatelessWidget {
  const _AddAttachmentTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.lineStrong, width: 1.5, strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_file_rounded, size: 22, color: t.textMuted),
            const SizedBox(height: 3),
            Text('Add file', style: TextStyle(fontSize: 10.5, color: t.textMuted)),
          ],
        ),
      ),
    );
  }
}
