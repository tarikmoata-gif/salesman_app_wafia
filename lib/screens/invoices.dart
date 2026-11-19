import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../widgets/common.dart';

class InvoicesScreen extends StatefulWidget {
  final String initialState;
  final String title;
  const InvoicesScreen({super.key, this.initialState = '', this.title = 'Invoices'});
  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late String _state = widget.initialState;
  final _listKey = GlobalKey<ApiListState>();
  static const _filters = {'': 'All States', 'not_paid': 'Not Paid', 'partial': 'Partial', 'paid': 'Paid', 'in_payment': 'In Payment'};

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(children: [
          SizedBox(
            height: 48,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              for (final e in _filters.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(label: Text(e.value), selected: _state == e.key, onSelected: (_) => setState(() => _state = e.key)),
                ),
            ]),
          ),
          Expanded(
            child: ApiList(
              key: _listKey,
              path: 'invoices',
              resultKey: 'invoices',
              params: {'state': _state},
              searchable: true,
              emptyText: 'No invoices.',
              itemBuilder: (c, m) {
                final ps = payState(m['payment_state']);
                final due = (m['amount_residual'] as num) > 0;
                final cur = m['currency'];
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: due
                        ? () async {
                            await Navigator.push(c, MaterialPageRoute(builder: (_) => PaymentScreen(invoice: m)));
                            _listKey.currentState?.reload();
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(m['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                          StatusChip(ps.label, ps.color),
                        ]),
                        Text(m['partner']),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Total', style: TextStyle(fontSize: 12)),
                            Text(money(m['amount_total'], cur), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ]),
                          if (due)
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              const Text('Amount Due', style: TextStyle(fontSize: 12)),
                              Text(money(m['amount_residual'], cur), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.red)),
                            ]),
                        ]),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(m['date'], style: const TextStyle(fontSize: 12)),
                          Text('Due: ${m['due']}', style: const TextStyle(fontSize: 12, color: Colors.red)),
                        ]),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      );
}

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;
  const PaymentScreen({super.key, required this.invoice});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final TextEditingController _amount = TextEditingController(text: (widget.invoice['amount_residual'] as num).toStringAsFixed(2));
  final _memo = TextEditingController();
  int? _journal;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final j = context.read<AppState>().meta['journals'] as List?;
    if (j != null && j.isNotEmpty) _journal = j.first['id'];
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    try {
      await context.read<AppState>().call('payments/register', {
        'invoice_id': widget.invoice['id'],
        'amount': double.tryParse(_amount.text) ?? 0,
        'journal_id': _journal,
        'memo': _memo.text,
      });
      if (!mounted) return;
      showMsg(context, 'Payment registered.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showMsg(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final journals = (context.watch<AppState>().meta['journals'] as List? ?? []);
    final inv = widget.invoice;
    return Scaffold(
      appBar: AppBar(title: const Text('Register Payment')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text(inv['name'], style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        Text(inv['partner']),
        const SizedBox(height: 4),
        Text('Amount due: ${money(inv['amount_residual'], inv['currency'])}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.payments_outlined))),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _journal,
          decoration: const InputDecoration(labelText: 'Payment method', prefixIcon: Icon(Icons.account_balance_outlined)),
          items: [for (final j in journals) DropdownMenuItem<int>(value: j['id'], child: Text(j['name']))],
          onChanged: (v) => setState(() => _journal = v),
        ),
        const SizedBox(height: 12),
        TextField(controller: _memo, decoration: const InputDecoration(labelText: 'Memo (optional)', prefixIcon: Icon(Icons.notes))),
        const SizedBox(height: 24),
        FilledButton(onPressed: _busy || _journal == null ? null : _pay, child: const Text('Register Payment')),
      ]),
    );
  }
}
