import 'package:flutter/material.dart';

/// Admin console sections from design doc §13.
enum AdminSection {
  overview('overview', 'Overview', Icons.dashboard_outlined),
  users('users', 'Users', Icons.group_outlined),
  subscriptions('subscriptions', 'Subscriptions', Icons.card_membership_outlined),
  payments('payments', 'Payments', Icons.payments_outlined),
  vouchers('vouchers', 'Vouchers', Icons.local_activity_outlined),
  bugs('bugs', 'Bug reports', Icons.bug_report_outlined),
  ai('ai', 'AI usage', Icons.auto_awesome_outlined),
  documents('documents', 'Documents', Icons.folder_outlined),
  team('team', 'Team', Icons.admin_panel_settings_outlined),
  audit('audit', 'Audit log', Icons.receipt_long_outlined);

  const AdminSection(this.path, this.label, this.icon);

  final String path;
  final String label;
  final IconData icon;

  static AdminSection? fromPath(String? segment) {
    if (segment == null || segment.isEmpty) return overview;
    for (final s in AdminSection.values) {
      if (s.path == segment) return s;
    }
    return null;
  }

  String get location => '/admin/$path';
}
