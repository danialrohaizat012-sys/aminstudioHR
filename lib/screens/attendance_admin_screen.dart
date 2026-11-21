import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import 'attendance_detail_screen.dart';
import 'attendance_summary_screen.dart';
import 'punch_settings_screen.dart';

enum _Filter { all, working, out, late, absent, leave, outside }

extension on _Filter {
  String get label => switch (this) {
        _Filter.all => 'Semua',
        _Filter.working => 'Sedang bekerja',
        _Filter.out => 'Sudah keluar',
        _Filter.late => 'Lewat',
        _Filter.absent => 'Tiada rekod',
        _Filter.leave => 'Bercuti',
        _Filter.outside => 'Luar kawasan',
      };
}

/// HR view of one day: who punched in and out, when, from where, with
/// filters for the cases that need attention.
class AttendanceAdminScreen extends StatefulWidget {
  const AttendanceAdminScreen({super.key});
  @override
  State<AttendanceAdminScreen> createState() => _AttendanceAdminScreenState();
}

class _AttendanceAdminScreenState extends State<AttendanceAdminScreen> {
  late DateTime day = DateTime.now();
  _Filter filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final date = ymd(day);
    final staff = store.staff;
    final isToday = date == ymd(store.now);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    bool matches(Employee e, _Filter f) {
      final rec = store.attendanceOn(e.id, date);
      final st = store.dayStatus(e, date);
      return switch (f) {
        _Filter.all => true,
        _Filter.working => rec?.clockIn != null && rec!.clockOut == null,
        _Filter.out => rec?.clockOut != null,
        _Filter.late => st == DayStatus.late,
        _Filter.absent => st == DayStatus.absent,
        _Filter.leave => st == DayStatus.onLeave,
        _Filter.outside => store.isFlagged(rec?.inMark) || store.isFlagged(rec?.outMark),
      };
    }

    final rows = staff.where((e) => matches(e, filter)).toList()
      ..sort((a, b) {
        final ra = store.attendanceOn(a.id, date)?.clockIn ?? '99';
        final rb = store.attendanceOn(b.id, date)?.clockIn ?? '99';
        return ra != rb ? ra.compareTo(rb) : a.name.compareTo(b.name);
      });
    final clockedIn = staff.where((e) => store.attendanceOn(e.id, date)?.clockIn != null).length;
    final clockedOut = staff.where((e) => store.attendanceOn(e.id, date)?.clockOut != null).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Kehadiran pekerja'), actions: [
        IconButton(
          tooltip: 'Ringkasan bulanan',
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceSummaryScreen())),
          icon: const Icon(Icons.insights_outlined),
        ),
        IconButton(
          tooltip: 'Tetapan punch',
          icon: const Icon(Icons.tune),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PunchSettingsScreen())),
        ),
      ]),
      body: PageList(children: [
        Row(children: [
          IconButton(
            onPressed: () => setState(() => day = day.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final d = await showDatePicker(
                    context: context, initialDate: day, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) setState(() => day = d);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  Text(isToday ? 'Hari ini' : longDate(day).split(',').first,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text(fmtDate(date), style: t.bodySmall),
                ]),
              ),
            ),
          ),
          IconButton(
            onPressed: isToday ? null : () => setState(() => day = day.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        FigureStrip(items: [
          Figure(
            label: 'Punch masuk',
            value: '$clockedIn / ${staff.length}',
            progress: staff.isEmpty ? 0 : clockedIn / staff.length,
          ),
          Figure(label: 'Punch keluar', value: '$clockedOut / ${staff.length}'),
        ]),
        Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Ringkasan bulanan'),
            subtitle: const Text('Jumlah hari lewat, tiada rekod dan jam bekerja setiap pekerja'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceSummaryScreen())),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final f in _Filter.values)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${f.label} ${staff.where((e) => matches(e, f)).length}'),
                  selected: filter == f,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => filter = f),
                ),
              ),
          ]),
        ),
        if (!store.settings.hasOffice)
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Lokasi kedai belum ditetapkan'),
              subtitle: const Text('Tetapkan supaya jarak punch dari kedai boleh disemak.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PunchSettingsScreen())),
            ),
          ),
        if (rows.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Tiada pekerja dalam "${filter.label}".',
                  textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ),
          )
        else
          for (final e in rows) _PersonCard(emp: e, date: date),
      ]),
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({required this.emp, required this.date});
  final Employee emp;
  final String date;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rec = store.attendanceOn(emp.id, date);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final isToday = date == ymd(store.now);

    final String state;
    if (rec?.clockIn == null) {
      state = store.dayStatus(emp, date) == DayStatus.onLeave ? 'Bercuti' : 'Belum punch masuk';
    } else if (rec!.clockOut != null) {
      state = 'Keluar ${rec.clockOut} · bekerja ${fmtMinutes(store.workedMinutes(rec))}';
    } else if (rec.openBreak != null) {
      state = '${rec.openBreak!.label} sejak ${rec.openBreak!.start}';
    } else {
      state = isToday ? 'Sedang bekerja · ${fmtMinutes(store.workedMinutes(rec))}' : 'Tiada punch keluar';
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => AttendanceDetailScreen(empId: emp.id, date: date))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              PunchAvatar(employee: emp, photo: rec?.inMark?.photo, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(emp.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 4, runSpacing: 4, children: dayTags(store, emp, date)),
                ]),
              ),
              if (rec?.clockIn != null)
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Masuk', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  Text(rec!.clockIn!, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ]),
            ]),
            const Divider(height: 20),
            Text(state, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }
}
