import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import 'request_forms.dart';

/// Employee's own leave, claim and overtime history with a new-request button.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  ReqKind kind = ReqKind.leave;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.me!;
    final list = store.requestsOf(me.id, kind);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Permohonan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => switch (kind) {
          ReqKind.leave => showLeaveForm(context),
          ReqKind.claim => showClaimForm(context),
          ReqKind.overtime => showOvertimeForm(context),
        },
        icon: const Icon(Icons.add),
        label: Text('Mohon ${kind.label.toLowerCase()}'),
      ),
      body: PageList(children: [
        SegmentedButton<ReqKind>(
          segments: [for (final k in ReqKind.values) ButtonSegment(value: k, label: Text(k.label))],
          selected: {kind},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => kind = s.first),
        ),
        if (kind == ReqKind.leave)
          FigureStrip(items: [
            for (final type in const ['Cuti Tahunan', 'Cuti Sakit'])
              Figure(
                label: 'Baki ${type.toLowerCase()}',
                value: daysLabel(store.leaveBalance(me.id, type) ?? 0),
                note: 'daripada ${store.entitlement(me, type)} hari',
              ),
          ]),
        if (list.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Belum ada permohonan ${kind.label.toLowerCase()}.',
                  textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                _RequestRow(list[i]),
              ],
            ]),
          ),
      ]),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow(this.r);
  final HrRequest r;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
      title: Text(requestTitle(r), style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text([
        requestDetail(r),
        if (r.note.isNotEmpty) r.note,
        r.status == ReqStatus.pending ? 'dihantar ${ago(r.createdAt)}' : '${r.status.label.toLowerCase()} ${ago(r.decidedAt ?? r.createdAt)}',
        if (r.decisionNote.isNotEmpty) 'Pengurus: “${r.decisionNote}”',
      ].join('\n'), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      isThreeLine: true,
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        StatusChip(r.status),
        if (r.status == ReqStatus.pending)
          TextButton(
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Tarik balik permohonan?'),
                  content: Text('${requestTitle(r)} akan dipadam.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Tarik balik')),
                  ],
                ),
              );
              if (ok == true) await store.withdraw(r.id);
            },
            child: const Text('Tarik balik'),
          ),
      ]),
    );
  }
}
