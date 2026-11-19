import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../widgets/common.dart';
import 'customers.dart';
import 'invoices.dart';
import 'new_order.dart';
import 'orders.dart';
import 'requests.dart';
import 'stock.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async =>
      Map<String, dynamic>.from(await context.read<AppState>().call('dashboard'));

  void _reload() => setState(() => _future = _load());

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _open(const NewOrderScreen()),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return ErrorView(snap.error!, _reload);
            final d = snap.data!;
            final cur = (d['currency'] ?? '').toString();
            final actions = <_Action>[
              _Action('My Orders', Icons.receipt_long, Colors.indigo, () => _open(const OrdersScreen())),
              _Action('Invoices', Icons.description_outlined, Colors.purple, () => _open(const InvoicesScreen())),
              _Action('Register Payment', Icons.credit_card, Colors.blueGrey, () => _open(const InvoicesScreen(initialState: 'not_paid', title: 'Register Payment'))),
              _Action('Return Product', Icons.assignment_return, Colors.green, () => _open(const OrdersScreen(returnMode: true))),
              _Action('Customers', Icons.groups, Colors.orange, () => _open(const CustomersScreen())),
              _Action('Create Customer', Icons.person_add_alt_1, Colors.blue, () => _open(const CreateCustomerScreen())),
              _Action('My Stock', Icons.warehouse_outlined, Colors.teal, () => _open(const StockScreen())),
              _Action('Request Products', Icons.inventory_2, Colors.red, () => _open(const StockRequestScreen())),
              _Action('Customer Requests', Icons.support_agent, Colors.deepOrange, () => _open(const CustomerRequestsScreen()), badge: d['open_requests'] ?? 0),
            ];
            return RefreshIndicator(
              onRefresh: () async {
                _reload();
                await _future;
              },
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text('${s.user?['name'] ?? ''}${s.meta['warehouse'] != null ? '  •  ${s.meta['warehouse']['name']}' : ''}', style: TextStyle(color: cs.outline)),
                    ]),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'logout') s.logout();
                      if (v == 'light') s.setTheme(ThemeMode.light);
                      if (v == 'dark') s.setTheme(ThemeMode.dark);
                      if (v == 'system') s.setTheme(ThemeMode.system);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'light', child: Text('Light theme')),
                      PopupMenuItem(value: 'dark', child: Text('Dark theme')),
                      PopupMenuItem(value: 'system', child: Text('System theme')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'logout', child: Text('Log out')),
                    ],
                  ),
                ]),
                const SizedBox(height: 16),
                SizedBox(
                  height: 108,
                  child: ListView(scrollDirection: Axis.horizontal, children: [
                    _StatCard(Icons.receipt_long, '${d['orders_today']}', "Today's Orders", Colors.indigo),
                    _StatCard(Icons.attach_money, money(d['revenue_today'] ?? 0, cur), "Today's Revenue", Colors.purple),
                    _StatCard(Icons.account_balance_wallet_outlined, money(d['receivables'] ?? 0, cur), 'Receivables', Colors.orange),
                    _StatCard(Icons.inventory_2_outlined, '${d['stock_items']}', 'Items in My Stock', Colors.teal),
                  ]),
                ),
                const SizedBox(height: 20),
                Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.95,
                  children: actions.map((a) => _ActionTile(a)).toList(),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Text('Recent Activity', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                  TextButton(onPressed: () => _open(const OrdersScreen()), child: const Text('See All')),
                ]),
                for (final o in (d['recent'] as List))
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.receipt_long),
                      title: Text(o['name']),
                      subtitle: Text(o['partner']),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                        StatusChip(orderState(o['state']).label, orderState(o['state']).color),
                        const SizedBox(height: 4),
                        Text(money(o['amount_total'], o['currency']), style: const TextStyle(fontSize: 12)),
                      ]),
                    ),
                  ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badge;
  _Action(this.label, this.icon, this.color, this.onTap, {this.badge = 0});
}

class _ActionTile extends StatelessWidget {
  final _Action a;
  const _ActionTile(this.a);
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: a.onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Badge(
            isLabelVisible: a.badge > 0,
            label: Text('${a.badge}'),
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(color: a.color.withOpacity(0.13), borderRadius: BorderRadius.circular(18), border: Border.all(color: a.color.withOpacity(0.25))),
              child: Icon(a.icon, color: a.color, size: 28),
            ),
          ),
          const SizedBox(height: 8),
          Text(a.label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12.5)),
        ]),
      );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final Color color;
  const _StatCard(this.icon, this.value, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(18),
          border: Border(left: BorderSide(color: color, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, color: color, size: 22),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
        ]),
      );
}
