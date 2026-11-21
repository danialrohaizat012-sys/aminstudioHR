import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'attendance_detail_screen.dart';

/// Month view for HR and the owner: how many days each person was late
/// (and by how many minutes), absent, on leave, left early, and hours worked.
class AttendanceSummaryScreen extends StatefulWidget {
  const AttendanceSummaryScreen({super.key});
  @override
  State<AttendanceSummaryScreen> createState() => _AttendanceSummaryScreenState();
}

class _AttendanceSummaryScreenState extends State<AttendanceSummaryScreen> {
  late String month = ym(DateTime.now());
  bool byLate = true;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final rows = [for (final e in store.staff) (e, store.monthSummary(e, month))];
    rows.sort((a, b) => byLate
        ? (b.$2.late != a.$2.late ? b.$2.late - a.$2.late : b.$2.lateMinutes - a.$2.lateMinutes)
        : a.$1.name.compareTo(b.$1.name));
    final totalLate = rows.fold(0, (s, r) => s + r.$2.late);
    final totalAbsent = rows.fold(0, (s, r) => s + r.$2.absent);
    final workdays = rows.fold(0, (s, r) => s + r.$2.workdays);
    final present = rows.fold(0, (s, r) => s + r.$2.present);
    final isThisMonth = month == ym(store.now);

    return Scaffold(
      appBar: AppBar(title: const Text('Ringkasan bulanan')),
      body: PageList(children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => month = addMonths(month, -1)), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Column(children: [
              Text(monthLabel(month), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (isThisMonth) Text('setakat hari ini', style: t.bodySmall),
            ]),
          ),
          IconButton(
            onPressed: isThisMonth ? null : () => setState(() => month = addMonths(month, 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        FigureStrip(items: [
          Figure(label: 'Kes lewat', value: '$totalLate', note: 'semua pekerja'),
          Figure(label: 'Tiada rekod', value: '$totalAbsent', note: 'hari'),
          Figure(
            label: 'Kadar kehadiran',
            value: workdays == 0 ? '—' : '${(present / workdays * 100).round()}%',
            progress: workdays == 0 ? 0 : present / workdays,
          ),
          Figure(label: 'Waktu mula', value: store.settings.startTime, note: 'lewat selepas ini'),
        ]),
        Row(children: [
          Text('Susun:', style: t.bodyMedium),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Paling kerap lewat'),
            selected: byLate,
            showCheckmark: false,
            onSelected: (_) => setState(() => byLate = true),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Nama'),
            selected: !byLate,
            showCheckmark: false,
            onSelected: (_) => setState(() => byLate = false),
          ),
        ]),
        for (final (e, sum) in rows) _SummaryCard(emp: e, sum: sum, month: month),
        Text(
          'Lewat dikira bila punch masuk selepas ${store.settings.startTime} pada hari bekerja. '
          'Tiada rekod = hari bekerja tanpa punch dan tanpa cuti diluluskan.',
          style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ]),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.emp, required this.sum, required this.month});
  final Employee emp;
  final MonthSummary sum;
  final String month;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final warn = statusColors(context, sum.late >= 3 ? 'bad' : sum.late > 0 ? 'warn' : 'ok');

    Widget stat(String label, String value) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text(label, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _DaysSheet(emp: emp, sum: sum, month: month),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Avatar(emp, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(emp.name, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(sum.late == 0 ? 'Tiada lewat' : 'Jumlah ${fmtMinutes(sum.lateMinutes)} lewat',
                      style: t.bodySmall?.copyWith(color: sum.late == 0 ? cs.onSurfaceVariant : warn.fg)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: warn.bg, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Text('${sum.late}', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: warn.fg, height: 1)),
                  Text('hari lewat', style: t.labelSmall?.copyWith(color: warn.fg)),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              stat('hadir', '${sum.present}/${sum.workdays}'),
              stat('tiada rekod', '${sum.absent}'),
              stat('cuti', '${sum.leave}'),
              stat('balik awal', '${sum.earlyLeave}'),
            ]),
            const SizedBox(height: 6),
            Text('Jam bekerja: ${fmtMinutes(sum.workedMinutes)}', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}

/// The dates behind the numbers: each late day with how late, and absent days.
class _DaysSheet extends StatelessWidget {
  const _DaysSheet({required this.emp, required this.sum, required this.month});
  final Employee emp;
  final MonthSummary sum;
  final String month;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    void open(String date) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => AttendanceDetailScreen(empId: emp.id, date: date)));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .6,
      maxChildSize: .92,
      builder: (_, controller) => ListView(controller: controller, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Text(emp.name, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        Text(monthLabel(month), style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        Text('Lewat (${sum.late} hari · ${fmtMinutes(sum.lateMinutes)})',
            style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (sum.lateDays.isEmpty) const QuietText('Tiada hari lewat.'),
        for (final d in sum.lateDays)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(longDate(parseYmd(d))),
            subtitle: Text('Masuk ${store.attendanceOn(emp.id, d)!.clockIn}'),
            trailing: Tag('+${fmtMinutes(store.lateMinutes(store.attendanceOn(emp.id, d)!))}', tone: 'warn'),
            onTap: () => open(d),
          ),
        const SizedBox(height: 12),
        Text('Tiada rekod (${sum.absent} hari)', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (sum.absentDays.isEmpty) const QuietText('Tiada.'),
        for (final d in sum.absentDays)
          ListTile(contentPadding: EdgeInsets.zero, title: Text(longDate(parseYmd(d))), trailing: const Tag('Tiada rekod', tone: 'bad')),
      ]),
    );
  }
}
