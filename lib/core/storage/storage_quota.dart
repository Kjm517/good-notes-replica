/// Per-person storage ceiling for imported files (PDFs, images, scans).
///
/// Tier ladder (bytes on disk for imports):
///   Free  → 5 GB
///   Trial → 5 GB (same; trial unlocks AI features, not extra storage)
///   Premium (paid) → 15 GB
///
/// Enforced when new asset bytes are written. Re-importing a file that already
/// exists on this device does not consume additional quota.
const int kFreeStorageQuotaBytes = 5 * 1024 * 1024 * 1024; // 5 GB — free & trial
const int kPremiumStorageQuotaBytes = 15 * 1024 * 1024 * 1024; // 15 GB — paid Premium only

/// Default free/trial quota — kept for call sites that have not resolved premium yet.
const int kStorageQuotaBytes = kFreeStorageQuotaBytes;

/// Paid Premium gets 15 GB; free accounts and registration trials stay at 5 GB.
int storageQuotaBytes({required bool isPremium}) =>
    isPremium ? kPremiumStorageQuotaBytes : kFreeStorageQuotaBytes;

/// Short label for UI, e.g. `5 GB` or `15 GB`.
String storageQuotaLabel(int quotaBytes) {
  if (quotaBytes == kPremiumStorageQuotaBytes) return '15 GB';
  if (quotaBytes == kFreeStorageQuotaBytes) return '5 GB';
  return formatStorageBytes(quotaBytes);
}

/// Thrown when an import or write would push past the storage ceiling.
class StorageQuotaExceeded implements Exception {
  const StorageQuotaExceeded({
    required this.usedBytes,
    required this.neededBytes,
    this.quotaBytes = kFreeStorageQuotaBytes,
  });

  final int usedBytes;
  final int neededBytes;
  final int quotaBytes;

  int get remainingBytes => (quotaBytes - usedBytes).clamp(0, quotaBytes);

  bool get isFull => usedBytes >= quotaBytes;

  String get title => isFull ? 'Storage full' : 'Not enough storage';

  String get message {
    final allowance = storageQuotaLabel(quotaBytes);
    if (isFull) {
      return 'You’ve used ${formatStorageBytes(usedBytes)} of your $allowance allowance. '
          'Delete documents you no longer need, then try again.';
    }
    return 'This file needs ${formatStorageBytes(neededBytes)}, but only '
        '${formatStorageBytes(remainingBytes)} is free of your $allowance.';
  }

  @override
  String toString() => message;
}

/// Human-readable byte count (1 decimal place from MB up).
String formatStorageBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final digits = unit == 0 ? 0 : 1;
  return '${value.toStringAsFixed(digits)} ${units[unit]}';
}
