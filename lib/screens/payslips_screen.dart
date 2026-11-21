import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../services/pdf_reports.dart';
import '../widgets/common.dart';

class PayslipsScreen extends StatelessWidget {
  const PayslipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final slips = store.payslipsOf(store.me!.id);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ytd = slips.where((s) => s.$1.startsWith('${store.now.year}'));

    return Scaffold(
      appBar: AppBar(title: const Text('Slip gaji')),
      body: PageList(children: [
        if (slips.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Slip akan muncul di sini selepas HR muktamadkan gaji bulanan.', textAlign: TextAlign.center),
            ),
          )
        else ...[
          FigureStrip(items: [
            Figure(label: 'Bersih ${store.now.year}', value: rm(ytd.fold(0.0, (s, e) => s + e.$2.net))),
            Figure(label: 'PCB ${store.now.year}', value: rm(ytd.fold(0.0, (s, e) => s + e.$2.pcb))),
          ]),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < slips.length; i++) ...[
                if (i > 0) const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    foregroundColor: cs.onPrimaryContainer,
                    child: const Icon(Icons.receipt_outlined, size: 20),
                  ),
                  title: Text(monthLabel(slips[i].$1), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Kasar ${rm(slips[i].$2.gross)}', style: t.bodySmall),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(rm(slips[i].$2.net), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const Icon(Icons.chevron_right),
                  ]),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PayslipDetail(month: slips[i].$1, line: slips[i].$2))),
                ),
              ],
            ]),
          ),
        ],
      ]),
    );
  }
}

class PayslipDetail extends StatelessWidget {
  const PayslipDetail({super.key, required this.month, required this.line, this.draft = false});
  final String month;
  final PayLine line;
  final bool draft;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    // A draft is recomputed on every build so adjustments show immediately.
    final emp = store.employeeById(line.empId);
    final l = draft && emp != null ? store.computeLine(emp, month) : line;

    Widget row(String k, double v, {bool bold = false, bool negative = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(k, style: bold ? t.bodyMedium?.copyWith(fontWeight: FontWeight.w700) : t.bodyMedium)),
            Text(negative ? '−${rm(v)}' : rm(v),
                style: t.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text('Slip ${monthLabel(month)}'), actions: [
        IconButton(
          tooltip: 'Muat turun PDF',
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: () async => sharePdf(await payslipPdf(store.settings.name, month, l),
              'slip-gaji-${l.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-$month.pdf'),
        ),
      ]),
      body: PageList(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.settings.name, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(l.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text([l.position, if (l.ic.isNotEmpty) 'KP ${l.ic}'].join(' · '),
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              if (l.bank.isNotEmpty)
                Text('${l.bank} ${l.bankAcc}', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              if (draft) const Padding(padding: EdgeInsets.only(top: 8), child: Tag('Draf, belum dimuktamadkan', tone: 'warn')),
            ]),
          ),
        ),
        Card(
          color: cs.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: Text('Gaji bersih', style: t.titleMedium?.copyWith(color: cs.onPrimaryContainer))),
              Text(rm(l.net),
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: cs.onPrimaryContainer, letterSpacing: -.5)),
            ]),
          ),
        ),
        Section(
          title: 'Pendapatan',
          child: Column(children: [
            row('Gaji pokok', l.basic),
            if (l.allowance > 0) row('Elaun tetap', l.allowance),
            if (l.extraAllowance > 0) row('Elaun tambahan', l.extraAllowance),
            if (l.bonus > 0) row('Bonus', l.bonus),
            if (l.commission > 0) row('Komisen', l.commission),
            if (l.jobCommission > 0) row('Komisen job (${l.jobCount} job)', l.jobCommission),
            if (l.overtime > 0) row('Kerja lebih masa', l.overtime),
            if (l.unpaidLeave > 0) row('Cuti tanpa gaji', l.unpaidLeave, negative: true),
            const Divider(height: 16),
            row('Gaji kasar', l.gross, bold: true),
          ]),
        ),
        Section(
          title: 'Potongan',
          child: Column(children: [
            row('KWSP (11%)', l.epfEe),
            row('PERKESO', l.socsoEe),
            row('SIP', l.eisEe),
            row('PCB / MTD', l.pcb),
            if (l.otherDeduction > 0)
              row('Potongan lain${l.adjustNote.isNotEmpty ? ' (${l.adjustNote})' : ''}', l.otherDeduction),
            const Divider(height: 16),
            row('Jumlah potongan', l.deductions, bold: true),
          ]),
        ),
        if (l.claims > 0) Section(title: 'Bayaran balik', child: row('Tuntutan diluluskan', l.claims)),
        if (draft && store.isAdmin && emp != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => showAdjustmentForm(context, month, emp),
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Bonus, komisen dan potongan bulan ini'),
          ),
        Section(
          title: 'Caruman majikan',
          child: Column(children: [
            row('KWSP', l.epfEr),
            row('PERKESO', l.socsoEr),
            row('SIP', l.eisEr),
          ]),
        ),
        Text(
          'Kiraan KWSP, PERKESO, SIP dan PCB ialah anggaran. Semak dengan jadual rasmi dan Kalkulator PCB LHDN.',
          style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ]),
    );
  }
}

/// Manager enters one-off pay items for one employee in a draft month.
Future<void> showAdjustmentForm(BuildContext context, String month, Employee e) {
  final store = StoreScope.of(context);
  final a = store.adjustmentFor(month, e.id);
  String v(double x) => x == 0 ? '' : x.toStringAsFixed(2);
  final c = {
    'bonus': TextEditingController(text: v(a.bonus)),
    'commission': TextEditingController(text: v(a.commission)),
    'extra': TextEditingController(text: v(a.extraAllowance)),
    'deduct': TextEditingController(text: v(a.otherDeduction)),
    'note': TextEditingController(text: a.note),
  };
  String? error;
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => StatefulBuilder(
      builder: (sheet, set) {
        Widget money(String k, String label, String? help) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: c[k],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: label, prefixText: 'RM ', helperText: help),
              ),
            );
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(sheet).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Pelarasan ${monthLabel(month)}',
                  style: Theme.of(sheet).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(e.name, style: Theme.of(sheet).textTheme.bodyMedium),
              const SizedBox(height: 16),
              money('bonus', 'Bonus', 'Dikenakan KWSP, PERKESO, SIP dan PCB'),
              money('commission', 'Komisen', null),
              money('extra', 'Elaun tambahan', 'Contoh: elaun penggambaran luar'),
              money('deduct', 'Potongan lain', 'Contoh: bayaran balik pendahuluan gaji'),
              TextField(controller: c['note'], decoration: const InputDecoration(labelText: 'Catatan (dipapar pada slip)')),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: TextStyle(color: Theme.of(sheet).colorScheme.error)),
                ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () async {
                  double n(String k) => double.tryParse(c[k]!.text.replaceAll(',', '').trim()) ?? 0;
                  final err = await store.setAdjustment(
                    month,
                    e.id,
                    PayAdjustment(
                      bonus: n('bonus'),
                      commission: n('commission'),
                      extraAllowance: n('extra'),
                      otherDeduction: n('deduct'),
                      note: c['note']!.text.trim(),
                    ),
                  );
                  if (err != null) {
                    set(() => error = err);
                    return;
                  }
                  if (sheet.mounted) Navigator.pop(sheet);
                },
                child: const Text('Simpan'),
              ),
            ]),
          ),
        );
      },
    ),
  );
}
