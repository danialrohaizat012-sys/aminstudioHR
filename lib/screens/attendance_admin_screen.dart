import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';
import 'punch_screen.dart';
import 'punch_settings_screen.dart';

/// HR view of one day: who punched, when, from where, and corrections.
class AttendanceAdminScreen extends StatefulWidget {
  const AttendanceAdminScreen({super.key});
  @override
  State<AttendanceAdminScreen> createState() => _AttendanceAdminScreenState();
}

class _AttendanceAdminScreenState extends State<AttendanceAdminScreen> {
  late DateTime day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final date = ymd(day);
    final staff = store.staff;
    final rows = [for (final e in staff) (e, store.attendanceOn(e.id, date), store.dayStatus(e, date))];
    int count(DayStatus s) => rows.where((r) => r.$3 == s).length;
    final flagged = rows.where((r) => store.isFlagged(r.$2?.inMark) || store.isFlagged(r.$2?.outMark)).length;
    final isToday = date == ymd(store.now);
    final t = Theme.of(context).textTheme;

    // Problems first: absent, flagged, late; then everyone else by name.
    int rank((Employee, AttendanceRecord?, DayStatus) r) {
      if (r.$3 == DayStatus.absent) return 0;
      if (store.isFlagged(r.$2?.inMark) || store.isFlagged(r.$2?.outMark)) return 1;
      if (r.$3 == DayStatus.late) return 2;
      return 3;
    }

    rows.sort((a, b) => rank(a) != rank(b) ? rank(a) - rank(b) : a.$1.name.compareTo(b.$1.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Kehadiran pekerja'), actions: [
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
          Figure(label: 'Hadir', value: '${count(DayStatus.present) + count(DayStatus.late)} / ${staff.length}'),
          Figure(label: 'Lewat', value: '${count(DayStatus.late)}', note: 'selepas ${store.settings.startTime}'),
          Figure(label: 'Tiada rekod', value: '${count(DayStatus.absent)}'),
          Figure(label: 'Luar kawasan', value: '$flagged', note: 'perlu disemak'),
        ]),
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
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(indent: 68),
              _Row(emp: rows[i].$1, rec: rows[i].$2, status: rows[i].$3, date: date),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.emp, required this.rec, required this.status, required this.date});
  final Employee emp;
  final AttendanceRecord? rec;
  final DayStatus status;
  final String date;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final flagged = store.isFlagged(rec?.inMark) || store.isFlagged(rec?.outMark);
    final times = rec?.clockIn == null ? '' : '${rec!.clockIn} → ${rec!.clockOut ?? 'belum keluar'}';
    return ListTile(
      leading: Avatar(emp),
      title: Text(emp.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          if (times.isNotEmpty) times,
          if (rec?.inMark?.distance != null) fmtDistance(rec!.inMark!.distance!),
          if (rec?.editedBy != null) 'dibetulkan HR',
        ].join(' · ').ifEmpty(emp.dept),
        style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Wrap(spacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (flagged) const Tag('Luar kawasan', tone: 'warn'),
        if (status != DayStatus.upcoming && !(flagged && status == DayStatus.present)) Tag(status.label, tone: status.tone),
      ]),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _Detail(emp: emp, date: date),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

class _Detail extends StatefulWidget {
  const _Detail({required this.emp, required this.date});
  final Employee emp;
  final String date;
  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rec = store.attendanceOn(widget.emp.id, widget.date);
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Avatar(widget.emp, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.emp.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(longDate(parseYmd(widget.date)), style: t.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        _MarkTile(label: 'Masuk', time: rec?.clockIn, mark: rec?.inMark),
        const SizedBox(height: 8),
        _MarkTile(label: 'Keluar', time: rec?.clockOut, mark: rec?.outMark),
        if (rec?.editedBy != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Masa dibetulkan oleh ${rec!.editedBy}', style: t.bodySmall),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          onPressed: () => _correct(context, rec),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Betulkan masa'),
        ),
      ]),
    );
  }

  Future<void> _correct(BuildContext context, AttendanceRecord? rec) async {
    final store = StoreScope.of(context);
    TimeOfDay? parse(String? v) =>
        v == null ? null : TimeOfDay(hour: int.parse(v.split(':')[0]), minute: int.parse(v.split(':')[1]));
    String fmt(TimeOfDay v) => '${two(v.hour)}:${two(v.minute)}';
    final inT = await showTimePicker(
        context: context, helpText: 'Masa masuk', initialTime: parse(rec?.clockIn) ?? const TimeOfDay(hour: 9, minute: 0));
    if (inT == null || !context.mounted) return;
    final outT = await showTimePicker(
        context: context, helpText: 'Masa keluar (batal = belum keluar)', initialTime: parse(rec?.clockOut) ?? const TimeOfDay(hour: 18, minute: 0));
    await store.correctAttendance(widget.emp.id, widget.date, fmt(inT), outT == null ? null : fmt(outT));
    if (mounted) setState(() {});
  }
}

class _MarkTile extends StatelessWidget {
  const _MarkTile({required this.label, required this.time, required this.mark});
  final String label;
  final String? time;
  final PunchMark? mark;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final m = mark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (m?.photo != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(base64Decode(m!.photo!), width: 64, height: 64, fit: BoxFit.cover),
            ),
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$label  ${time ?? '—'}', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (m == null && time != null) Text('Dimasukkan oleh HR', style: t.bodySmall),
            if (m != null && !m.hasLocation) Text('Tiada lokasi', style: t.bodySmall),
            if (m?.hasLocation == true)
              Text(
                '${m!.distance != null ? '${fmtDistance(m.distance!)} dari kedai · ' : ''}'
                '${m.lat!.toStringAsFixed(5)}, ${m.lng!.toStringAsFixed(5)}'
                '${m.accuracy != null ? ' (±${m.accuracy!.round()} m)' : ''}',
                style: t.bodySmall,
              ),
            if (m != null && m.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Sebab: ${m.note}', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ]),
    );
  }
}
