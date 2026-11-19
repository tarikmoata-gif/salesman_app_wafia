import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../widgets/common.dart';
import 'pickers.dart';

class StockScreen extends StatelessWidget {
  const StockScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('My Stock'),
            bottom: const TabBar(tabs: [Tab(text: 'Inventory'), Tab(text: 'My Requests')]),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StockRequestScreen())),
            icon: const Icon(Icons.inventory_2),
            label: const Text('Request'),
          ),
          body: TabBarView(children: [
            ApiList(
              path: 'stock',
              resultKey: 'items',
              searchable: true,
              emptyText: 'Your inventory is empty. Request products from the main warehouse.',
              itemBuilder: (c, i) => Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(i['name']),
                  trailing: Text('${(i['qty'] as num).toStringAsFixed((i['qty'] as num) % 1 == 0 ? 0 : 2)} ${i['uom']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            ApiList(
              path: 'stock_requests',
              resultKey: 'requests',
              emptyText: 'No stock requests yet.',
              itemBuilder: (c, r) {
                final color = r['state'] == 'approved' ? Colors.green : (r['state'] == 'rejected' ? Colors.red : Colors.orange);
                return Card(
                  child: ExpansionTile(
                    title: Text(r['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(r['date']),
                    trailing: StatusChip(r['state'].toString().toUpperCase(), color),
                    children: [for (final l in (r['lines'] as List)) ListTile(dense: true, title: Text(l['product']), trailing: Text('${l['qty']}'))],
                  ),
                );
              },
            ),
          ]),
        ),
      );
}

/// "Request Products": ask the main warehouse to load the salesman's van.
class StockRequestScreen extends StatefulWidget {
  const StockRequestScreen({super.key});
  @override
  State<StockRequestScreen> createState() => _StockRequestScreenState();
}

class _StockRequestScreenState extends State<StockRequestScreen> {
  final List<Map<String, dynamic>> _lines = [];
  final _note = TextEditingController();
  bool _busy = false;

  Future<void> _add() async {
    final p = await pickProduct(context, onlyInStock: false);
    if (p == null) return;
    setState(() {
      final i = _lines.indexWhere((l) => l['product']['id'] == p['id']);
      if (i >= 0) {
        _lines[i]['qty'] += 1.0;
      } else {
        _lines.add({'product': p, 'qty': 1.0});
      }
    });
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final r = await context.read<AppState>().call('stock_requests/create', {
        'note': _note.text,
        'lines': [for (final l in _lines) {'product_id': l['product']['id'], 'qty': l['qty']}],
      });
      if (!mounted) return;
      showMsg(context, 'Request ${r['name']} sent.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showMsg(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Request Products')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(child: Text('Products', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
            TextButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add')),
          ]),
          if (_lines.isEmpty) const EmptyView('Add the products you need loaded into your stock.'),
          for (var i = 0; i < _lines.length; i++)
            Card(
              child: ListTile(
                leading: productThumb(_lines[i]['product']['image'], size: 44),
                title: Text(_lines[i]['product']['name']),
                subtitle: Row(children: [
                  IconButton(onPressed: () => setState(() {
                        _lines[i]['qty'] -= 1.0;
                        if (_lines[i]['qty'] <= 0) _lines.removeAt(i);
                      }), icon: const Icon(Icons.remove_circle_outline)),
                  Text((_lines[i]['qty'] as double).toStringAsFixed(0), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  IconButton(onPressed: () => setState(() => _lines[i]['qty'] += 1.0), icon: const Icon(Icons.add_circle)),
                ]),
              ),
            ),
          const SizedBox(height: 12),
          TextField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note (optional)')),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy || _lines.isEmpty ? null : _send, child: const Text('Send Request')),
        ]),
      );
}
