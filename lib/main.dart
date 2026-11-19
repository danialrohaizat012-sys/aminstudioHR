import 'package:material_ui/material_ui.dart';

import 'screens/login_screen.dart';
import 'screens/shell.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = HrStore();
  await store.load();
  runApp(PejabatHrApp(store: store));
}

class PejabatHrApp extends StatelessWidget {
  const PejabatHrApp({super.key, required this.store});
  final HrStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: MaterialApp(
        title: 'Amin Studio HR',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (!store.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: store.me == null ? const LoginScreen() : Shell(key: ValueKey(store.currentUserId)),
    );
  }
}
