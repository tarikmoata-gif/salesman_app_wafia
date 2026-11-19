import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/location.dart';
import '../widgets/common.dart';
import 'pickers.dart';

class NewOrderScreen extends StatefulWidget {
  /// Optional pre-fill (used when turning a customer request into an order).
  final Map<String, dynamic>? customer;
  final List<Map<String, dynamic>> prefillLines;
  final int? requestId;
  const NewOrderScreen({super.key, this.customer, this.prefillLines = const [], this.requestId});
  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

enum _Geo { unknown, checking, ok, far, noCustomerLocation, error }

class _NewOrderScreenState extends State<NewOrderScreen> {
  Map<String, dynamic>? _customer;
  final List<Map<String, dynamic>> _lines = []; // product, qty, discount
  _Geo _geo = _Geo.unknown;
  String _geoMsg = '';
  double? _lat, _lng, _acc, _dist;
  bool _mocked = false;
  bool _confirm = true;
  bool _invoice = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.customer != null) {
      _customer = widget.customer;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkLocation());
    }
    _prefill();
  }

  Future<void> _prefill() async {
    if (widget.prefillLines.isEmpty || _customer == null) return;
    try {
      final r = await context.read<AppState>().call('products', {'partner_id': _customer!['id'], 'limit': 200});
      final byId = {for (final p in r['products']) p['id']: Map<String, dynamic>.from(p)};
      setState(() {
        for (final l in widget.prefillLines) {
          final p = byId[l['product_id']];
          if (p != null) _lines.add({'product': p, 'qty': (l['qty'] as num).toDouble(), 'discount': 0.0});
        }
      });
    } catch (_) {}
  }

  Future<void> _pickCustomer() async {
    final c = await pickCustomer(context);
    if (c == null) return;
    setState(() {
      _customer = c;
      _lines.clear(); // prices depend on the customer's pricelist
    });
    _checkLocation();
  }

  /// Client-side distance check (the server enforces it again on submit).
  Future<void> _checkLocation() async {
    final s = context.read<AppState>();
    final c = _customer;
    if (c == null) return;
    if (!s.geofenceEnabled) {
      setState(() => _geo = _Geo.ok);
      return;
    }
    setState(() {
      _geo = _Geo.checking;
      _geoMsg = 'Getting your location…';
    });
    try {
      final pos = await LocationService.current();
      _lat = pos.latitude;
      _lng = pos.longitude;
      _acc = pos.accuracy;
      _mocked = pos.isMocked;
      if (_mocked) {
        setState(() {
          _geo = _Geo.error;
          _geoMsg = 'Mock location detected. Disable fake GPS apps.';
        });
        return;
      }
      if (c['has_location'] != true) {
        setState(() {
          _geo = _Geo.noCustomerLocation;
          _geoMsg = 'This customer has no location in Odoo. Ask the office to set it.';
        });
        return;
      }
      _dist = LocationService.distance(_lat!, _lng!, (c['lat'] as num).toDouble(), (c['lng'] as num).toDouble());
      final r = s.geofenceRadius;
      setState(() {
        if (_dist! <= r) {
          _geo = _Geo.ok;
          _geoMsg = 'You are ${_dist!.round()} m from the customer.';
        } else {
          _geo = _Geo.far;
          _geoMsg = 'You are ${_dist!.round()} m away. You must be within ${r.round()} m to sell.';
        }
      });
    } catch (e) {
      setState(() {
        _geo = _Geo.error;
        _geoMsg = e.toString();
      });
    }
  }

  Future<void> _addProduct() async {
    final p = await pickProduct(context, partnerId: _customer?['id']);
    if (p == null) return;
    final i = _lines.indexWhere((l) => l['product']['id'] == p['id']);
    setState(() {
      if (i >= 0) {
        _changeQty(i, 1);
      } else {
        _lines.add({'product': p, 'qty': 1.0, 'discount': 0.0});
      }
    });
  }

  void _changeQty(int i, double delta) {
    final p = _lines[i]['product'];
    final max = (p['qty'] as num).toDouble();
    final q = (_lines[i]['qty'] as double) + delta;
    if (q <= 0) {
      setState(() => _lines.removeAt(i));
      return;
    }
    if (p['storable'] == true && q > max) {
      showMsg(context, 'Only ${max.toStringAsFixed(0)} in your stock.', error: true);
      return;
    }
    setState(() => _lines[i]['qty'] = q);
  }

  Future<void> _editDiscount(int i) async {
    final max = context.read<AppState>().maxDiscount;
    final ctrl = TextEditingController(text: (_lines[i]['discount'] as double).toString());
    final v = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discount %'),
        content: TextField(controller: ctrl, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(helperText: 'Maximum ${max.toStringAsFixed(0)}%')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(90, 40)), onPressed: () => Navigator.pop(c, double.tryParse(ctrl.text) ?? 0), child: const Text('OK')),
        ],
      ),
    );
    if (v == null) return;
    if (v < 0 || v > max) {
      if (mounted) showMsg(context, 'Discount must be between 0 and ${max.toStringAsFixed(0)}%.', error: true);
      return;
    }
    setState(() => _lines[i]['discount'] = v);
  }

  double get _total => _lines.fold(0.0, (t, l) => t + (l['product']['price'] as num) * (l['qty'] as double) * (1 - (l['discount'] as double) / 100));

  bool get _canSubmit => _customer != null && _lines.isNotEmpty && !_busy && (_geo == _Geo.ok);

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      // Fresh fix right before sending, so the server sees the current position.
      if (context.read<AppState>().geofenceEnabled) {
        await _checkLocation();
        if (_geo != _Geo.ok) {
          setState(() => _busy = false);
          return;
        }
      }
      final r = await context.read<AppState>().call('orders/create', {
        'partner_id': _customer!['id'],
        'lines': [for (final l in _lines) {'product_id': l['product']['id'], 'qty': l['qty'], 'discount': l['discount']}],
        'lat': _lat,
        'lng': _lng,
        'accuracy': _acc,
        'is_mocked': _mocked,
        'confirm': _confirm,
        'invoice': _confirm && _invoice,
        if (widget.requestId != null) 'request_id': widget.requestId,
      });
      if (!mounted) return;
      showMsg(context, 'Order ${r['order']['name']} created.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showMsg(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New Sales Order')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Customer', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              InkWell(
                onTap: widget.customer == null ? _pickCustomer : null,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Customer', prefixIcon: Icon(Icons.person_outline)),
                  child: Text(_customer?['name'] ?? 'Tap to choose'),
                ),
              ),
              if (_customer != null) ...[const SizedBox(height: 10), _geoBanner(cs)],
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('Order Lines', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
          TextButton.icon(onPressed: _customer == null ? null : _addProduct, icon: const Icon(Icons.add), label: const Text('Add product')),
        ]),
        if (_lines.isEmpty) const EmptyView('Add products from your stock.'),
        for (var i = 0; i < _lines.length; i++) _lineCard(i, cur),
        if (_lines.isNotEmpty) ...[
          const Divider(height: 28),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total (before tax)', style: TextStyle(fontSize: 16)),
            Text(money(_total, cur), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Confirm order & deliver from my stock'), value: _confirm, onChanged: (v) => setState(() => _confirm = v)),
          if (_confirm) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Create invoice'), value: _invoice, onChanged: (v) => setState(() => _invoice = v)),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _canSubmit ? _submit : null,
          icon: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
          label: Text(_confirm ? 'Confirm Sale' : 'Save Quotation'),
        ),
        if (_customer != null && _geo != _Geo.ok)
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('Selling is disabled until you are at the customer location.', textAlign: TextAlign.center, style: TextStyle(color: cs.outline, fontSize: 12))),
      ]),
    );
  }

  Widget _geoBanner(ColorScheme cs) {
    late Color color;
    late IconData icon;
    switch (_geo) {
      case _Geo.ok:
        color = Colors.green;
        icon = Icons.location_on;
        break;
      case _Geo.checking:
        color = Colors.blue;
        icon = Icons.my_location;
        break;
      default:
        color = Colors.red;
        icon = Icons.location_off;
    }
    final text = _geo == _Geo.ok && _geoMsg.isEmpty ? 'Location check passed.' : _geoMsg;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        _geo == _Geo.checking ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        IconButton(visualDensity: VisualDensity.compact, onPressed: _checkLocation, icon: const Icon(Icons.refresh), tooltip: 'Recheck location'),
      ]),
    );
  }

  Widget _lineCard(int i, String cur) {
    final l = _lines[i];
    final p = l['product'];
    final qty = l['qty'] as double;
    return Dismissible(
      key: ValueKey('line-${p['id']}'),
      direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (_) => setState(() => _lines.removeAt(i)),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Row(children: [
                  IconButton(onPressed: () => _changeQty(i, -1), icon: const Icon(Icons.remove_circle_outline)),
                  Text(qty.toStringAsFixed(qty % 1 == 0 ? 1 : 2), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
                  IconButton(onPressed: () => _changeQty(i, 1), icon: const Icon(Icons.add_circle)),
                  Chip(label: Text(p['uom'].toString()), visualDensity: VisualDensity.compact),
                ]),
                ActionChip(avatar: const Icon(Icons.sell_outlined, size: 18), label: Text('Discount ${(l['discount'] as double).toStringAsFixed(1)}%'), onPressed: () => _editDiscount(i)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              productThumb(p['image'], size: 54),
              const SizedBox(height: 6),
              Text(money(p['price'], cur), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13)),
            ]),
          ]),
        ),
      ),
    );
  }
}
