import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
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
    final l = line;

    Widget row(String k, double v, {bool bold = false, bool negative = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(k, style: bold ? t.bodyMedium?.copyWith(fontWeight: FontWeight.w700) : t.bodyMedium)),
            Text(negative ? '−${rm(v)}' : rm(v),
                style: t.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: Text('Slip ${monthLabel(month)}')),
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
            const Divider(height: 16),
            row('Jumlah potongan', l.deductions, bold: true),
          ]),
        ),
        if (l.claims > 0) Section(title: 'Bayaran balik', child: row('Tuntutan diluluskan', l.claims)),
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
