/// Per-person storage ceiling for imported files (PDFs, images, scans).
///
/// Enforced when new asset bytes are written. Re-importing a file that already
/// exists on this device does not consume additional quota.
const int kStorageQuotaBytes = 5 * 1024 * 1024 * 1024; // 5 GB

/// Thrown when an import or write would push past [kStorageQuotaBytes].
class StorageQuotaExceeded implements Exception {
  const StorageQuotaExceeded({
    required this.usedBytes,
    required this.neededBytes,
    this.quotaBytes = kStorageQuotaBytes,
  });

  final int usedBytes;
  final int neededBytes;
  final int quotaBytes;

  int get remainingBytes => (quotaBytes - usedBytes).clamp(0, quotaBytes);

  bool get isFull => usedBytes >= quotaBytes;

  String get title => isFull ? 'Storage full' : 'Not enough storage';

  String get message {
    if (isFull) {
      return 'You’ve used ${formatStorageBytes(usedBytes)} of your 5 GB allowance. '
          'Delete documents you no longer need, then try again.';
    }
    return 'This file needs ${formatStorageBytes(neededBytes)}, but only '
        '${formatStorageBytes(remainingBytes)} is free of your 5 GB.';
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
