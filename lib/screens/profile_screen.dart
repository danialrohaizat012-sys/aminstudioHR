import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../store.dart';
import '../widgets/common.dart';
import 'announcements_screen.dart';

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
              leading: const Icon(Icons.campaign_outlined),
              title: const Text('Pengumuman'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AnnouncementsScreen())),
            ),
            if (store.isAdmin) ...[
              const Divider(indent: 56),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Tetapan syarikat'),
                subtitle: Text('Waktu mula ${store.settings.startTime} · '
                    '${store.settings.weekendFriSat ? 'Jumaat & Sabtu' : 'Sabtu & Ahad'}'),
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController name;
  late TimeOfDay start;
  late bool friSat;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final s = StoreScope.of(context).settings;
    name = TextEditingController(text: s.name);
    final p = s.startTime.split(':');
    start = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    friSat = s.weekendFriSat;
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tetapan syarikat')),
      body: PageList(children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama syarikat')),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
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
            SwitchListTile(
              value: friSat,
              onChanged: (v) => setState(() => friSat = v),
              title: const Text('Hujung minggu Jumaat & Sabtu'),
              subtitle: const Text('Untuk Kelantan dan Terengganu'),
            ),
          ]),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () async {
            final s = store.settings
              ..name = name.text.trim()
              ..startTime = '${two(start.hour)}:${two(start.minute)}'
              ..weekendFriSat = friSat;
            final nav = Navigator.of(context);
            await store.updateSettings(s);
            nav.pop();
          },
          child: const Text('Simpan'),
        ),
      ]),
    );
  }
}
