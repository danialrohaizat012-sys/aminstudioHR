import 'package:material_ui/material_ui.dart';

import '../store.dart';
import '../widgets/brand.dart';
import 'pin_sheet.dart';
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: MediaQuery.sizeOf(context).height > 760,
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
              children: [
                const BrandLockup(markSize: 56),
                const SizedBox(height: 32),
                Text('Log masuk sebagai',
                    style:
                        t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                    'Versi demo: pilih akaun dan masukkan PIN demo ${HrStore.demoPin}. Tukar PIN di Profil selepas log masuk.',
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
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Data demo diset semula')));
                      }
                    },
                    child: const Text('Set semula data demo'),
                  ),
                ),
              ],
            ),
          ),
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
            title: Text(e.name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${e.position} · ${e.dept}'),
            trailing: store.needsPin(e.id)
                ? const Tag('Cipta PIN')
                : store.lockMinutesLeft(e.id) > 0
                    ? const Icon(Icons.lock_clock_outlined)
                    : const Icon(Icons.chevron_right),
            onTap: () => showPinSheet(context, e),
          ),
      ]),
    );
  }
}
