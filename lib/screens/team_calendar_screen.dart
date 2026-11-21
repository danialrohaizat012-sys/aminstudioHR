import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'roster_screen.dart';

/// Month view of who is away and what is on: public holidays, leave
/// (approved and pending), jobs and roster changes.
class TeamCalendarScreen extends StatefulWidget {
  const TeamCalendarScreen({super.key});
  @override
  State<TeamCalendarScreen> createState() => _TeamCalendarScreenState();
}

class _TeamCalendarScreenState extends State<TeamCalendarScreen> {
  late String month = ym(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final p = month.split('-');
    final first = DateTime(int.parse(p[0]), int.parse(p[1]), 1);
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday-first grid
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();
    final today = ymd(store.now);

    return Scaffold(
      appBar: AppBar(title: const Text('Kalendar pasukan')),
      body: PageList(maxWidth: 900, children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => month = addMonths(month, -1)), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(monthLabel(month), textAlign: TextAlign.center, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          IconButton(onPressed: () => setState(() => month = addMonths(month, 1)), icon: const Icon(Icons.chevron_right)),
        ]),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              Row(children: [
                for (final d in const ['Isn', 'Sel', 'Rab', 'Kha', 'Jum', 'Sab', 'Ahd'])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(d, textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                    ),
                  ),
              ]),
              for (var r = 0; r < rows; r++)
                Row(children: [
                  for (var c = 0; c < 7; c++)
                    Expanded(
                      child: Builder(builder: (context) {
                        final n = r * 7 + c - lead + 1;
                        if (n < 1 || n > daysInMonth) return const SizedBox(height: 70);
                        return _DayCell(date: '$month-${two(n)}', isToday: '$month-${two(n)}' == today);
                      }),
                    ),
                ]),
            ]),
          ),
        ),
        Wrap(spacing: 14, runSpacing: 6, children: [
          _legend(context, statusColors(context, 'bad').fg, 'Cuti umum'),
          _legend(context, statusColors(context, 'warn').fg, 'Cuti pekerja', Icons.luggage_outlined),
          _legend(context, cs.onSurface, 'Job', Icons.photo_camera_outlined),
          _legend(context, cs.outline, 'Kedai tutup'),
        ]),
        Text('Tekan tarikh untuk butiran: siapa cuti, job, dan syif yang berubah.',
            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _legend(BuildContext context, Color c, String label, [IconData? icon]) => Row(mainAxisSize: MainAxisSize.min, children: [
        icon != null ? Icon(icon, size: 14, color: c) : Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.date, required this.isToday});
  final String date;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final holiday = store.settings.holidays.contains(date);
    final closed = !store.isWorkday(parseYmd(date));
    final leave = _leaves(store, date);
    final jobs = store.jobs.where((j) => j.date == date).length;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _DaySheet(date: date),
      ),
      child: Container(
        height: 70,
        margin: const EdgeInsets.all(1.5),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: closed && !holiday ? cs.surfaceContainer : null,
          borderRadius: BorderRadius.circular(10),
          border: isToday ? Border.all(color: cs.primary, width: 2) : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${int.parse(date.substring(8))}',
              style: t.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700, color: holiday ? statusColors(context, 'bad').fg : null)),
          const Spacer(),
          Wrap(spacing: 3, runSpacing: 2, children: [
            if (holiday) _dot(statusColors(context, 'bad').fg),
            if (leave.isNotEmpty) _count(context, statusColors(context, 'warn'), Icons.luggage_outlined, leave.length),
            if (jobs > 0) _count(context, (bg: cs.primaryContainer, fg: cs.onPrimaryContainer), Icons.photo_camera_outlined, jobs),
          ]),
        ]),
      ),
    );
  }

  Widget _dot(Color c) => Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _count(BuildContext context, ({Color bg, Color fg}) c, IconData icon, int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(6)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: c.fg),
          if (n > 1) Text('$n', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.fg, fontWeight: FontWeight.w700, fontSize: 10)),
        ]),
      );
}

List<HrRequest> _leaves(HrStore store, String date) => store.requests
    .where((r) =>
        r.kind == ReqKind.leave &&
        r.status != ReqStatus.rejected &&
        r.from!.compareTo(date) <= 0 &&
        r.to!.compareTo(date) >= 0)
    .toList();

class _DaySheet extends StatelessWidget {
  const _DaySheet({required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final holiday = store.settings.holidayNames[date] ?? (store.settings.holidays.contains(date) ? 'Cuti umum' : null);
    final leave = _leaves(store, date);
    final jobs = store.jobs.where((j) => j.date == date).toList();
    final changes = [
      for (final e in store.staff)
        if (store.roster.containsKey('${e.id}_$date')) (e, store.shiftFor(e.id, date)),
    ];
    Widget head(String s) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Text(s, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .55,
      maxChildSize: .9,
      builder: (_, controller) => ListView(controller: controller, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Text(longDate(parseYmd(date)), style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        if (holiday != null) Padding(padding: const EdgeInsets.only(top: 6), child: Tag(holiday, tone: 'bad')),
        if (!store.isWorkday(parseYmd(date)) && holiday == null)
          const Padding(padding: EdgeInsets.only(top: 6), child: Tag('Kedai tutup')),
        head('Cuti (${leave.length})'),
        if (leave.isEmpty) const QuietText('Semua staf bekerja.'),
        for (final r in leave)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Avatar(store.employeeById(r.empId)),
            title: Text(store.nameOf(r.empId)),
            subtitle: Text(requestTitle(r)),
            trailing: StatusChip(r.status),
          ),
        head('Job (${jobs.length})'),
        if (jobs.isEmpty) const QuietText('Tiada job direkod.'),
        for (final j in jobs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.photo_camera_outlined, color: cs.primary),
            title: Text(j.title),
            subtitle: Text(j.staff.keys.map((id) => store.employeeById(id)?.firstName ?? '?').join(', ')),
          ),
        if (changes.isNotEmpty) ...[
          head('Syif berubah'),
          for (final (e, sh) in changes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Avatar(e),
              title: Text(e.name),
              trailing: sh == null
                  ? const Tag('Off')
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(color: shiftColor(context, sh.id), borderRadius: BorderRadius.circular(99)),
                      child: Text(sh.label, style: t.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
                    ),
            ),
        ],
      ]),
    );
  }
}
