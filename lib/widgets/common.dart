import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';

void showMsg(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
}

String money(num v, String cur) => '${v.toStringAsFixed(2)} $cur';

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip(this.label, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      );
}

({String label, Color color}) orderState(String s) {
  switch (s) {
    case 'draft':
      return (label: 'Quotation', color: Colors.orange);
    case 'sale':
      return (label: 'Sale', color: Colors.green);
    case 'done':
      return (label: 'Locked', color: Colors.teal);
    case 'cancel':
      return (label: 'Cancelled', color: Colors.red);
    default:
      return (label: s, color: Colors.grey);
  }
}

({String label, Color color}) payState(String s) {
  switch (s) {
    case 'paid':
      return (label: 'Paid', color: Colors.green);
    case 'partial':
      return (label: 'Partial', color: Colors.orange);
    case 'in_payment':
      return (label: 'In Payment', color: Colors.blue);
    default:
      return (label: 'Not Paid', color: Colors.red);
  }
}

class ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView(this.error, this.onRetry, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ]),
        ),
      );
}

class EmptyView extends StatelessWidget {
  final String text;
  const EmptyView(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ),
      );
}

/// Generic "load a list from the API, pull to refresh, search" scaffold body.
class ApiList extends StatefulWidget {
  final String path;
  final Map<String, dynamic> params;
  final String resultKey;
  final Widget Function(BuildContext, Map<String, dynamic>) itemBuilder;
  final bool searchable;
  final String emptyText;
  const ApiList({
    super.key,
    required this.path,
    required this.resultKey,
    required this.itemBuilder,
    this.params = const {},
    this.searchable = false,
    this.emptyText = 'Nothing here yet.',
  });
  @override
  State<ApiList> createState() => ApiListState();
}

class ApiListState extends State<ApiList> {
  late Future<List<Map<String, dynamic>>> _future;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant ApiList old) {
    super.didUpdateWidget(old);
    if (old.params.toString() != widget.params.toString() || old.path != widget.path) reload();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await context.read<AppState>().call(widget.path, {...widget.params, if (_search.isNotEmpty) 'search': _search});
    return (r[widget.resultKey] as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  void reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (widget.searchable)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search', isDense: true),
            onSubmitted: (v) {
              _search = v.trim();
              reload();
            },
          ),
        ),
      Expanded(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return ErrorView(snap.error!, reload);
            final items = snap.data!;
            return RefreshIndicator(
              onRefresh: () async {
                reload();
                await _future;
              },
              child: items.isEmpty
                  ? ListView(children: [SizedBox(height: 200, child: EmptyView(widget.emptyText))])
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: items.length,
                      itemBuilder: (c, i) => widget.itemBuilder(c, items[i]),
                    ),
            );
          },
        ),
      ),
    ]);
  }
}

Widget productThumb(String? b64, {double size = 56}) {
  if (b64 == null || b64.isEmpty) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.inventory_2_outlined, color: Colors.grey),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.memory(base64Decode(b64), width: size, height: size, fit: BoxFit.contain, gaplessPlayback: true),
  );
}
