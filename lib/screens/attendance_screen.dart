import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../store.dart';
import '../widgets/common.dart';
import 'attendance_detail_screen.dart';
import 'employee_home.dart';
import 'roster_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late String month = ym(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.me!;
    final rows = store.attendanceOf(me.id, month);
    final done = rows.where((r) => r.clockOut != null).toList();
    final avg = done.isEmpty ? 0.0 : done.fold(0.0, (s, r) => s + hoursBetween(r.clockIn, r.clockOut)) / done.length;
    final late = rows.where(store.isLate).length;
    final isThisMonth = month == ym(store.now);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Kehadiran')),
      body: PageList(children: [
        if (isThisMonth) const PunchCard(),
        if (isThisMonth) MyScheduleCard(empId: me.id),
        Row(children: [
          IconButton(onPressed: () => setState(() => month = addMonths(month, -1)), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(monthLabel(month), textAlign: TextAlign.center, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          IconButton(
            onPressed: isThisMonth ? null : () => setState(() => month = addMonths(month, 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        FigureStrip(items: [
          Figure(label: 'Hadir', value: '${rows.length} hari'),
          Figure(label: 'Lewat', value: '$late', note: 'selepas ${store.settings.startTime}'),
          Figure(label: 'Purata', value: '${avg.toStringAsFixed(1)} jam', note: 'sehari'),
        ]),
        if (rows.isEmpty)
          const Card(
              child: EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'Tiada rekod bulan ini',
                  message: 'Rekod muncul selepas anda punch masuk.'))
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                ListTile(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AttendanceDetailScreen(empId: me.id, date: rows[i].date))),
                  title: Text(longDate(parseYmd(rows[i].date)), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${rows[i].clockIn ?? '—'}  →  ${rows[i].clockOut ?? 'belum keluar'}'
                      '${rows[i].breaks.isNotEmpty ? ' · ${rows[i].breaks.length} rehat' : ''}',
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (store.isLate(rows[i])) const Padding(padding: EdgeInsets.only(right: 6), child: Tag('Lewat', tone: 'warn')),
                    if (store.isEarlyLeave(rows[i]))
                      const Padding(padding: EdgeInsets.only(right: 6), child: Tag('Balik awal', tone: 'warn')),
                    Text(rows[i].clockIn == null ? '' : fmtMinutes(store.workedMinutes(rows[i])),
                        style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ],
            ]),
          ),
      ]),
    );
  }
}
