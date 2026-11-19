import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../widgets/common.dart';
import 'new_order.dart';

/// Requests created by customers (via the separate customer app) and assigned to this salesman.
class CustomerRequestsScreen extends StatefulWidget {
  const CustomerRequestsScreen({super.key});
  @override
  State<CustomerRequestsScreen> createState() => _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState extends State<CustomerRequestsScreen> {
  String _state = '';
  final _listKey = GlobalKey<ApiListState>();
  static const _filters = {'': 'All', 'new': 'New', 'in_progress': 'In Progress', 'done': 'Done', 'cancelled': 'Cancelled'};

  Color _color(String s) => switch (s) {
        'new' => Colors.blue,
        'in_progress' => Colors.orange,
        'done' => Colors.green,
        _ => Colors.grey,
      };

  Future<void> _setState(Map<String, dynamic> r, String state) async {
    try {
      await context.read<AppState>().call('customer_requests/update', {'request_id': r['id'], 'state': state});
      _listKey.currentState?.reload();
    } catch (e) {
      if (mounted) showMsg(context, e.toString(), error: true);
    }
  }

  void _details(Map<String, dynamic> r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r['name'], style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
            StatusChip(_filters[r['state']] ?? r['state'], _color(r['state'])),
          ]),
          Text(r['partner'], style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          if ((r['description'] as String).isNotEmpty) Text(r['description']),
          const SizedBox(height: 8),
          for (final l in (r['lines'] as List)) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.inventory_2_outlined), title: Text(l['name']), trailing: Text('× ${l['qty']}')),
          const SizedBox(height: 12),
          if (r['state'] == 'new' || r['state'] == 'in_progress') ...[
            if ((r['lines'] as List).isNotEmpty)
              FilledButton.icon(
                icon: const Icon(Icons.shopping_cart_checkout),
                label: const Text('Create order from request'),
                onPressed: () async {
                  Navigator.pop(c);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NewOrderScreen(
                        customer: {
                          'id': r['partner_id'],
                          'name': r['partner'],
                          'lat': r['partner_lat'],
                          'lng': r['partner_lng'],
                          'has_location': r['partner_has_location'],
                        },
                        prefillLines: [for (final l in (r['lines'] as List)) Map<String, dynamic>.from(l)],
                        requestId: r['id'],
                      ),
                    ),
                  );
                  _listKey.currentState?.reload();
                },
              ),
            const SizedBox(height: 8),
            Row(children: [
              if (r['state'] == 'new') Expanded(child: OutlinedButton(onPressed: () { Navigator.pop(c); _setState(r, 'in_progress'); }, child: const Text('Start'))),
              if (r['state'] == 'new') const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () { Navigator.pop(c); _setState(r, 'done'); }, child: const Text('Mark Done'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () { Navigator.pop(c); _setState(r, 'cancelled'); }, child: const Text('Cancel'))),
            ]),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Customer Requests')),
        body: Column(children: [
          SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              for (final e in _filters.entries)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(e.value), selected: _state == e.key, onSelected: (_) => setState(() => _state = e.key))),
            ]),
          ),
          Expanded(
            child: ApiList(
              key: _listKey,
              path: 'customer_requests',
              resultKey: 'requests',
              params: {'state': _state},
              emptyText: 'No customer requests.',
              itemBuilder: (c, r) => Card(
                child: ListTile(
                  leading: Icon(r['type'] == 'complaint' ? Icons.report_problem_outlined : Icons.support_agent, color: _color(r['state'])),
                  title: Text('${r['name']}  •  ${r['partner']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text((r['description'] as String).isEmpty ? '${(r['lines'] as List).length} product(s)' : r['description'], maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: StatusChip(_filters[r['state']] ?? r['state'], _color(r['state'])),
                  onTap: () => _details(r),
                ),
              ),
            ),
          ),
        ]),
      );
}
