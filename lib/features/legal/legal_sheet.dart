import 'package:flutter/material.dart';

import '../../app/design.dart';
import 'legal_copy.dart';

/// Full-height sheet with Terms and Privacy. Returns `true` if the user
/// taps Agree (sign-up). Settings opens it read-only.
class LegalSheet extends StatefulWidget {
  const LegalSheet({
    super.key,
    this.initial = LegalDoc.terms,
    this.requireAgree = false,
  });

  final LegalDoc initial;
  final bool requireAgree;

  /// `true` when the user agrees; `false` / null if they dismiss.
  static Future<bool> show(
    BuildContext context, {
    LegalDoc initial = LegalDoc.terms,
    bool requireAgree = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => LegalSheet(
        initial: initial,
        requireAgree: requireAgree,
      ),
    );
    return result == true;
  }

  @override
  State<LegalSheet> createState() => _LegalSheetState();
}

class _LegalSheetState extends State<LegalSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initial == LegalDoc.privacy ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final height = MediaQuery.sizeOf(context).height * 0.92;

    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Notably legal',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          TabBar(
            controller: _tabs,
            labelColor: t.accentText,
            unselectedLabelColor: t.textMuted,
            indicatorColor: t.accent,
            tabs: const [
              Tab(text: kTermsTitle),
              Tab(text: kPrivacyTitle),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _LegalScroll(sections: kTermsSections),
                _LegalScroll(sections: kPrivacySections),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            child: widget.requireAgree
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Not now'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('I agree'),
                        ),
                      ),
                    ],
                  )
                : OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Close'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LegalScroll extends StatelessWidget {
  const _LegalScroll({required this.sections});

  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final s = sections[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.heading,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.body,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: t.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
