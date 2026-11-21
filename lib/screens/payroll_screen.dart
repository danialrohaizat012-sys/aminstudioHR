import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../store.dart';
import '../services/pdf_reports.dart';
import '../widgets/common.dart';
import 'year_summary_screen.dart';
import 'payslips_screen.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});
  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  late String month = ym(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final run = store.payrun(month);
    final lines = run?.lines ?? store.draftLines(month);
    double sum(double Function(dynamic) f) => lines.fold(0.0, (s, l) => s + f(l));
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Penggajian'), actions: [
        IconButton(
          tooltip: 'Ringkasan tahunan (Borang EA)',
          icon: const Icon(Icons.summarize_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const YearSummaryScreen())),
        ),
        IconButton(
          tooltip: 'PDF ringkasan gaji dan bayaran bank',
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: lines.isEmpty
              ? null
              : () async => sharePdf(
                  await payrollPdf(store.settings.name, month, lines, finalised: run != null), 'gaji-$month.pdf'),
        ),
      ]),
      body: PageList(children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => month = addMonths(month, -1)), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Column(children: [
              Text(monthLabel(month), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Tag(run == null ? 'Draf' : 'Dimuktamadkan ${fmtDate(ymd(run.createdAt))}', tone: run == null ? 'warn' : 'ok'),
            ]),
          ),
          IconButton(onPressed: () => setState(() => month = addMonths(month, 1)), icon: const Icon(Icons.chevron_right)),
        ]),
        FigureStrip(items: [
          Figure(label: 'Bersih dibayar', value: rm(sum((l) => l.net))),
          Figure(label: 'Gaji kasar', value: rm(sum((l) => l.gross))),
          Figure(label: 'KWSP majikan', value: rm(sum((l) => l.epfEr))),
          Figure(label: 'PCB dipotong', value: rm(sum((l) => l.pcb))),
        ]),
        Card(
          clipBehavior: Clip.antiAlias,
          child: lines.isEmpty
              ? const Padding(padding: EdgeInsets.all(24), child: Text('Tiada pekerja bergaji untuk dikira.'))
              : Column(children: [
                  for (var i = 0; i < lines.length; i++) ...[
                    if (i > 0) const Divider(indent: 68),
                    ListTile(
                      leading: Avatar(store.employeeById(lines[i].empId)),
                      title: Text(lines[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        'Kasar ${rm(lines[i].gross)}${lines[i].overtime > 0 ? ' · OT ${rm(lines[i].overtime)}' : ''}'
                        '${lines[i].bonus + lines[i].commission > 0 ? ' · bonus/komisen ${rm(lines[i].bonus + lines[i].commission)}' : ''}'
                        '${lines[i].otherDeduction > 0 ? ' · potongan ${rm(lines[i].otherDeduction)}' : ''}'
                        '${lines[i].claims > 0 ? ' · tuntutan ${rm(lines[i].claims)}' : ''}',
                        style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      trailing: Text(rm(lines[i].net), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => PayslipDetail(month: month, line: lines[i], draft: run == null))),
                    ),
                  ],
                ]),
        ),
        if (run == null)
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: lines.isEmpty ? null : () => _confirm(context, lines.length, sum((l) => l.net)),
            icon: const Icon(Icons.check),
            label: const Text('Muktamadkan dan keluarkan slip'),
          )
        else
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () => store.reopenPayroll(month),
            child: const Text('Buka semula sebagai draf'),
          ),
        Text(
          'Anggaran: KWSP ikut pembundaran Jadual Ketiga, PERKESO dan SIP ikut bracket RM100 (siling RM6,000), '
          'PCB dikira secara tahunan ringkas. OT ikut ORP = gaji pokok ÷ 26 ÷ 8.',
          style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ]),
    );
  }

  Future<void> _confirm(BuildContext context, int n, double net) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Muktamadkan gaji ${monthLabel(month)}?'),
        content: Text('$n slip gaji akan dikeluarkan kepada pekerja. Jumlah bersih ${rm(net)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Muktamadkan')),
        ],
      ),
    );
    if (ok != true) return;
    await store.finalizePayroll(month);
    messenger.showSnackBar(SnackBar(content: Text('Gaji ${monthLabel(month)} dimuktamadkan')));
  }
}
