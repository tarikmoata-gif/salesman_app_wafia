import 'package:flutter/material.dart';
import 'api.dart';
import 'geo.dart';

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

BoxDecoration box(BuildContext c) => BoxDecoration(
    color: isDark(c) ? const Color(0xFF1B1D24) : Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: isDark(c) ? Colors.white12 : Colors.black12));

const Map<String, Color> _sc = {'paid': Colors.green, 'sale': Colors.green, 'done': Colors.green, 'not_paid': Colors.red,
  'cancel': Colors.red, 'partial': Colors.orange, 'in_payment': Colors.blue, 'draft': Colors.grey};
const Map<String, String> _sl = {'not_paid': 'Not Paid', 'in_payment': 'In Payment', 'partial': 'Partial', 'paid': 'Paid',
  'sale': 'Sale', 'draft': 'Quotation', 'done': 'Done', 'cancel': 'Cancelled'};

class Pill extends StatelessWidget {
  final String s; const Pill(this.s, {super.key});
  @override Widget build(BuildContext c) {
    final col = _sc[s] ?? Colors.grey;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: col.withOpacity(.18), borderRadius: BorderRadius.circular(20)),
        child: Text(_sl[s] ?? s, style: TextStyle(color: col, fontSize: 12, fontWeight: FontWeight.w600)));
  }
}

class Fut<T> extends StatelessWidget {
  final Future<T> f; final Widget Function(T) b; const Fut(this.f, this.b, {super.key});
  @override Widget build(BuildContext c) => FutureBuilder<T>(future: f, builder: (c, s) {
    if (s.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('${s.error}')));
    if (!s.hasData) return const Center(child: CircularProgressIndicator());
    return b(s.data as T);
  });
}

Widget screen(String title, Widget body) => Scaffold(appBar: AppBar(title: Text(title), centerTitle: false), body: body);

Widget orderCard(BuildContext c, Map o) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14), decoration: box(c),
    child: Row(children: [
      const Icon(Icons.receipt_long), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(o['name'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), Text(o['partner'])])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Pill(o['state'] == 'sale' ? 'sale' : o['state']), const SizedBox(height: 6),
        Text('${(o['total'] as num).toStringAsFixed(2)} ${o['cur']}')]),
    ]));

class Qty extends StatelessWidget {
  final int v; final int? max; final ValueChanged<int> on; const Qty(this.v, this.on, {this.max, super.key});
  @override Widget build(BuildContext c) => Row(mainAxisSize: MainAxisSize.min, children: [
    IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: v > 0 ? () => on(v - 1) : null),
    Text('$v', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
    IconButton(icon: const Icon(Icons.add_circle), onPressed: (max == null || v < max!) ? () => on(v + 1) : null)]);
}

Widget prodImg(Map p) => Image.network('${Api.base}${p['img']}', headers: Api.headers, width: 56, height: 56,
    errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2, size: 40));

Future<String?> ask(BuildContext c, String title, String init) {
  final t = TextEditingController(text: init);
  return showDialog<String>(context: c, builder: (_) => AlertDialog(title: Text(title),
      content: TextField(controller: t, keyboardType: TextInputType.number),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, t.text), child: const Text('OK'))]));
}

// ---------------- My Orders ----------------
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});
  @override Widget build(BuildContext c) => screen('My Orders', Fut<List>(Api.orders(),
      (l) => ListView(padding: const EdgeInsets.all(16), children: [for (final o in l) orderCard(c, o)])));
}

// ---------------- Invoices / Register payment ----------------
class Invoices extends StatefulWidget { final bool pay; const Invoices({this.pay = false, super.key}); @override State<Invoices> createState() => _InvS(); }
class _InvS extends State<Invoices> {
  String? flt; late Future<List> f;
  static const filters = [['All States', null], ['Not Paid', 'not_paid'], ['Partial', 'partial'], ['Paid', 'paid'], ['In Payment', 'in_payment']];
  @override void initState() { super.initState(); flt = widget.pay ? 'not_paid' : null; f = Api.invoices(flt); }
  void load() => setState(() => f = Api.invoices(flt));

  Future<void> pay(Map i) async {
    if ((i['due'] as num) <= 0) return;
    final a = await ask(context, 'Register payment', (i['due'] as num).toString());
    final v = double.tryParse(a ?? '');
    if (v == null || v <= 0) return;
    try {
      final r = await Api.payment(i['id'], v);
      if (!mounted) return;
      toast(context, r['ok'] == true ? 'Payment registered' : r['error']);
      load();
    } catch (e) { if (mounted) toast(context, '$e'); }
  }

  @override Widget build(BuildContext c) => screen(widget.pay ? 'Register Payment' : 'Invoices', Column(children: [
    SizedBox(height: 56, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
      for (final x in filters) Padding(padding: const EdgeInsets.all(6), child: ChoiceChip(
          label: Text(x[0]!), selected: flt == x[1], onSelected: (_) { flt = x[1]; load(); }))])),
    Expanded(child: Fut<List>(f, (l) => ListView(padding: const EdgeInsets.all(16), children: [
      for (final i in l) InkWell(borderRadius: BorderRadius.circular(18), onTap: () => pay(i), child: Container(
          margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: box(c),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(i['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), Pill(i['state'])]),
            Text(i['partner']), const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total'),
                Text('${(i['total'] as num).toStringAsFixed(2)} ${i['cur']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))]),
              if ((i['due'] as num) > 0) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('Amount Due'),
                Text('${(i['due'] as num).toStringAsFixed(2)} ${i['cur']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.red))]),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(i['date']),
              Text('Due: ${i['due_date']}', style: const TextStyle(color: Colors.red))]),
          ])))]))),
  ]));
}

// ---------------- Customers ----------------
class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});
  @override Widget build(BuildContext c) => screen('Customers', Fut<List>(Api.customers(), (l) => ListView(
      padding: const EdgeInsets.all(16), children: [for (final m in l) Container(margin: const EdgeInsets.only(bottom: 10), decoration: box(c),
        child: ListTile(leading: const Icon(Icons.person), title: Text(m['name']),
            subtitle: Text((m['lat'] ?? 0) == 0 ? 'No location set' : 'Location set'),
            trailing: const Icon(Icons.add_shopping_cart),
            onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => NewOrder(custId: m['id'])))))])));
}

class CreateCustomer extends StatefulWidget { const CreateCustomer({super.key}); @override State<CreateCustomer> createState() => _CCS(); }
class _CCS extends State<CreateCustomer> {
  final n = TextEditingController(), p = TextEditingController(), e = TextEditingController(); bool busy = false;
  Future<void> save() async {
    if (n.text.trim().isEmpty) return toast(context, 'Name required');
    setState(() => busy = true);
    try {
      final pos = await currentPosition(); // customer location = where the salesman stands
      await Api.createCustomer({'name': n.text, 'phone': p.text, 'email': e.text, 'lat': pos.latitude, 'lng': pos.longitude});
      if (mounted) { toast(context, 'Customer created'); Navigator.pop(context); }
    } catch (x) { if (mounted) toast(context, '$x'); }
    if (mounted) setState(() => busy = false);
  }
  Widget f(String t, TextEditingController c) => Padding(padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: c, decoration: InputDecoration(labelText: t, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)))));
  @override Widget build(BuildContext c) => screen('Create Customer', ListView(padding: const EdgeInsets.all(16), children: [
    f('Name', n), f('Phone', p), f('Email', e),
    const Text('The customer location is saved from your current GPS position.'), const SizedBox(height: 16),
    FilledButton(onPressed: busy ? null : save, child: const Text('Save'))]));
}

// ---------------- Sales order ----------------
class NewOrder extends StatefulWidget { final int? custId; const NewOrder({this.custId, super.key}); @override State<NewOrder> createState() => _NOS(); }
class _NOS extends State<NewOrder> {
  List customers = [], stock = []; int? cid; final lines = <Map>[];
  String? status; bool near = false, busy = false; double? lat, lng;
  @override void initState() {
    super.initState(); cid = widget.custId;
    Api.stock().then((s) { if (mounted) setState(() => stock = s); });
    Api.customers().then((s) { if (mounted) { setState(() => customers = s); check(); } });
  }
  Future<void> check() async {
    final m = customers.cast<Map>().where((x) => x['id'] == cid).toList();
    if (m.isEmpty) return;
    try {
      final p = await currentPosition(); lat = p.latitude; lng = p.longitude;
      final cl = ((m.first['lat'] ?? 0) as num).toDouble(), cn = ((m.first['lng'] ?? 0) as num).toDouble();
      if (cl == 0 && cn == 0) { if (mounted) setState(() { near = false; status = 'Customer has no location in Odoo'; }); return; }
      final d = distanceM(lat!, lng!, cl, cn);
      if (mounted) setState(() { near = d <= maxMeters; status = near ? 'In range (${d.round()} m)' : 'Too far: ${d.round()} m (max ${maxMeters.round()} m)'; });
    } catch (e) { if (mounted) setState(() { near = false; status = '$e'; }); }
  }
  double get total => lines.fold(0.0, (s, l) => s + (l['p']['price'] as num) * l['qty'] * (1 - l['disc'] / 100));

  void addProduct() => showModalBottomSheet(context: context, builder: (_) => ListView(children: [
    for (final s in stock.where((s) => !lines.any((l) => l['p']['id'] == s['id']))) ListTile(
        leading: prodImg(s), title: Text(s['name']), subtitle: Text('Available ${s['qty']}'),
        onTap: () { Navigator.pop(context); setState(() => lines.add({'p': s, 'qty': 1, 'disc': 0.0})); })]));

  Future<void> submit() async {
    if (lines.isEmpty) return toast(context, 'Add at least one product');
    setState(() => busy = true);
    try {
      await check();
      final r = await Api.order(cid!, lat!, lng!, [for (final l in lines) {'product_id': l['p']['id'], 'qty': l['qty'], 'discount': l['disc']}]);
      if (!mounted) return;
      if (r['ok'] == true) { toast(context, 'Order ${r['name']} created'); Navigator.pop(context); } else { toast(context, r['error']); }
    } catch (e) { if (mounted) toast(context, '$e'); }
    if (mounted) setState(() => busy = false);
  }

  Widget line(Map l) {
    final p = l['p'];
    return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12), decoration: box(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(p['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => lines.remove(l)))]),
        Row(children: [
          Qty(l['qty'], (v) => setState(() => l['qty'] = v), max: (p['qty'] as num).floor()),
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(
              border: Border.all(color: Colors.black26), borderRadius: BorderRadius.circular(14)), child: Text(p['uom'])),
          const Spacer(), prodImg(p)]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          ActionChip(avatar: const Icon(Icons.sell_outlined, size: 18), label: Text('Discount ${l['disc']}%'), onPressed: () async {
            final v = double.tryParse(await ask(context, 'Discount %', '${l['disc']}') ?? '');
            if (v != null) setState(() => l['disc'] = v.clamp(0, 100));
          }),
          Text('${(p['price'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))]),
      ]));
  }

  @override Widget build(BuildContext c) => screen('Sales Orders', Column(children: [
    Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
      DropdownButtonFormField<int>(value: cid, isExpanded: true,
          decoration: InputDecoration(labelText: 'Customer', prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16))),
          items: [for (final m in customers) DropdownMenuItem<int>(value: m['id'], child: Text(m['name']))],
          onChanged: (v) { setState(() { cid = v; status = null; near = false; }); check(); }),
      if (status != null) Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: (near ? Colors.green : Colors.red).withOpacity(.15), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [Icon(near ? Icons.location_on : Icons.location_off, color: near ? Colors.green : Colors.red),
            const SizedBox(width: 8), Expanded(child: Text(status!)), IconButton(onPressed: check, icon: const Icon(Icons.refresh))])),
      const SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Order Lines', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        TextButton.icon(onPressed: addProduct, icon: const Icon(Icons.add), label: const Text('Add product'))]),
      for (final l in lines) line(l),
    ])),
    Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      Text('Total ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)), const Spacer(),
      FilledButton(onPressed: (cid == null || !near || busy) ? null : submit, child: const Text('Create Order'))])),
  ]));
}

// ---------------- Return product ----------------
class ReturnProduct extends StatelessWidget {
  const ReturnProduct({super.key});
  @override Widget build(BuildContext c) => screen('Return Product', Fut<List>(Api.orders(), (l) => ListView(padding: const EdgeInsets.all(16), children: [
    for (final o in l.where((o) => o['state'] == 'sale' || o['state'] == 'done')) InkWell(
        onTap: () => Navigator.push(c, MaterialPageRoute(builder: (_) => ReturnLines(o))), child: orderCard(c, o))])));
}

class ReturnLines extends StatefulWidget { final Map o; const ReturnLines(this.o, {super.key}); @override State<ReturnLines> createState() => _RLS(); }
class _RLS extends State<ReturnLines> {
  final q = <int, int>{}; late Future<List> f = Api.orderLines(widget.o['id']);
  Future<void> go() async {
    final ls = [for (final e in q.entries) if (e.value > 0) {'product_id': e.key, 'qty': e.value}];
    if (ls.isEmpty) return toast(context, 'Choose quantities');
    try {
      final r = await Api.returnProducts(widget.o['id'], ls);
      if (!mounted) return;
      if (r['ok'] == true) { toast(context, 'Return ${r['picking']} done'); Navigator.pop(context); } else { toast(context, r['error']); }
    } catch (e) { if (mounted) toast(context, '$e'); }
  }
  @override Widget build(BuildContext c) => screen('Return ${widget.o['name']}', Column(children: [
    Expanded(child: Fut<List>(f, (l) => ListView(children: [for (final x in l) ListTile(title: Text(x['name']), subtitle: Text('Delivered ${x['qty']}'),
        trailing: Qty(q[x['product_id']] ?? 0, (v) => setState(() => q[x['product_id']] = v), max: (x['qty'] as num).floor()))]))),
    Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: FilledButton(onPressed: go, child: const Text('Return')))),
  ]));
}

// ---------------- Request products ----------------
class RequestProducts extends StatefulWidget { const RequestProducts({super.key}); @override State<RequestProducts> createState() => _RPS(); }
class _RPS extends State<RequestProducts> {
  final q = <int, int>{}; late Future<List> f = Api.catalog();
  Future<void> go() async {
    final ls = [for (final e in q.entries) if (e.value > 0) {'product_id': e.key, 'qty': e.value}];
    if (ls.isEmpty) return toast(context, 'Choose quantities');
    try {
      final r = await Api.requestStock(ls);
      if (mounted) { toast(context, 'Request ${r['name']} sent'); Navigator.pop(context); }
    } catch (e) { if (mounted) toast(context, '$e'); }
  }
  @override Widget build(BuildContext c) => screen('Request Products', Column(children: [
    Expanded(child: Fut<List>(f, (l) => ListView(children: [for (final x in l) ListTile(leading: prodImg(x), title: Text(x['name']),
        subtitle: Text('Warehouse: ${x['qty']}'), trailing: Qty(q[x['id']] ?? 0, (v) => setState(() => q[x['id']] = v)))]))),
    Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: FilledButton(onPressed: go, child: const Text('Send Request')))),
  ]));
}
