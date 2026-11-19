import 'package:material_ui/material_ui.dart';

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
    final cs = Theme.of(context).colorScheme;
    if (list.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.done_all, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text('Tiada permohonan ${kind.label.toLowerCase()} menunggu.',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ]),
      );
    }
    return PageList(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const Divider(),
              ApprovalTile(list[i], showBalance: true),
            ],
          ]),
        ),
      ),
    ]);
  }
}
