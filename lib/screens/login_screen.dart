import 'package:material_ui/material_ui.dart';

import '../store.dart';
import '../widgets/common.dart';

/// Demo sign-in: pick an account. A production build replaces this with
/// email/password or SSO from the chosen backend.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final admins = store.activeEmployees.where((e) => e.isAdmin).toList();
    final staff = store.activeEmployees.where((e) => !e.isAdmin).toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
          children: [
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text('HR', style: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pejabat HR', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text(store.settings.name, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ]),
            ]),
            const SizedBox(height: 32),
            Text('Log masuk sebagai', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Versi demo: pilih akaun untuk mencuba. Data disimpan dalam peranti ini sahaja.',
                style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 16),
            _group(context, 'Pengurus HR', admins),
            const SizedBox(height: 12),
            _group(context, 'Pekerja', staff),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () async {
                  await store.resetDemo();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Data demo diset semula')));
                  }
                },
                child: const Text('Set semula data demo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _group(BuildContext context, String title, List employees) {
    final store = StoreScope.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        for (final e in employees)
          ListTile(
            leading: Avatar(e),
            title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${e.position} · ${e.dept}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => store.signIn(e.id),
          ),
      ]),
    );
  }
}
