import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design.dart';
import '../../core/sync/user_telemetry.dart';
import '../auth/providers.dart';
import 'settings_widgets.dart';

enum BugCategory { crash, sync, annotation, aiQuiz, other }

class BugReportSheet extends ConsumerStatefulWidget {
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
  ConsumerState<BugReportSheet> createState() => _BugReportSheetState();
}

class _BugReportSheetState extends ConsumerState<BugReportSheet> {
  BugCategory _category = BugCategory.annotation;
  final _subject = TextEditingController();
  final _description = TextEditingController();
  var _attachDiagnostics = true;
  var _busy = false;
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
        if (f.size > _maxBytes) continue;
        _attachments.add(f);
      }
    });
  }

  String get _deviceLabel {
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

  Future<void> _send() async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to send a bug report to the admin console.'),
        ),
      );
      return;
    }

    final subject = _subject.text.trim().isEmpty
        ? 'Notably bug report'
        : _subject.text.trim();
    final description = _description.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe what went wrong.')),
      );
      return;
    }

    final attachmentNames = _attachments.map((f) => f.name).join(', ');
    final body = StringBuffer()
      ..writeln(description)
      ..writeln()
      ..writeln('Attachments: ${attachmentNames.isEmpty ? 'none' : attachmentNames}')
      ..writeln('Diagnostics: ${_attachDiagnostics ? 'yes' : 'no'}')
      ..writeln()
      ..writeln('—')
      ..writeln('Notably · $_deviceLabel · ${user.email ?? user.uid}');

    setState(() => _busy = true);
    final result = await UserTelemetry.submitBugReport(
      category: _category.name,
      subject: subject,
      description: body.toString(),
      device: _deviceLabel,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (result.ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report sent — the admin team can see it in Bug reports.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Could not send bug report.')),
    );
  }

  static String _categoryLabel(BugCategory c) => switch (c) {
        BugCategory.crash => 'Crash',
        BugCategory.sync => 'Sync',
        BugCategory.annotation => 'Annotation',
        BugCategory.aiQuiz => 'AI quiz',
        BugCategory.other => 'Other',
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final signedIn = ref.watch(authStateProvider).asData?.value != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(
                'Report a bug',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(
                signedIn
                    ? 'Reports go to the Notably admin console for the team to review.'
                    : 'Sign in first so your report appears on the admin Bug reports page.',
                style: TextStyle(fontSize: 13, color: t.textMuted),
              ),
              const SizedBox(height: 18),
              Text('Category', style: AppTokens.sectionLabel(t.textFaint)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: BugCategory.values.map((c) {
                  final selected = _category == c;
                  return FilterChip(
                    label: Text(_categoryLabel(c)),
                    selected: selected,
                    onSelected: _busy ? null : (_) => setState(() => _category = c),
                    selectedColor: t.accentSoft,
                    checkmarkColor: t.accentText,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? t.accentText : t.textSecondary,
                    ),
                    side: BorderSide(color: selected ? t.accentText : t.line),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _subject,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Brief summary',
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What happened? Steps to reproduce?',
                  alignLabelWithHint: true,
                ),
                minLines: 4,
                maxLines: 8,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text('Attachments', style: AppTokens.sectionLabel(t.textFaint)),
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
                    for (final f in _attachments)
                      _AttachmentThumb(
                        file: f,
                        onRemove: _busy
                            ? () {}
                            : () => setState(() => _attachments.remove(f)),
                      ),
                    if (_attachments.length < _maxAttachments)
                      _AddAttachmentTile(onTap: _busy ? () {} : _pickFiles),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SettingsGroupCard(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                    secondary: Icon(Icons.bug_report_outlined, color: t.textSecondary),
                    title: const Text(
                      'Attach diagnostics',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Device, app version, crash log',
                      style: AppTokens.mono(size: 10, color: t.textFaint),
                    ),
                    value: _attachDiagnostics,
                    activeTrackColor: t.accent,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _attachDiagnostics = v),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _send,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_busy ? 'Sending…' : 'Send to admin console'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ],
          );
        },
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: t.fill,
              borderRadius: BorderRadius.circular(Radii.inner),
              border: Border.all(color: t.line),
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.insert_drive_file_outlined, color: t.textMuted, size: 22),
                const SizedBox(height: 6),
                Text(
                  file.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTokens.mono(size: 9, color: t.textSecondary),
                ),
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: IconButton.filled(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 14),
              style: IconButton.styleFrom(
                backgroundColor: t.surface,
                foregroundColor: t.text,
                minimumSize: const Size(24, 24),
                padding: EdgeInsets.zero,
                side: BorderSide(color: t.line),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddAttachmentTile extends StatelessWidget {
  const _AddAttachmentTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.inner),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.inner),
          border: Border.all(color: t.lineStrong, style: BorderStyle.solid),
          color: t.fill,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: t.accentText),
            const SizedBox(height: 4),
            Text('Add', style: TextStyle(fontSize: 12, color: t.textMuted)),
          ],
        ),
      ),
    );
  }
}
