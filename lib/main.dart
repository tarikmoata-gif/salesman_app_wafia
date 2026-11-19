import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_state.dart';
import 'core/theme.dart';
import 'screens/home.dart';
import 'screens/login.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(ChangeNotifierProvider.value(value: state, child: const SalesmanApp()));
  state.init();
}

class SalesmanApp extends StatelessWidget {
  const SalesmanApp({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'Salesman',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: s.themeMode,
      home: !s.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : (s.loggedIn ? const HomeScreen() : const LoginScreen()),
    );
  }
}
