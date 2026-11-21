import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'punch_screen.dart';

/// Employee avatar that uses the day's punch selfie when there is one.
class PunchAvatar extends StatelessWidget {
  const PunchAvatar({super.key, required this.employee, this.photo, this.radius = 22});
  final Employee? employee;
  final String? photo;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (photo == null) return Avatar(employee, radius: radius);
    return CircleAvatar(radius: radius, backgroundImage: MemoryImage(base64Decode(photo!)));
  }
}

/// Tags describing one day's record, shared by the list and the detail page.
List<Widget> dayTags(HrStore store, Employee e, String date) {
  final rec = store.attendanceOn(e.id, date);
  final status = store.dayStatus(e, date);
  final flagged = store.isFlagged(rec?.inMark) || store.isFlagged(rec?.outMark);
  return [
    if (status != DayStatus.upcoming) Tag(status.label, tone: status.tone),
    if (rec?.openBreak != null) Tag('Sedang rehat', tone: 'warn'),
    if (rec != null && store.isEarlyLeave(rec)) const Tag('Balik awal', tone: 'warn'),
    if (flagged) const Tag('Luar kawasan', tone: 'warn'),
    if (rec?.editedBy != null) const Tag('Dibetulkan HR'),
  ];
}

/// Full record of one employee's day: selfie, device, where and when they
/// punched (with map link), breaks and hours worked.
class AttendanceDetailScreen extends StatefulWidget {
  const AttendanceDetailScreen({super.key, required this.empId, required this.date});
  final String empId;
  final String date;

  @override
  State<AttendanceDetailScreen> createState() => _AttendanceDetailScreenState();
}

class _AttendanceDetailScreenState extends State<AttendanceDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final e = store.employeeById(widget.empId)!;
    final rec = store.attendanceOn(e.id, widget.date);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final s = store.settings;
    final device = rec?.inMark?.device ?? rec?.outMark?.device;

    return Scaffold(
      appBar: AppBar(title: const Text('Butiran kehadiran')),
      body: PageList(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GestureDetector(
                onTap: rec?.inMark?.photo == null ? null : () => _showPhoto(context, rec!.inMark!.photo!),
                child: PunchAvatar(employee: e, photo: rec?.inMark?.photo, radius: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text([e.position, if (device != null) device].join(' · '),
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    ...dayTags(store, e, widget.date),
                    Tag('Shift ${s.startTime}–${s.endTime}'),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
        _MarkCard(label: 'Masuk', icon: Icons.login, date: widget.date, time: rec?.clockIn, mark: rec?.inMark),
        _MarkCard(label: 'Keluar', icon: Icons.logout, date: widget.date, time: rec?.clockOut, mark: rec?.outMark),
        if (rec?.clockIn != null) _Sessions(rec: rec!),
        if (store.isAdmin)
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
        context: context,
        helpText: 'Masa masuk',
        initialTime: parse(rec?.clockIn) ?? const TimeOfDay(hour: 9, minute: 0));
    if (inT == null || !context.mounted) return;
    final outT = await showTimePicker(
        context: context,
        helpText: 'Masa keluar (batal = belum keluar)',
        initialTime: parse(rec?.clockOut) ?? const TimeOfDay(hour: 18, minute: 0));
    await store.correctAttendance(widget.empId, widget.date, fmt(inT), outT == null ? null : fmt(outT));
    if (mounted) setState(() {});
  }
}

void _showPhoto(BuildContext context, String photo) => showDialog<void>(
      context: context,
      builder: (c) => Dialog(clipBehavior: Clip.antiAlias, child: Image.memory(base64Decode(photo))),
    );

class _MarkCard extends StatelessWidget {
  const _MarkCard({required this.label, required this.icon, required this.date, required this.time, required this.mark});
  final String label;
  final IconData icon;
  final String date;
  final String? time;
  final PunchMark? mark;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final m = mark;
    Widget line(IconData i, Widget child) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 14),
            Expanded(child: child),
          ]),
        );

    return Section(
      title: label,
      child: time == null
          ? QuietText(label == 'Keluar' ? 'Belum punch keluar.' : 'Tiada rekod punch masuk.')
          : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  line(icon, Text('${fmtDate(date)} | $time', style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
                  if (m == null)
                    line(Icons.edit_note, const Text('Dimasukkan oleh HR'))
                  else if (!m.hasLocation)
                    line(Icons.location_off_outlined, const Text('Tiada lokasi'))
                  else
                    line(
                      Icons.location_on_outlined,
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.address ?? '${m.lat!.toStringAsFixed(5)}, ${m.lng!.toStringAsFixed(5)}', style: t.bodyMedium),
                        if (m.distance != null)
                          Text(
                            '${fmtDistance(m.distance!)} dari kedai'
                            '${m.accuracy != null ? ' · ketepatan ±${m.accuracy!.round()} m' : ''}',
                            style: t.bodySmall?.copyWith(
                                color: store.isFlagged(m) ? statusColors(context, 'warn').fg : cs.onSurfaceVariant),
                          ),
                        TextButton.icon(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                          onPressed: () => launchUrl(Uri.parse(m.mapUrl!), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.map_outlined, size: 18),
                          label: const Text('Lihat di peta'),
                        ),
                      ]),
                    ),
                  if (m != null && m.note.isNotEmpty) line(Icons.sticky_note_2_outlined, Text('Sebab: ${m.note}')),
                ]),
              ),
              if (m?.photo case final String photo)
                GestureDetector(
                  onTap: () => _showPhoto(context, photo),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(base64Decode(photo), width: 72, height: 72, fit: BoxFit.cover),
                  ),
                ),
            ]),
    );
  }
}

class _Sessions extends StatelessWidget {
  const _Sessions({required this.rec});
  final AttendanceRecord rec;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final end = rec.clockOut ?? (rec.date == ymd(store.now) ? null : rec.clockIn);
    TableRow row(String a, String b, String c, {bool head = false, bool bold = false}) => TableRow(
          decoration: head ? BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(10)) : null,
          children: [
            for (final (i, x) in [a, b, c].indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                child: Text(x,
                    textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                    style: (head ? t.labelMedium : t.bodyMedium)?.copyWith(
                        fontWeight: head || bold ? FontWeight.w700 : null,
                        color: head ? cs.onSurfaceVariant : null)),
              ),
          ],
        );
    final grossMin = store.workedMinutes(rec) + rec.breaks.fold<int>(0, (s, b) => s + store.breakMinutes(b, until: end));

    return Section(
      title: 'Sesi',
      child: Table(
        columnWidths: const {0: FlexColumnWidth(1.4), 1: FlexColumnWidth(1.4), 2: FlexColumnWidth(1)},
        children: [
          row('Sesi', 'Masa', 'Tempoh', head: true),
          row('Kerja', '${rec.clockIn} – ${rec.clockOut ?? 'sekarang'}', fmtMinutes(grossMin)),
          for (final b in rec.breaks)
            row(b.label, '${b.start} – ${b.end ?? 'sekarang'}', '−${fmtMinutes(store.breakMinutes(b, until: end))}'),
          row('Jumlah bekerja', '', fmtMinutes(store.workedMinutes(rec)), bold: true),
        ],
      ),
    );
  }
}
