import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';

List<Announcement> sortedAnnouncements(HrStore store) => [...store.announcements]
  ..sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.createdAt.compareTo(a.createdAt);
  });

class AnnouncementItem extends StatelessWidget {
  const AnnouncementItem(this.a, {super.key});
  final Announcement a;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(a.title, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
          if (a.pinned) Text('Disemat', style: t.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 2),
        Text(a.body, style: t.bodyMedium),
        const SizedBox(height: 2),
        Text(fmtDate(ymd(a.createdAt)), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = sortedAnnouncements(store);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengumuman')),
      floatingActionButton: store.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => showAnnouncementForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Pengumuman baru'),
            )
          : null,
      body: PageList(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: list.isEmpty
                ? const QuietText('Belum ada pengumuman.')
                : Column(children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const Divider(),
                      AnnouncementItem(list[i]),
                    ],
                  ]),
          ),
        ),
      ]),
    );
  }
}

Future<void> showAnnouncementForm(BuildContext context) {
  final title = TextEditingController();
  final body = TextEditingController();
  var pinned = false;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pengumuman baru', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'Tajuk')),
          const SizedBox(height: 12),
          TextField(controller: body, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Isi')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: pinned,
            onChanged: (v) => set(() => pinned = v),
            title: const Text('Sematkan di atas'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () async {
              if (title.text.trim().isEmpty || body.text.trim().isEmpty) return;
              await StoreScope.of(context).postAnnouncement(title.text.trim(), body.text.trim(), pinned);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Terbitkan'),
          ),
        ]),
      ),
    ),
  );
}
