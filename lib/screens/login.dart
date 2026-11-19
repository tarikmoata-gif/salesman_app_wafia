import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_state.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _url = TextEditingController();
  final _db = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>();
    _url.text = s.serverUrl;
    _db.text = s.db;
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await context.read<AppState>().login(_url.text, _db.text, _user.text, _pass.text);
    } catch (e) {
      if (mounted) showMsg(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Icon(Icons.local_shipping_outlined, size: 64, color: cs.primary),
                const SizedBox(height: 12),
                Text('Salesman', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                Text('Sign in to your Odoo account', textAlign: TextAlign.center, style: TextStyle(color: cs.outline)),
                const SizedBox(height: 28),
                TextField(controller: _url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Server URL', hintText: 'https://erp.example.com', prefixIcon: Icon(Icons.dns_outlined))),
                const SizedBox(height: 12),
                TextField(controller: _db, decoration: const InputDecoration(labelText: 'Database', prefixIcon: Icon(Icons.storage_outlined))),
                const SizedBox(height: 12),
                TextField(controller: _user, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Login', prefixIcon: Icon(Icons.person_outline))),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: _hide,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(icon: Icon(_hide ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _hide = !_hide)),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
