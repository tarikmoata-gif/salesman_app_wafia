import 'package:flutter/material.dart';
import 'api.dart';
import 'screens.dart';

const navy = Color(0xFF1B237E);

void main() => runApp(const App());

ThemeData _theme(Brightness b) {
  final dark = b == Brightness.dark;
  return ThemeData(
      useMaterial3: true, brightness: b,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3F4F94), brightness: b),
      scaffoldBackgroundColor: dark ? const Color(0xFF111318) : const Color(0xFFF8F8FF));
}

class App extends StatelessWidget {
  const App({super.key});
  @override Widget build(BuildContext c) => MaterialApp(
      title: 'Salesman', debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light), darkTheme: _theme(Brightness.dark), home: const Login());
}

class Login extends StatefulWidget { const Login({super.key}); @override State<Login> createState() => _LoginS(); }
class _LoginS extends State<Login> {
  final u = TextEditingController(text: 'https://'), d = TextEditingController(), l = TextEditingController(), p = TextEditingController();
  bool busy = false;
  Future<void> go() async {
    setState(() => busy = true);
    try {
      await Api.login(u.text, d.text, l.text, p.text);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Dashboard()));
    } catch (e) { if (mounted) toast(context, '$e'); }
    if (mounted) setState(() => busy = false);
  }
  Widget f(String t, TextEditingController c, {bool pw = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: c, obscureText: pw,
          decoration: InputDecoration(labelText: t, filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))));
  @override Widget build(BuildContext c) => Scaffold(
      backgroundColor: navy,
      body: SafeArea(child: ListView(padding: const EdgeInsets.all(24), children: [
        const SizedBox(height: 40),
        const Text('Salesman', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
        const Text('Sign in to your Odoo', style: TextStyle(color: Colors.white70, fontSize: 18)),
        const SizedBox(height: 32),
        f('Odoo URL', u), f('Database', d), f('Login', l), f('Password', p, pw: true),
        const SizedBox(height: 12),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00897B), padding: const EdgeInsets.all(16)),
            onPressed: busy ? null : go, child: Text(busy ? '...' : 'Sign in')),
      ])));
}

class Dashboard extends StatefulWidget { const Dashboard({super.key}); @override State<Dashboard> createState() => _DashS(); }
class _DashS extends State<Dashboard> {
  late Future<Map> f = Api.dashboard();
  void reload() => setState(() => f = Api.dashboard());
  Future<void> open(Widget w) async { await Navigator.push(context, MaterialPageRoute(builder: (_) => w)); reload(); }

  Widget stat(IconData i, String v, String t, Color col) => Container(
      width: 175, margin: const EdgeInsets.only(right: 12),
      decoration: box(context), clipBehavior: Clip.antiAlias,
      child: Row(children: [
        Container(width: 5, color: col),
        Expanded(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(i, color: col), const SizedBox(height: 6),
          Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          Text(t, style: const TextStyle(fontSize: 13)),
        ]))),
      ]));

  Widget tile(IconData i, String t, Color col, Widget w) => InkWell(
      borderRadius: BorderRadius.circular(16), onTap: () => open(w),
      child: SizedBox(width: 82, child: Column(children: [
        Container(width: 60, height: 60,
            decoration: BoxDecoration(color: col.withOpacity(.12), borderRadius: BorderRadius.circular(18),
                border: Border.all(color: col.withOpacity(.25))),
            child: Icon(i, color: col, size: 28)),
        const SizedBox(height: 6),
        Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      ])));

  @override Widget build(BuildContext c) => Scaffold(
      floatingActionButton: FloatingActionButton(onPressed: () => open(const NewOrder()), child: const Icon(Icons.add)),
      body: SafeArea(child: Fut<Map>(f, (d) {
        final cur = d['currency'];
        return RefreshIndicator(onRefresh: () async => reload(), child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Dashboard', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const Text('Sales, Receivables & Stock Details'),
          const SizedBox(height: 16),
          SizedBox(height: 120, child: ListView(scrollDirection: Axis.horizontal, children: [
            stat(Icons.receipt_long, '${d['orders']}', "Today's Orders", const Color(0xFF3F4F94)),
            stat(Icons.attach_money, '$cur ${(d['revenue'] as num).round()}', "Today's Revenue", const Color(0xFF7B3F61)),
            stat(Icons.account_balance_wallet, '$cur ${(d['receivables'] as num).round()}', 'Receivables', Colors.orange),
            stat(Icons.inventory_2, '${(d['stock'] as num).round()}', 'Units in Stock', Colors.teal),
          ])),
          const SizedBox(height: 20),
          const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 16, children: [
            tile(Icons.receipt_long, 'My Orders', const Color(0xFF3F4F94), const OrdersScreen()),
            tile(Icons.receipt, 'Invoices', const Color(0xFF7B3F61), const Invoices()),
            tile(Icons.credit_card, 'Register Payment', Colors.blueGrey, const Invoices(pay: true)),
            tile(Icons.assignment_return, 'Return Product', Colors.green, const ReturnProduct()),
            tile(Icons.people, 'Customers', Colors.orange, const CustomersScreen()),
            tile(Icons.person_add, 'Create Customer', Colors.blue, const CreateCustomer()),
            tile(Icons.inventory, 'Request Products', Colors.red, const RequestProducts()),
          ]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Recent Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            TextButton(onPressed: () => open(const OrdersScreen()), child: const Text('See All')),
          ]),
          for (final o in d['recent']) orderCard(context, o),
          const SizedBox(height: 80),
        ]));
      })));
}
