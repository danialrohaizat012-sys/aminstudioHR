import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';

/// One inbox for every pending request, oldest first.
class ApprovalsScreen extends StatelessWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return DefaultTabController(
      length: ReqKind.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelulusan'),
          bottom: TabBar(
            tabs: [
              for (final k in ReqKind.values) Tab(text: '${k.label} (${store.pending(k).length})'),
            ],
          ),
        ),
        body: TabBarView(children: [
          for (final k in ReqKind.values) _Inbox(kind: k),
        ]),
      ),
    );
  }
}

class _Inbox extends StatelessWidget {
  const _Inbox({required this.kind});
  final ReqKind kind;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.pending(kind);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    if (list.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.done_all,
          title: 'Semua sudah selesai',
          message: 'Tiada permohonan ${kind.label.toLowerCase()} menunggu.',
        ),
      );
    }
    final small = kind == ReqKind.claim
        ? list.where((r) => r.amount <= smallClaim && r.empId != store.me?.id).toList()
        : <HrRequest>[];
    return PageList(children: [
      Text('Leret ke kanan untuk lulus, ke kiri untuk tolak.',
          style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      if (small.length > 1)
        FilledButton.tonalIcon(
          onPressed: () => _approveAll(context, small),
          icon: const Icon(Icons.done_all),
          label: Text('Lulus semua tuntutan bawah ${rm(smallClaim)} (${small.length})'),
        ),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const Divider(),
              ApprovalTile(list[i], showBalance: true, swipe: true),
            ],
          ]),
        ),
      ),
    ]);
  }

  static const smallClaim = 100.0;

  Future<void> _approveAll(BuildContext context, List<HrRequest> items) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final total = items.fold(0.0, (s, r) => s + r.amount);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Lulus ${items.length} tuntutan?'),
        content: Text('Jumlah ${rm(total)}. Setiap tuntutan bawah ${rm(smallClaim)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Lulus semua')),
        ],
      ),
    );
    if (ok != true) return;
    final done = <String>[];
    for (final r in items) {
      if (await store.decide(r.id, ReqStatus.approved) == null) done.add(r.id);
    }
    messenger.showSnackBar(SnackBar(
      content: Text('${done.length} tuntutan diluluskan'),
      action: SnackBarAction(
        label: 'Batal',
        onPressed: () async {
          for (final id in done) {
            await store.undoDecision(id);
          }
        },
      ),
    ));
  }
}
