import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'document_text_service.dart';

/// "Find in document" panel — the Ctrl+F experience.
///
/// Searches text extracted from the source PDF (see [DocumentTextService]) and
/// jumps to the page a match is on.
class DocumentSearchPanel extends ConsumerStatefulWidget {
  const DocumentSearchPanel({
    super.key,
    required this.documentId,
    required this.onJumpToPage,
    required this.onClose,
  });

  final String documentId;
  final void Function(int pageIndex) onJumpToPage;
  final VoidCallback onClose;

  @override
  ConsumerState<DocumentSearchPanel> createState() =>
      _DocumentSearchPanelState();
}

class _DocumentSearchPanelState extends ConsumerState<DocumentSearchPanel> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<SearchHit> _hits = const [];
  int _current = -1;
  bool _searching = false;
  bool _indexing = false;
  double _indexProgress = 0;
  bool _ranSearch = false;

  DocumentTextService get _service => ref.read(documentTextServiceProvider);

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
    _prepareIndex();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Text is extracted lazily — the first search on a document may need to
  /// build the index before it can answer.
  Future<void> _prepareIndex() async {
    if (await _service.isIndexed(widget.documentId)) return;
    if (!mounted) return;
    setState(() => _indexing = true);
    await _service.index(
      widget.documentId,
      onProgress: (p) {
        if (mounted) setState(() => _indexProgress = p);
      },
    );
    if (!mounted) return;
    setState(() => _indexing = false);
    if (_controller.text.trim().isNotEmpty) _runSearch();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _hits = const [];
        _current = -1;
        _ranSearch = false;
      });
      return;
    }
    setState(() => _searching = true);
    final hits = await _service.search(widget.documentId, query);
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _searching = false;
      _ranSearch = true;
      _current = hits.isEmpty ? -1 : 0;
    });
    if (hits.isNotEmpty) widget.onJumpToPage(hits.first.pageIndex);
  }

  void _step(int delta) {
    if (_hits.isEmpty) return;
    final next = (_current + delta) % _hits.length;
    setState(() => _current = next < 0 ? _hits.length - 1 : next);
    widget.onJumpToPage(_hits[_current].pageIndex);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: scheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _step(1),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Find in document',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        border: const OutlineInputBorder(),
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (_hits.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text('${_current + 1}/${_hits.length}',
                        style: Theme.of(context).textTheme.bodySmall),
                    IconButton(
                      tooltip: 'Previous match',
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      onPressed: () => _step(-1),
                    ),
                    IconButton(
                      tooltip: 'Next match (Enter)',
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      onPressed: () => _step(1),
                    ),
                  ],
                  IconButton(
                    tooltip: 'Close (Esc)',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
            ),
            if (_indexing)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _indexProgress == 0 ? null : _indexProgress,
                      minHeight: 4,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reading the document for the first time… '
                      '${(_indexProgress * 100).round()}%',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            if (_ranSearch && _hits.isEmpty && !_searching && !_indexing)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No matches. Scanned pages have no text to search — '
                    'handwriting search comes later.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            if (_hits.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _hits.length,
                  itemBuilder: (context, i) {
                    final hit = _hits[i];
                    return ListTile(
                      dense: true,
                      selected: i == _current,
                      leading: CircleAvatar(
                        radius: 13,
                        child: Text('${hit.pageIndex + 1}',
                            style: const TextStyle(fontSize: 10)),
                      ),
                      title: Text(
                        hit.snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: hit.matchCount > 1
                          ? Text('${hit.matchCount}',
                              style: Theme.of(context).textTheme.labelSmall)
                          : null,
                      onTap: () {
                        setState(() => _current = i);
                        widget.onJumpToPage(hit.pageIndex);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
