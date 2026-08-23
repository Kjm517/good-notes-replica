import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/models/enums.dart';
import '../../core/sync/sync_providers.dart';
import '../../core/sync/sync_state.dart';
import '../editor/widgets/editor_prepare_overlay.dart';
import 'document_transfer.dart';
import 'providers.dart';

/// Reads per-document transfer state from a [ProviderContainer].
DocumentTransferState readDocumentTransfer(
  ProviderContainer container,
  String documentId,
) {
  return documentTransferState(
    documentId: documentId,
    pendingUpload:
        container.read(pendingUploadDocumentsProvider).asData?.value ??
            const {},
    missingLocal:
        container.read(missingLocalFileDocumentsProvider).asData?.value ??
            const {},
    status: container.read(syncStatusProvider),
    paused: container.read(syncPausedProvider),
  );
}

void showDocumentLockedSnackBar(
  BuildContext context,
  DocumentTransferState transfer,
  SyncStatus status,
) {
  final pct = transfer.percent(status);
  final pctLabel = pct != null ? ' ($pct%)' : '';
  final verb = transfer.kind == DocumentTransferKind.downloading
      ? 'downloading'
      : 'uploading';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Still $verb$pctLabel — try again when sync finishes.'),
    ),
  );
}

/// Opens [d] when its source file is ready. Returns false when blocked.
bool tryOpenDocument(
  BuildContext context,
  Document d, {
  required ProviderContainer container,
  bool replace = false,
}) {
  final transfer = readDocumentTransfer(container, d.id);
  if (transfer.locked) {
    showDocumentLockedSnackBar(
      context,
      transfer,
      container.read(syncStatusProvider),
    );
    return false;
  }
  if (d.type == DocumentType.folder) {
    context.push('/folder/${d.id}');
    return true;
  }
  container.read(libraryRepositoryProvider).touchOpened(d.id);
  if (replace) {
    context.go('/doc/${d.id}');
  } else {
    context.push('/doc/${d.id}');
  }
  return true;
}

/// Full-screen gate shown when navigating to a document whose file is still
/// transferring — common on a fresh sign-in while R2 bytes catch up.
class DocumentTransferGate extends ConsumerWidget {
  const DocumentTransferGate({
    super.key,
    required this.documentId,
    required this.transfer,
  });

  final String documentId;
  final DocumentTransferState transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final pageCount = ref
            .watch(documentPageCountProvider(documentId))
            .asData
            ?.value ??
        0;
    final label = transfer.badgeLabel(status) ?? 'Downloading…';
    final pct = transfer.percent(status);
    final fraction = pct != null ? (pct / 100).clamp(0.04, 0.96) : 0.04;

    return Scaffold(
      body: EditorPrepareOverlay(
        label: label,
        fraction: fraction,
        pageCount: pageCount,
        onClose: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      ),
    );
  }
}
