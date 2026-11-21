import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../store.dart';
import '../widgets/common.dart';
import 'announcements_screen.dart';
import 'audit_screen.dart';
import 'punch_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.me!;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Widget kv(String k, String v) => ListTile(
          dense: true,
          title: Text(k, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          subtitle: Text(v.isEmpty ? '—' : v, style: t.bodyLarge),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: PageList(children: [
        Row(children: [
          Avatar(me, radius: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(me.name, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text('${me.position} · ${me.dept}', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
        ]),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            kv('Syarikat', store.settings.name),
            kv('Mula kerja', '${fmtDate(ymd(me.joinDate))} · ${tenure(me.joinDate)}'),
            kv('Emel', me.email),
            kv('Telefon', me.phone),
            kv('Bank', '${me.bank} ${me.bankAcc}'.trim()),
          ]),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.password_outlined),
              title: const Text('Tukar PIN'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _changePin(context),
            ),
            const Divider(indent: 56),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('Pengumuman'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnnouncementsScreen())),
            ),
            if (store.isAdmin) ...[
              const Divider(indent: 56),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Log audit'),
                subtitle: Text('${store.audit.length} rekod tindakan pengurus'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuditScreen())),
              ),
              const Divider(indent: 56),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Tetapan syarikat'),
                subtitle: Text('Waktu mula ${store.settings.startTime} · '
                    '${store.settings.hasOffice ? 'radius ${store.settings.radiusM.round()} m' : 'lokasi kedai belum ditetapkan'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
            ],
          ]),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: store.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Log keluar'),
        ),
      ]),
    );
  }
}

Future<void> _changePin(BuildContext context) async {
  final store = StoreScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final old = TextEditingController(), next = TextEditingController(), again = TextEditingController();
  String? error;
  await showDialog<void>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) {
        InputDecoration dec(String l) => InputDecoration(labelText: l, counterText: '');
        Widget f(TextEditingController ctl, String l) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: ctl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: dec(l),
              ),
            );
        return AlertDialog(
          title: const Text('Tukar PIN'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            f(old, 'PIN semasa'),
            f(next, 'PIN baharu (6 digit)'),
            f(again, 'Ulang PIN baharu'),
            if (error != null) Text(error!, style: TextStyle(color: Theme.of(c).colorScheme.error)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                if (next.text != again.text) {
                  set(() => error = 'PIN baharu tidak sama.');
                  return;
                }
                final err = await store.changePin(old.text, next.text);
                if (err != null) {
                  set(() => error = err);
                  return;
                }
                if (c.mounted) Navigator.pop(c);
                messenger.showSnackBar(const SnackBar(content: Text('PIN ditukar')));
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController name;
  late TimeOfDay start;
  late Set<int> weekend;
  bool _ready = false;

  static const _dayNames = ['Isn', 'Sel', 'Rab', 'Kha', 'Jum', 'Sab', 'Ahd'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final s = StoreScope.of(context).settings;
    name = TextEditingController(text: s.name);
    final p = s.startTime.split(':');
    start = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    weekend = {...s.weekendDays};
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget heading(String x) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(x, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Tetapan syarikat')),
      body: PageList(children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama syarikat')),
        heading('Waktu kerja'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ListTile(
              title: const Text('Waktu mula kerja'),
              subtitle: const Text('Punch masuk selepas waktu ini ditanda lewat'),
              trailing: Text('${two(start.hour)}:${two(start.minute)}', style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final v = await showTimePicker(context: context, initialTime: start);
                if (v != null) setState(() => start = v);
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hari tutup', style: t.bodyLarge),
                Text('Tidak dikira sebagai hari bekerja untuk cuti dan kehadiran', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(_dayNames[d - 1]),
                      selected: weekend.contains(d),
                      onSelected: (v) => setState(() => v ? weekend.add(d) : weekend.remove(d)),
                    ),
                ]),
              ]),
            ),
          ]),
        ),
        heading('Punch masuk'),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.where_to_vote_outlined),
            title: const Text('Tetapan punch'),
            subtitle: Text(s.hasOffice
                ? 'Radius ${s.radiusM.round()} m${s.requireSelfie ? ' · selfie wajib' : ''}'
                : 'Lokasi kedai belum ditetapkan'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PunchSettingsScreen())),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () async {
            final st = store.settings
              ..name = name.text.trim()
              ..startTime = '${two(start.hour)}:${two(start.minute)}'
              ..weekendDays = (weekend.toList()..sort());
            final nav = Navigator.of(context);
            await store.updateSettings(st);
            nav.pop();
          },
          child: const Text('Simpan'),
        ),
      ]),
    );
  }
}
