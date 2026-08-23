import '../../core/sync/sync_state.dart';

enum DocumentTransferKind { none, uploading, downloading }

/// Whether a library document's source file is mid-transfer.
class DocumentTransferState {
  const DocumentTransferState({
    this.assetId,
    this.kind = DocumentTransferKind.none,
    this.locked = false,
  });

  final String? assetId;
  final DocumentTransferKind kind;
  final bool locked;

  int? percent(SyncStatus status) {
    if (!status.isBusy || status.progress == null) return null;
    if (kind == DocumentTransferKind.downloading) {
      return (status.progress! * 100).round().clamp(0, 100);
    }
    if (assetId != null &&
        status.activeAssetId != null &&
        status.activeAssetId != assetId) {
      return null;
    }
    return (status.progress! * 100).round().clamp(0, 100);
  }

  String? badgeLabel(SyncStatus status) {
    final pct = percent(status);
    return switch (kind) {
      DocumentTransferKind.none => null,
      DocumentTransferKind.downloading => status.isBusy
          ? (pct != null ? 'Downloading $pct%' : 'Downloading…')
          : 'Waiting for file…',
      DocumentTransferKind.uploading => locked
          ? (pct != null ? 'Uploading $pct%' : 'Uploading…')
          : 'Waiting to upload',
    };
  }

  String? listBadgeLabel(SyncStatus status) {
    final pct = percent(status);
    return switch (kind) {
      DocumentTransferKind.none => null,
      DocumentTransferKind.downloading => status.isBusy
          ? (pct != null ? 'Downloading · $pct%' : 'Downloading…')
          : 'Waiting for file…',
      DocumentTransferKind.uploading => locked
          ? (pct != null ? 'Uploading · $pct%' : 'Uploading…')
          : 'Waiting to upload',
    };
  }
}

DocumentTransferState documentTransferState({
  required String documentId,
  required Map<String, String> pendingUpload,
  required Map<String, String> missingLocal,
  required SyncStatus status,
  required bool paused,
}) {
  final downloadAssetId = missingLocal[documentId];
  if (downloadAssetId != null) {
    return DocumentTransferState(
      assetId: downloadAssetId,
      kind: DocumentTransferKind.downloading,
      locked: true,
    );
  }

  final uploadAssetId = pendingUpload[documentId];
  if (uploadAssetId != null && !paused) {
    return DocumentTransferState(
      assetId: uploadAssetId,
      kind: DocumentTransferKind.uploading,
      locked: status.isBusy,
    );
  }

  return const DocumentTransferState();
}
