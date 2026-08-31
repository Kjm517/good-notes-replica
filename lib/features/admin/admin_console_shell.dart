import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/design.dart';
import '../../app/providers.dart';
import 'admin_access.dart';
import 'admin_api.dart';
import 'admin_auth_providers.dart';
import 'admin_section.dart';
import 'widgets/admin_widgets.dart';
import 'pages/admin_audit_page.dart';
import 'pages/admin_ai_page.dart';
import 'pages/admin_bugs_page.dart';
import 'pages/admin_documents_page.dart';
import 'pages/admin_overview_page.dart';
import 'pages/admin_payments_page.dart';
import 'pages/admin_subscriptions_page.dart';
import 'pages/admin_team_page.dart';
import 'pages/admin_users_page.dart';
import 'pages/admin_vouchers_page.dart';

class AdminConsoleShell extends ConsumerStatefulWidget {
  const AdminConsoleShell({super.key, required this.section});

  final AdminSection section;

  @override
  ConsumerState<AdminConsoleShell> createState() => _AdminConsoleShellState();
}

class _AdminConsoleShellState extends ConsumerState<AdminConsoleShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final t = context.tokens;
    final width = MediaQuery.sizeOf(context).width;
    final useDrawer = width < 960;

    final content = switch (section) {
      AdminSection.overview => const AdminOverviewPage(),
      AdminSection.users => const AdminUsersPage(),
      AdminSection.subscriptions => const AdminSubscriptionsPage(),
      AdminSection.payments => const AdminPaymentsPage(),
      AdminSection.vouchers => const AdminVouchersPage(),
      AdminSection.bugs => const AdminBugsPage(),
      AdminSection.ai => const AdminAiPage(),
      AdminSection.documents => const AdminDocumentsPage(),
      AdminSection.team => const AdminTeamPage(),
      AdminSection.audit => const AdminAuditPage(),
    };

    final sidebar = _AdminSidebar(
      current: section,
      onNavigate: (s) {
        if (useDrawer) Navigator.of(context).pop();
        context.go(s.location);
      },
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: t.canvas,
      drawer: useDrawer ? Drawer(child: sidebar) : null,
      body: Row(
        children: [
          if (!useDrawer)
            SizedBox(width: 248, child: sidebar),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminTopBar(
                  section: section,
                  onMenu: useDrawer
                      ? () => _scaffoldKey.currentState?.openDrawer()
                      : null,
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminTopBar extends ConsumerWidget {
  const _AdminTopBar({
    required this.section,
    this.onMenu,
  });

  final AdminSection section;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final user = ref.watch(adminAuthStateProvider).asData?.value;
    final initials = _initials(user?.displayName ?? user?.email ?? 'Admin');
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          if (onMenu != null) ...[
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: onMenu,
              color: t.textMuted,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            section.label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: t.text,
            ),
          ),
          if (!(ref.watch(adminCanWriteProvider))) ...[
            const SizedBox(width: 10),
            AdminStatusChip(label: 'Viewer', color: t.textMuted),
          ],
          const Spacer(),
          IconButton(
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: () {
              ref.read(themeModeProvider.notifier).set(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
            },
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: t.textMuted,
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<_AdminUserMenu>(
            offset: const Offset(0, 44),
            tooltip: 'Account',
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.control),
              side: BorderSide(color: t.line),
            ),
            onSelected: (action) async {
              if (action == _AdminUserMenu.signOut) {
                await ref.read(adminAuthRepositoryProvider)?.signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  themeMode == ThemeMode.system
                      ? 'Theme: System'
                      : themeMode == ThemeMode.dark
                          ? 'Theme: Dark'
                          : 'Theme: Light',
                  style: AppTokens.mono(size: 11, color: t.textFaint),
                ),
              ),
              PopupMenuItem(
                value: _AdminUserMenu.signOut,
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: t.textMuted),
                    const SizedBox(width: 10),
                    Text('Log out', style: TextStyle(color: t.text)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: t.fill,
                borderRadius: BorderRadius.circular(Radii.control),
                border: Border.all(color: t.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: t.accentSoft,
                    child: Text(
                      initials,
                      style: AppTokens.mono(
                        size: 11,
                        weight: FontWeight.w700,
                        color: t.accentText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user?.displayName ?? user?.email?.split('@').first ?? 'Admin',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: t.text,
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, size: 18, color: t.textFaint),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return raw.isNotEmpty ? raw[0].toUpperCase() : '?';
  }
}

enum _AdminUserMenu { signOut }

class _AdminSidebar extends ConsumerWidget {
  const _AdminSidebar({
    required this.current,
    required this.onNavigate,
  });

  final AdminSection current;
  final ValueChanged<AdminSection> onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final badges = ref.watch(adminBadgeCountsProvider).maybeWhen(
          data: (c) => c,
          orElse: () => const AdminBadgeCounts(),
        );

    return ColoredBox(
      color: t.surfaceAlt,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
              child: Row(
                children: [
                  const AppMark(size: 32),
                  const SizedBox(width: 10),
                  Text(
                    'Notably',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: t.text,
                      letterSpacing: -0.02,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: t.accentSoft,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'ADMIN',
                      style: AppTokens.mono(
                        size: 9,
                        weight: FontWeight.w700,
                        color: t.accentText,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Console',
                style: AppTokens.sectionLabel(t.textFaint),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final item in AdminSection.values)
                    _NavTile(
                      item: item,
                      selected: item == current,
                      onTap: () => onNavigate(item),
                      tokens: t,
                      badge: _badgeFor(item, badges),
                      badgeColor: item == AdminSection.bugs ? t.pdfBadge : t.accentText,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextButton.icon(
                onPressed: () => context.go('/'),
                icon: Icon(Icons.arrow_back_rounded, size: 18, color: t.textMuted),
                label: Text(
                  'Back to app',
                  style: TextStyle(color: t.textMuted, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _badgeFor(AdminSection item, AdminBadgeCounts badges) {
    return switch (item) {
      AdminSection.bugs when badges.openBugs > 0 => '${badges.openBugs}',
      AdminSection.vouchers when badges.activeVouchers > 0 => '${badges.activeVouchers}',
      AdminSection.subscriptions when badges.premiumUsers > 0 => '${badges.premiumUsers}',
      _ => null,
    };
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.tokens,
    this.badge,
    this.badgeColor,
  });

  final AdminSection item;
  final bool selected;
  final VoidCallback onTap;
  final AppTokens tokens;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final chipColor = badgeColor ?? t.pdfBadge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? t.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.inner),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.inner),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.inner),
              border: selected ? Border.all(color: t.line) : null,
              boxShadow: selected
                  ? AppTokens.elevation(t.shadow, y: 4, blur: 12, opacity: 0.08)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? t.accentText : t.textMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? t.text : t.textSecondary,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: chipColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badge!,
                      style: AppTokens.mono(
                        size: 10,
                        weight: FontWeight.w700,
                        color: chipColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
