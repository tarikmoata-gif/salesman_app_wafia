import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../widgets/common.dart';

class OrdersScreen extends StatelessWidget {
  final bool returnMode;
  const OrdersScreen({super.key, this.returnMode = false});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(returnMode ? 'Return Product' : 'My Orders')),
        body: ApiList(
          path: 'orders',
          resultKey: 'orders',
          params: {'only_confirmed': returnMode},
          searchable: true,
          emptyText: 'No orders.',
          itemBuilder: (c, o) {
            final st = orderState(o['state']);
            return Card(
              child: ListTile(
                title: Text(o['name'], style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${o['partner']}\n${o['date']}'),
                isThreeLine: true,
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  StatusChip(st.label, st.color),
                  const SizedBox(height: 6),
                  Text(money(o['amount_total'], o['currency']), style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: o['id'], startReturn: returnMode))),
              ),
            );
          },
        ),
      );
}

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  final bool startReturn;
  const OrderDetailScreen({super.key, required this.orderId, this.startReturn = false});
  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  final Map<int, double> _ret = {};
  late bool _returning;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _returning = widget.startReturn;
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async => Map<String, dynamic>.from(
      (await context.read<AppState>().call('orders/detail', {'order_id': widget.orderId}))['order']);

  Future<void> _submitReturn() async {
    setState(() => _busy = true);
    try {
      final r = await context.read<AppState>().call('orders/return', {
        'order_id': widget.orderId,
        'lines': [for (final e in _ret.entries) {'product_id': e.key, 'qty': e.value}],
      });
      if (!mounted) return;
      showMsg(context, 'Return done: ${(r['returns'] as List).join(', ')}');
      setState(() {
        _ret.clear();
        _returning = false;
        _future = _load();
      });
    } catch (e) {
      if (mounted) showMsg(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return ErrorView(snap.error!, () => setState(() => _future = _load()));
          final o = snap.data!;
          final st = orderState(o['state']);
          final confirmed = o['state'] == 'sale' || o['state'] == 'done';
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Expanded(child: Text(o['name'], style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
              StatusChip(st.label, st.color),
            ]),
            Text('${o['partner']}  •  ${o['date']}'),
            const SizedBox(height: 16),
            for (final l in (o['lines'] as List))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('Qty ${l['qty']}  •  Delivered ${l['delivered']}'),
                      Text(money(l['subtotal'], cur), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ]),
                    if (_returning && (l['delivered'] as num) > 0)
                      Row(children: [
                        const Text('Return qty:'),
                        IconButton(onPressed: () => setState(() => _ret[l['product_id']] = ((_ret[l['product_id']] ?? 0) - 1).clamp(0, (l['delivered'] as num).toDouble()).toDouble()), icon: const Icon(Icons.remove_circle_outline)),
                        Text('${(_ret[l['product_id']] ?? 0).toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        IconButton(onPressed: () => setState(() => _ret[l['product_id']] = ((_ret[l['product_id']] ?? 0) + 1).clamp(0, (l['delivered'] as num).toDouble()).toDouble()), icon: const Icon(Icons.add_circle)),
                      ]),
                  ]),
                ),
              ),
            const Divider(height: 28),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total'),
              Text(money(o['amount_total'], cur), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 20),
            if (confirmed && !_returning)
              OutlinedButton.icon(onPressed: () => setState(() => _returning = true), icon: const Icon(Icons.assignment_return), label: const Text('Return products')),
            if (_returning)
              FilledButton.icon(
                onPressed: _busy || _ret.values.every((v) => v <= 0) ? null : _submitReturn,
                icon: const Icon(Icons.check),
                label: const Text('Confirm Return to My Stock'),
              ),
          ]);
        },
      ),
    );
  }
}
