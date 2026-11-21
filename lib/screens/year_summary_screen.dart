import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../services/pdf_reports.dart';
import '../store.dart';
import '../widgets/common.dart';

/// Totals per employee for a year of finalised payroll, to fill Borang EA.
class YearSummaryScreen extends StatefulWidget {
  const YearSummaryScreen({super.key});
  @override
  State<YearSummaryScreen> createState() => _YearSummaryScreenState();
}

class _YearSummaryScreenState extends State<YearSummaryScreen> {
  late int year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rows = store.yearTotals(year);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    double sum(double Function(dynamic) f) => rows.fold(0.0, (s, r) => s + f(r));

    return Scaffold(
      appBar: AppBar(title: const Text('Ringkasan tahunan'), actions: [
        IconButton(
          tooltip: 'Muat turun PDF',
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: rows.isEmpty
              ? null
              : () async => sharePdf(
                  await yearPdf(store.settings.name, year, [
                    for (final r in rows)
                      (name: r.name, ic: r.ic, gross: r.gross, epf: r.epf, socso: r.socso, eis: r.eis, pcb: r.pcb, months: r.months)
                  ]),
                  'saraan-$year.pdf'),
        ),
      ]),
      body: PageList(children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => year--), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text('$year', textAlign: TextAlign.center, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          IconButton(
            onPressed: year >= store.now.year ? null : () => setState(() => year++),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        FigureStrip(items: [
          Figure(label: 'Saraan kasar', value: rm(sum((r) => r.gross))),
          Figure(label: 'PCB dipotong', value: rm(sum((r) => r.pcb))),
          Figure(label: 'KWSP pekerja', value: rm(sum((r) => r.epf))),
          Figure(label: 'PERKESO + SIP', value: rm(sum((r) => r.socso + r.eis))),
        ]),
        if (rows.isEmpty)
          const Card(
              child: EmptyState(
                  icon: Icons.summarize_outlined,
                  title: 'Tiada gaji dimuktamadkan tahun ini',
                  message: 'Muktamadkan gaji bulanan di tab Gaji; jumlah tahunan dikira dari situ.'))
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(indent: 68),
                ListTile(
                  leading: Avatar(rows[i].emp),
                  title: Text(rows[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${rows[i].months} bulan · KWSP ${rm(rows[i].epf)} · PERKESO ${rm(rows[i].socso)} · SIP ${rm(rows[i].eis)} · PCB ${rm(rows[i].pcb)}',
                    style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  trailing: Text(rm(rows[i].gross), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
          ),
        Text('Hanya bulan yang dimuktamadkan dikira. Gunakan angka ini untuk mengisi Borang EA (sebelum 28 Februari) dan Borang E.',
            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}
