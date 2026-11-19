import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../widgets/common.dart';

/// Full-screen customer picker. Returns the selected customer map.
Future<Map<String, dynamic>?> pickCustomer(BuildContext context) {
  return Navigator.push<Map<String, dynamic>>(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Select Customer')),
        body: ApiList(
          path: 'customers',
          resultKey: 'customers',
          searchable: true,
          emptyText: 'No customers found.',
          itemBuilder: (c, p) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(p['name']),
              subtitle: Text(p['phone'].toString().isEmpty ? p['city'].toString() : p['phone']),
              trailing: p['has_location'] == true
                  ? const Icon(Icons.location_on, color: Colors.green)
                  : const Icon(Icons.location_off, color: Colors.red),
              onTap: () => Navigator.pop(c, p),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Product picker showing stock of the salesman's own warehouse.
Future<Map<String, dynamic>?> pickProduct(BuildContext context, {int? partnerId, bool onlyInStock = true}) {
  return Navigator.push<Map<String, dynamic>>(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Select Product')),
        body: ApiList(
          path: 'products',
          resultKey: 'products',
          params: {if (partnerId != null) 'partner_id': partnerId},
          searchable: true,
          emptyText: 'No products found.',
          itemBuilder: (c, p) {
            final qty = (p['qty'] as num).toDouble();
            final out = onlyInStock && qty <= 0;
            final cur = c.read<AppState>().currency;
            return Opacity(
              opacity: out ? 0.45 : 1,
              child: Card(
                child: ListTile(
                  leading: productThumb(p['image']),
                  title: Text(p['name']),
                  subtitle: Text(p['storable'] == true ? 'In my stock: ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)} ${p['uom']}' : p['uom'], style: TextStyle(color: out ? Colors.red : null)),
                  trailing: Text(money(p['price'], cur), style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: out ? null : () => Navigator.pop(c, p),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
