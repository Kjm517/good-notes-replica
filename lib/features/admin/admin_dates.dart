/// Human-readable timestamps for the admin console.
DateTime? parseAdminDate(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  if (text.isEmpty) return null;

  final iso = DateTime.tryParse(text);
  if (iso != null && iso.year >= 2018) return iso;

  final n = num.tryParse(text);
  if (n != null) {
    if (n > 1e12) {
      return DateTime.fromMillisecondsSinceEpoch(n.round(), isUtc: true);
    }
    if (n > 1e9) {
      return DateTime.fromMillisecondsSinceEpoch((n * 1000).round(), isUtc: true);
    }
  }
  return iso;
}

String formatAdminWhen(String? raw) {
  final dt = parseAdminDate(raw)?.toLocal();
  if (dt == null) return '—';
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inSeconds.abs() < 45) return 'Just now';
  if (!diff.isNegative && diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (!diff.isNegative && diff.inHours < 24) return '${diff.inHours}h ago';
  if (!diff.isNegative && diff.inDays == 1) return 'Yesterday';
  if (!diff.isNegative && diff.inDays < 7) return '${diff.inDays}d ago';
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
