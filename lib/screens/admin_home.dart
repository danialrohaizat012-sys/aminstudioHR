import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import 'announcements_screen.dart';
import 'attendance_admin_screen.dart';
import 'employee_home.dart';
import 'punch_screen.dart';
import 'punch_settings_screen.dart';

/// HR manager's day: who is in, what needs a decision, payroll status.
class AdminHome extends StatelessWidget {
  const AdminHome({super.key, required this.onGo});
  final void Function(int tab) onGo;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = ymd(store.now);
    final staff = store.staff;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final workday = store.isWorkday(store.now);

    final present = staff.where((e) => store.attendanceOn(e.id, today)?.clockIn != null).toList();
    final late = present.where((e) => store.isLate(store.attendanceOn(e.id, today)!)).length;
    final leaveToday = store.onLeave(today);
    final leaveIds = leaveToday.map((r) => r.empId).toSet();
    final missing = workday
        ? staff.where((e) => !present.contains(e) && !leaveIds.contains(e.id)).toList()
        : <dynamic>[];
    final pending = store.pending();
    final month = ym(store.now);
    final run = store.payrun(month);
    final lines = run?.lines ?? store.draftLines(month);
    final net = lines.fold(0.0, (s, l) => s + l.net);
    final reminders = store.reminders();
    final in14 = ymd(store.now.add(const Duration(days: 14)));
    final upcoming = store.requests
        .where((r) =>
            r.kind == ReqKind.leave &&
            r.status == ReqStatus.approved &&
            r.from!.compareTo(today) > 0 &&
            r.from!.compareTo(in14) <= 0)
        .toList()
      ..sort((a, b) => a.from!.compareTo(b.from!));

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leadingWidth: 64,
        // On wide screens the navigation rail already shows the logo.
        leading: MediaQuery.sizeOf(context).width < 840
            ? const Padding(padding: EdgeInsets.only(left: 16), child: Center(child: BrandMark(size: 40)))
            : null,
        titleSpacing: 12,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hari ini', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(longDate(store.now), style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Buat pengumuman',
            onPressed: () => showAnnouncementForm(context),
            icon: const Icon(Icons.campaign_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PageList(children: [
        if (store.me!.salary > 0) const PunchCard(),
        FigureStrip(items: [
          Figure(
            label: 'Hadir',
            value: '${present.length} / ${staff.length}',
            progress: staff.isEmpty ? 0 : present.length / staff.length,
            onTap: () => _openAttendance(context),
          ),
          Figure(
            label: 'Lewat',
            value: '$late',
            note: 'selepas ${store.settings.startTime}',
            onTap: () => _openAttendance(context),
          ),
          Figure(label: 'Bercuti', value: '${leaveToday.length}', note: 'hari ini'),
          Figure(
            label: 'Menunggu kelulusan',
            value: '${pending.length}',
            note: pending.isEmpty ? 'semua selesai' : 'paling lama ${ago(pending.first.createdAt)}',
            onTap: () => onGo(1),
          ),
        ]),
        // Until the shop location is set, punch rules sit near the top.
        if (!store.settings.hasOffice) _PunchRulesCard(),
        Section(
          title: 'Menunggu kelulusan',
          action: pending.length > 3 ? TextAction('Semua (${pending.length})', onPressed: () => onGo(1)) : null,
          child: pending.isEmpty
              ? const QuietText('Tiada permohonan menunggu.')
              : Column(children: [
                  for (var i = 0; i < pending.length && i < 3; i++) ...[
                    if (i > 0) const Divider(),
                    ApprovalTile(pending[i], showBalance: true),
                  ],
                ]),
        ),
        const ColumnBreak(),
        if (reminders.isNotEmpty)
          Section(
            title: 'Peringatan',
            child: Column(children: [
              for (final r in reminders.take(6))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Avatar(r.empId == null ? null : store.employeeById(r.empId!)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(r.title, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                    Tag(_when(r.date, store.now), tone: r.tone),
                  ]),
                ),
            ]),
          ),
        if (upcoming.isNotEmpty)
          Section(
            title: 'Cuti 14 hari akan datang',
            child: Column(children: [
              for (final r in upcoming)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Avatar(store.employeeById(r.empId)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(store.nameOf(r.empId), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text(requestTitle(r), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ]),
                    ),
                    Text(r.from == r.to ? fmtShort(r.from) : '${fmtShort(r.from)} – ${fmtShort(r.to)}',
                        style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                  ]),
                ),
            ]),
          ),
        Section(
          title: workday ? 'Belum punch masuk' : 'Kehadiran',
          action: TextAction('Kehadiran penuh', onPressed: () => _openAttendance(context)),
          child: !workday
              ? const QuietText('Hari ini hari rehat.')
              : missing.isEmpty
                  ? const QuietText('Semua pekerja sudah punch masuk.')
                  : Column(children: [
                      for (final e in missing)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Avatar(e),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(e.name, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                Text(e.dept, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                              ]),
                            ),
                          ]),
                        ),
                    ]),
        ),
        if (leaveToday.isNotEmpty)
          Section(
            title: 'Bercuti hari ini',
            child: Column(children: [
              for (final r in leaveToday)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Avatar(store.employeeById(r.empId)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(store.nameOf(r.empId), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                    Text('${r.leaveType}, hingga ${fmtShort(r.to)}', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ]),
                ),
            ]),
          ),
        if (store.settings.hasOffice) _PunchRulesCard(),
        Section(
          title: 'Gaji ${monthLabel(month)}',
          action: Tag(run == null ? 'Draf' : 'Dimuktamadkan', tone: run == null ? 'warn' : 'ok'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rm(net), style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.5)),
            Text('bersih untuk ${lines.length} pekerja', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            run == null
                ? FilledButton(onPressed: () => onGo(3), child: const Text('Semak dan muktamadkan'))
                : OutlinedButton(onPressed: () => onGo(3), child: const Text('Lihat penggajian')),
          ]),
        ),
      ]),
    );
  }

  void _openAttendance(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AttendanceAdminScreen()));
}

/// Punch rules at a glance, with a shortcut to change them.
class _PunchRulesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget row(IconData icon, String label, String value, {String tone = 'mute'}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Icon(icon, size: 20, color: cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: t.bodyMedium)),
            Tag(value, tone: tone),
          ]),
        );
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PunchSettingsScreen()));
    return Section(
      title: 'Tetapan punch',
      action: TextAction('Ubah', onPressed: open),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        row(Icons.storefront_outlined, 'Lokasi kedai', s.hasOffice ? 'Ditetapkan' : 'Belum ditetapkan',
            tone: s.hasOffice ? 'ok' : 'warn'),
        row(Icons.radar_outlined, 'Radius', fmtDistance(s.radiusM)),
        row(Icons.face_outlined, 'Selfie', s.requireSelfie ? 'Wajib' : 'Tidak wajib', tone: s.requireSelfie ? 'ok' : 'mute'),
        row(Icons.location_on_outlined, 'Lokasi telefon', 'Wajib', tone: 'ok'),
        if (!s.hasOffice) ...[
          const SizedBox(height: 8),
          FilledButton.tonal(onPressed: open, child: const Text('Tetapkan lokasi kedai')),
        ],
      ]),
    );
  }
}

String _when(DateTime d, DateTime now) {
  final days = DateTime(d.year, d.month, d.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days < 0) return '${-days} hari lepas';
  if (days == 0) return 'Hari ini';
  if (days == 1) return 'Esok';
  return '${d.day} ${monthsMs[d.month - 1].substring(0, 3)} · $days hari';
}
