import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../core/location.dart';
import '../widgets/common.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Customers')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCustomerScreen())),
          icon: const Icon(Icons.person_add),
          label: const Text('New'),
        ),
        body: ApiList(
          path: 'customers',
          resultKey: 'customers',
          searchable: true,
          emptyText: 'No customers yet.',
          itemBuilder: (c, p) => Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(p['name']),
              subtitle: Text([p['phone'], p['city']].where((e) => e.toString().isNotEmpty).join(' • ')),
              trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Icon(p['has_location'] == true ? Icons.location_on : Icons.location_off, color: p['has_location'] == true ? Colors.green : Colors.red, size: 20),
                if ((p['balance'] as num) > 0) Text(money(p['balance'], c.read<AppState>().currency), style: const TextStyle(color: Colors.red, fontSize: 12)),
              ]),
            ),
          ),
        ),
      );
}

class CreateCustomerScreen extends StatefulWidget {
  const CreateCustomerScreen({super.key});
  @override
  State<CreateCustomerScreen> createState() => _CreateCustomerScreenState();
}

class _CreateCustomerScreenState extends State<CreateCustomerScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  double? _lat, _lng;
  bool _busy = false, _locating = false;

  Future<void> _capture() async {
    setState(() => _locating = true);
    try {
      final p = await LocationService.current();
      setState(() {
        _lat = p.latitude;
        _lng = p.longitude;
      });
    } catch (e) {
      if (mounted) showMsg(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await context.read<AppState>().call('customers/create', {
        'name': _name.text, 'phone': _phone.text, 'email': _email.text, 'street': _street.text, 'city': _city.text, 'lat': _lat, 'lng': _lng,
      });
      if (!mounted) return;
      showMsg(context, 'Customer created.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showMsg(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create Customer')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name *', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _street, decoration: const InputDecoration(labelText: 'Street', prefixIcon: Icon(Icons.signpost_outlined))),
          const SizedBox(height: 12),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city))),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(_lat == null ? Icons.location_off : Icons.location_on, color: _lat == null ? Colors.red : Colors.green),
              title: Text(_lat == null ? 'Location not set' : '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}'),
              subtitle: const Text('Stand at the customer\'s place and capture. Sales are only allowed near this point.'),
              trailing: _locating ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(onPressed: _capture, icon: const Icon(Icons.my_location)),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save')),
        ]),
      );
}
