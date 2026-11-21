import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';
import 'announcements_screen.dart';
import 'payslips_screen.dart';
import 'punch_screen.dart';
import 'request_forms.dart';

class EmployeeHome extends StatelessWidget {
  const EmployeeHome({super.key, required this.onGo});
  final void Function(int tab) onGo;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.me!;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final recent = store.requestsOf(me.id).take(3).toList();
    final slips = store.payslipsOf(me.id);
    final anns = sortedAnnouncements(store);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leadingWidth: 64,
        // On wide screens the navigation rail already shows the logo.
        leading: MediaQuery.sizeOf(context).width < 840
            ? const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Center(child: BrandMark(size: 40)))
            : null,
        titleSpacing: 12,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hai, ${me.firstName}',
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(longDate(store.now),
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        ]),
        actions: const [ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: PageList(children: [
        const PunchCard(),
        Row(children: [
          Expanded(
            child: FilledButton(
              onPressed: () => showLeaveForm(context),
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Mohon cuti'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => showClaimForm(context),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Tuntutan'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () => showOvertimeForm(context),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('Lebih masa'),
            ),
          ),
        ]),
        Section(
          title: 'Baki cuti ${store.now.year}',
          action: TextAction('Sejarah', onPressed: () => onGo(2)),
          child: Column(children: [
            for (final type in const ['Cuti Tahunan', 'Cuti Sakit'])
              _BalanceRow(empId: me.id, type: type),
          ]),
        ),
        const ColumnBreak(),
        Section(
          title: 'Slip gaji terakhir',
          action: slips.isEmpty
              ? null
              : TextAction('Semua', onPressed: () => onGo(3)),
          child: slips.isEmpty
              ? const QuietText(
                  'Slip akan muncul selepas HR muktamadkan gaji bulanan.')
              : InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PayslipDetail(
                          month: slips.first.$1, line: slips.first.$2))),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rm(slips.first.$2.net),
                                style: t.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -.5)),
                            Text('bersih · ${monthLabel(slips.first.$1)}',
                                style: t.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                          ]),
                    ),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
        ),
        Section(
          title: 'Permohonan saya',
          action: recent.isEmpty
              ? null
              : TextAction('Semua', onPressed: () => onGo(2)),
          child: recent.isEmpty
              ? const QuietText('Belum ada permohonan.')
              : Column(children: [
                  for (final r in recent)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Icon(requestIcon(r.kind),
                            size: 20, color: cs.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(requestTitle(r),
                                    style: t.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600)),
                                Text(requestDetail(r),
                                    style: t.bodySmall
                                        ?.copyWith(color: cs.onSurfaceVariant)),
                              ]),
                        ),
                        StatusChip(r.status),
                      ]),
                    ),
                ]),
        ),
        Section(
          title: 'Pengumuman',
          action: TextAction('Semua',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AnnouncementsScreen()))),
          child: anns.isEmpty
              ? const QuietText('Belum ada pengumuman.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final a in anns.take(2)) AnnouncementItem(a)],
                ),
        ),
      ]),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.empId, required this.type});
  final String empId, type;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final e = store.employeeById(empId)!;
    final ent = store.entitlement(e, type);
    final bal = store.leaveBalance(empId, type) ?? 0;
    final pend = store.usedLeave(empId, type, status: ReqStatus.pending);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(type, style: t.bodyMedium)),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: daysLabel(bal).split(' ').first,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(
                text: ' / $ent hari',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ])),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: ent == 0 ? 0 : (bal / ent).clamp(0, 1).toDouble(),
            minHeight: 6,
            backgroundColor: cs.surfaceContainer,
          ),
        ),
        if (pend > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('${daysLabel(pend)} menunggu kelulusan',
                style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ),
      ]),
    );
  }
}

/// Live clock with punch in / punch out.
class PunchCard extends StatefulWidget {
  const PunchCard({super.key});

  @override
  State<PunchCard> createState() => _PunchCardState();
}

class _PunchCardState extends State<PunchCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer =
        Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = store.now;
    final rec = store.attendanceOn(store.me!.id, ymd(now));
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final late = rec != null && store.isLate(rec);
    final workday = store.isWorkday(now);

    final status = rec?.clockIn == null
        ? (workday
            ? 'Waktu mula kerja ${store.settings.startTime}'
            : 'Hari rehat')
        : rec!.clockOut == null
            ? rec.openBreak != null
                ? '${rec.openBreak!.label} sejak ${rec.openBreak!.start}'
                : 'Bekerja sejak ${rec.clockIn}${late ? ' · lewat' : ''} · ${fmtMinutes(store.workedMinutes(rec))}'
            : 'Selesai · bekerja ${fmtMinutes(store.workedMinutes(rec))}';

    Widget? button;
    if (rec?.clockIn == null) {
      button = FilledButton.icon(
        onPressed: () => _act(context, true),
        icon: const Icon(Icons.login, size: 20),
        label: const Text('Punch masuk'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      );
    } else if (rec!.clockOut == null) {
      final onBreak = rec.openBreak != null;
      button = Row(children: [
        Expanded(
          child: onBreak
              ? FilledButton.tonalIcon(
                  onPressed: () => _endBreak(context),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('Tamat rehat'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                )
              : OutlinedButton.icon(
                  onPressed: () => _startBreak(context),
                  icon: const Icon(Icons.free_breakfast_outlined, size: 20),
                  label: const Text('Mula rehat'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _act(context, false),
            icon: const Icon(Icons.logout, size: 20),
            label: const Text('Punch keluar'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ),
      ]);
    }

    Widget io(String label, String? v) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          Text(v ?? '—',
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ]);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(hm(now),
                    style: t.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        height: 1)),
              ),
            ),
            const SizedBox(width: 16),
            Container(width: 1, height: 36, color: cs.outlineVariant),
            const SizedBox(width: 16),
            io('Masuk', rec?.clockIn),
            const SizedBox(width: 20),
            io('Keluar', rec?.clockOut),
          ]),
          const SizedBox(height: 10),
          Text(status,
              style: t.bodyMedium?.copyWith(
                  color: late
                      ? statusColors(context, 'warn').fg
                      : cs.onSurfaceVariant,
                  fontWeight: late ? FontWeight.w600 : null)),
          if (rec?.inMark?.distance != null ||
              store.isFlagged(rec?.inMark) ||
              store.isFlagged(rec?.outMark))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                if (rec!.inMark?.distance != null)
                  Tag('Masuk ${fmtDistance(rec.inMark!.distance!)} dari kedai',
                      tone: store.isFlagged(rec.inMark) ? 'warn' : 'ok'),
                if (rec.outMark?.distance != null)
                  Tag('Keluar ${fmtDistance(rec.outMark!.distance!)} dari kedai',
                      tone: store.isFlagged(rec.outMark) ? 'warn' : 'ok'),
              ]),
            ),
          if (button != null) ...[const SizedBox(height: 12), button],
        ]),
      ),
    );
  }

  Future<void> _startBreak(BuildContext context) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final label = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Jenis rehat',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
          ),
          for (final l in breakLabels)
            ListTile(
              leading: Icon(l.contains('Solat')
                  ? Icons.mosque_outlined
                  : Icons.restaurant_outlined),
              title: Text(l),
              onTap: () => Navigator.pop(c, l),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (label == null) return;
    final err = await store.startBreak(label);
    messenger.showSnackBar(
        SnackBar(content: Text(err ?? '$label bermula ${hm(store.now)}')));
  }

  Future<void> _endBreak(BuildContext context) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final b = store.attendanceOn(store.me!.id, ymd(store.now))?.openBreak;
    final err = await store.endBreak();
    messenger.showSnackBar(SnackBar(
        content: Text(err ??
            '${b?.label ?? 'Rehat'} tamat · ${fmtMinutes(b == null ? 0 : store.breakMinutes(b))}')));
  }

  Future<void> _act(BuildContext context, bool clockIn) async {
    final store = StoreScope.of(context);
    final nav = Navigator.of(context);
    if (store.me!.consentAt == null) {
      final ok = await showPrivacyNotice(context);
      if (ok != true) return;
      await store.recordConsent();
    }
    nav.push(MaterialPageRoute(
        builder: (_) => PunchScreen(clockIn: clockIn), fullscreenDialog: true));
  }
}
