import 'package:flutter_test/flutter_test.dart';
import 'package:notably/core/models/enums.dart';
import 'package:notably/core/sync/sync_state.dart';
import 'package:notably/features/library/document_transfer.dart';

void main() {
  const docId = 'textbook';

  test('pages still pulling show cover progress but stay openable', () {
    final transfer = documentTransferState(
      documentId: docId,
      pendingUpload: const {},
      missingLocal: const {},
      status: const SyncStatus(
        phase: SyncPhase.syncing,
        progress: 0.60,
        progressMessage: 'Downloading documents…',
        pullingDocumentIds: {docId},
        pullingDocumentId: docId,
        pullingDocumentProgress: 0.4,
      ),
      paused: false,
      documentType: DocumentType.pdf,
      pageCount: 4452,
      hasCoverPreview: true,
    );

    expect(transfer.locked, isFalse);
    expect(transfer.kind, DocumentTransferKind.syncingPages);
    expect(transfer.showCoverProgress, isTrue);
    expect(transfer.progressFraction(const SyncStatus(
      phase: SyncPhase.syncing,
      pullingDocumentId: docId,
      pullingDocumentProgress: 0.4,
    )), 0.4);
  });

  test('a waiting document stays gray without using another document’s fill', () {
    final transfer = documentTransferState(
      documentId: docId,
      pendingUpload: const {},
      missingLocal: const {},
      status: const SyncStatus(
        phase: SyncPhase.syncing,
        pullingDocumentIds: {docId, 'other'},
        pullingDocumentId: 'other',
        pullingDocumentProgress: 0.9,
      ),
      paused: false,
      documentType: DocumentType.pdf,
      pageCount: 100,
      hasCoverPreview: true,
    );

    expect(transfer.locked, isFalse);
    expect(transfer.showCoverProgress, isTrue);
    expect(transfer.progressFraction(const SyncStatus(
      phase: SyncPhase.syncing,
      pullingDocumentIds: {docId, 'other'},
      pullingDocumentId: 'other',
      pullingDocumentProgress: 0.9,
    )), isNull);
  });

  test('page pull progress is used even when the file is still missing', () {
    final transfer = documentTransferState(
      documentId: docId,
      pendingUpload: const {},
      missingLocal: const {docId: 'asset-1'},
      status: const SyncStatus(
        phase: SyncPhase.syncing,
        progress: 0.60,
        pullingDocumentIds: {docId},
        pullingDocumentId: docId,
        pullingDocumentProgress: 0.32,
      ),
      paused: false,
      documentType: DocumentType.pdf,
      pageCount: 4895,
      hasCoverPreview: true,
    );

    expect(transfer.locked, isTrue);
    expect(
      transfer.progressFraction(const SyncStatus(
        phase: SyncPhase.syncing,
        progress: 0.60,
        pullingDocumentIds: {docId},
        pullingDocumentId: docId,
        pullingDocumentProgress: 0.32,
      )),
      0.32,
    );
  });

  test('zero local pages still block opening while the pull is in flight', () {
    final transfer = documentTransferState(
      documentId: docId,
      pendingUpload: const {},
      missingLocal: const {},
      status: const SyncStatus(
        phase: SyncPhase.syncing,
        pullingDocumentIds: {docId},
        pullingDocumentId: docId,
      ),
      paused: false,
      documentType: DocumentType.pdf,
      pageCount: 0,
      hasCoverPreview: true,
    );

    expect(transfer.locked, isTrue);
    expect(transfer.kind, DocumentTransferKind.syncingPages);
  });

  test('idle documents with pages are not locked', () {
    final transfer = documentTransferState(
      documentId: docId,
      pendingUpload: const {},
      missingLocal: const {},
      status: const SyncStatus(phase: SyncPhase.idle),
      paused: false,
      documentType: DocumentType.pdf,
      pageCount: 4452,
      hasCoverPreview: true,
    );

    expect(transfer.locked, isFalse);
    expect(transfer.showCoverProgress, isFalse);
  });
}
