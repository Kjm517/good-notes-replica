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
  Document document, {
  int? pageCount,
}) {
  return documentTransferState(
    documentId: document.id,
    pendingUpload:
        container.read(pendingUploadDocumentsProvider).asData?.value ??
            const {},
    missingLocal:
        container.read(missingLocalFileDocumentsProvider).asData?.value ??
            const {},
    status: container.read(syncStatusProvider),
    paused: container.read(syncPausedProvider),
    documentType: document.type,
    pageCount: pageCount,
    hasCoverPreview:
        document.coverThumb != null && document.coverThumb!.isNotEmpty,
  );
}

void showDocumentLockedSnackBar(
  BuildContext context,
  DocumentTransferState transfer,
  SyncStatus status,
) {
  final pct = transfer.percent(status);
  final pctLabel = pct != null ? ' ($pct%)' : '';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Still ${transfer.lockedVerb}$pctLabel — try again when sync finishes.',
      ),
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
  final transfer = readDocumentTransfer(
    container,
    d,
    pageCount: container
        .read(documentPageCountProvider(d.id))
        .asData
        ?.value,
  );
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
class DocumentTransferGate extends ConsumerStatefulWidget {
  const DocumentTransferGate({
    super.key,
    required this.documentId,
    required this.transfer,
  });

  final String documentId;
  final DocumentTransferState transfer;

  @override
  ConsumerState<DocumentTransferGate> createState() =>
      _DocumentTransferGateState();
}

class _DocumentTransferGateState extends ConsumerState<DocumentTransferGate> {
  double _heldFraction = 0;
  late String _heldLabel;

  @override
  void initState() {
    super.initState();
    _heldLabel = widget.transfer.badgeLabel(const SyncStatus()) ?? 'Syncing…';
  }

  void _absorb(double? next, String? label) {
    if (next != null && next + 0.0005 >= _heldFraction) {
      _heldFraction = next.clamp(0.0, 1.0);
    }
    if (label != null && label.isNotEmpty) {
      _heldLabel = label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(syncStatusProvider);
    final pageCount = ref
            .watch(documentPageCountProvider(widget.documentId))
            .asData
            ?.value ??
        0;
    final pendingUpload =
        ref.watch(pendingUploadDocumentsProvider).asData?.value ?? const {};
    final missingLocal =
        ref.watch(missingLocalFileDocumentsProvider).asData?.value ?? const {};
    final paused = ref.watch(syncPausedProvider);
    final doc = ref.watch(documentStreamProvider(widget.documentId)).asData?.value;
    final transfer = documentTransferState(
      documentId: widget.documentId,
      pendingUpload: pendingUpload,
      missingLocal: missingLocal,
      status: status,
      paused: paused,
      documentType: doc?.type ?? DocumentType.notebook,
      pageCount: pageCount,
      hasCoverPreview: (doc?.coverThumb ?? '').isNotEmpty,
    );
    _absorb(transfer.progressFraction(status), transfer.badgeLabel(status));

    return Scaffold(
      body: EditorPrepareOverlay(
        label: _heldLabel,
        fraction: _heldFraction,
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
