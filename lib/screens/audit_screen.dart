import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../store.dart';
import '../widgets/common.dart';

/// Every manager action with who and when: approvals, salary changes,
/// attendance corrections, settings, PIN resets.
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});
  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ql = q.toLowerCase();
    final list = store.audit
        .where((a) => ql.isEmpty || '${a.action} ${a.detail} ${a.by}'.toLowerCase().contains(ql))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Log audit')),
      body: PageList(children: [
        SearchBar(
          hintText: 'Cari tindakan, nama atau butiran',
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(cs.surface),
          side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant)),
          onChanged: (v) => setState(() => q = v),
        ),
        if (list.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Tiada rekod. Setiap kelulusan, perubahan gaji, pembetulan kehadiran dan tetapan akan direkod di sini.',
                  textAlign: TextAlign.center),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                ListTile(
                  title: Text(list[i].action, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [if (list[i].detail.isNotEmpty) list[i].detail, '${list[i].by} · ${fmtDate(ymd(list[i].at))} ${hm(list[i].at)}']
                        .join('\n'),
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  isThreeLine: list[i].detail.isNotEmpty,
                ),
              ],
            ]),
          ),
        Text('Log disimpan bersama data app (500 rekod terkini).',
            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
