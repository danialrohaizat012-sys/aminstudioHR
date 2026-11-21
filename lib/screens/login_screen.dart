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
                const Row(children: [
                  Expanded(child: Align(alignment: Alignment.centerLeft, child: BrandLockup(markSize: 56))),
                  ThemeToggleButton(),
                ]),
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
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Set semula data demo?'),
                          content: const Text(
                              'Semua pekerja, kehadiran, permohonan, gaji dan PIN dalam peranti ini akan dipadam dan diganti dengan data contoh.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Set semula')),
                          ],
                        ),
                      );
                      if (ok != true) return;
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
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                    label: const Text('Mula syarikat baharu (guna sebenar)'),
                    onPressed: () => _startFresh(context),
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

  Future<void> _startFresh(BuildContext context) async {
    final store = StoreScope.of(context);
    final company = TextEditingController(text: 'Amin Photo Studio');
    final manager = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mula syarikat baharu'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Semua data demo dalam peranti ini akan dipadam. Anda akan jadi pengurus pertama, '
              'cipta PIN, kemudian dibimbing untuk isi tetapan dan import pekerja.'),
          const SizedBox(height: 14),
          TextField(controller: company, decoration: const InputDecoration(labelText: 'Nama syarikat')),
          const SizedBox(height: 10),
          TextField(controller: manager, autofocus: true, decoration: const InputDecoration(labelText: 'Nama penuh anda (pengurus)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (manager.text.trim().isEmpty || company.text.trim().isEmpty) return;
              Navigator.pop(c, true);
            },
            child: const Text('Mula'),
          ),
        ],
      ),
    );
    if (ok == true) await store.startFresh(manager.text, company.text);
    company.dispose();
    manager.dispose();
  }
}
