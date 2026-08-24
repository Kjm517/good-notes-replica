import '../../core/models/enums.dart';
import '../../core/sync/sync_state.dart';

enum DocumentTransferKind { none, uploading, downloading, syncingPages }

/// Whether a library document's source file is mid-transfer.
class DocumentTransferState {
  const DocumentTransferState({
    this.documentId,
    this.assetId,
    this.kind = DocumentTransferKind.none,
    this.locked = false,
  });

  final String? documentId;
  final String? assetId;
  final DocumentTransferKind kind;

  /// True when the editor must not open yet (no local file, or no pages).
  /// Remaining page rows can keep syncing after this is false.
  final bool locked;

  bool get showCoverProgress => kind != DocumentTransferKind.none;

  int? percent(SyncStatus status) {
    final fraction = progressFraction(status);
    if (fraction == null) return null;
    return (fraction * 100).round().clamp(0, 100);
  }

  /// 0–1 fill for the cover colour reveal; null = no new reading (hold last).
  double? progressFraction(SyncStatus status) {
    if (kind == DocumentTransferKind.none) return null;

    final pullingThis =
        documentId != null && status.pullingDocumentId == documentId;
    // Page-insert progress wins over the staged 0.60 "Downloading documents"
    // cursor — swapping between those two is what made the bar snap.
    if (pullingThis && status.pullingDocumentProgress != null) {
      return status.pullingDocumentProgress!.clamp(0.0, 1.0);
    }
    if (kind == DocumentTransferKind.syncingPages) {
      return pullingThis ? status.pullingDocumentProgress?.clamp(0.0, 1.0) : null;
    }

    if (kind == DocumentTransferKind.downloading ||
        kind == DocumentTransferKind.uploading) {
      if (kind == DocumentTransferKind.downloading) {
        if (status.isBusy && status.progress != null) {
          return status.progress!.clamp(0.0, 1.0);
        }
        return null;
      }
      if (assetId != null &&
          status.activeAssetId != null &&
          status.activeAssetId != assetId) {
        return null;
      }
      if (status.isBusy && status.progress != null) {
        return status.progress!.clamp(0.0, 1.0);
      }
      return null;
    }

    return null;
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
      DocumentTransferKind.syncingPages => status.isBusy
          ? (pct != null ? 'Syncing pages $pct%' : 'Syncing pages…')
          : 'Waiting to sync pages…',
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
      DocumentTransferKind.syncingPages => status.isBusy
          ? (pct != null ? 'Syncing pages · $pct%' : 'Syncing pages…')
          : 'Waiting to sync pages…',
    };
  }

  String get lockedVerb => switch (kind) {
        DocumentTransferKind.downloading => 'downloading',
        DocumentTransferKind.uploading => 'uploading',
        DocumentTransferKind.syncingPages => 'syncing',
        DocumentTransferKind.none => 'syncing',
      };
}

DocumentTransferState documentTransferState({
  required String documentId,
  required Map<String, String> pendingUpload,
  required Map<String, String> missingLocal,
  required SyncStatus status,
  required bool paused,
  DocumentType documentType = DocumentType.notebook,
  int? pageCount,
  bool hasCoverPreview = false,
}) {
  final downloadAssetId = missingLocal[documentId];
  if (downloadAssetId != null) {
    return DocumentTransferState(
      documentId: documentId,
      assetId: downloadAssetId,
      kind: DocumentTransferKind.downloading,
      locked: true,
    );
  }

  final uploadAssetId = pendingUpload[documentId];
  if (uploadAssetId != null && !paused) {
    return DocumentTransferState(
      documentId: documentId,
      assetId: uploadAssetId,
      kind: DocumentTransferKind.uploading,
      locked: status.isBusy,
    );
  }

  // Cover can land (and pages can already be in the thousands) while the
  // rest of the page rows are still being pulled. The editor is openable
  // as soon as any pages exist — remaining rows catch up in the background.
  final pagesPulling = status.pullingDocumentIds.contains(documentId) ||
      status.pullingDocumentId == documentId;
  if (documentType != DocumentType.folder && pagesPulling) {
    return DocumentTransferState(
      documentId: documentId,
      kind: DocumentTransferKind.syncingPages,
      locked: pageCount == 0,
    );
  }

  // Metadata landed (cover visible) but this run has not reached the
  // document's page pull yet.
  if (documentType != DocumentType.folder &&
      pageCount == 0 &&
      hasCoverPreview &&
      (status.isBusy || status.phase == SyncPhase.pending)) {
    return DocumentTransferState(
      documentId: documentId,
      kind: DocumentTransferKind.syncingPages,
      locked: true,
    );
  }

  return DocumentTransferState(documentId: documentId);
}

