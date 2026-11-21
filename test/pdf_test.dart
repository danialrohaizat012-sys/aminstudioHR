import 'package:flutter_test/flutter_test.dart';
import 'package:pejabat_hr/services/pdf_reports.dart';
import 'package:pejabat_hr/store.dart';

void main() {
  test('payslip, payroll and year PDFs are generated', () async {
    final s = HrStore(clock: () => DateTime(2026, 11, 18, 10))..seedForTest();
    final lines = s.draftLines('2026-11');
    final slip = await payslipPdf(s.settings.name, '2026-11', lines.first);
    expect(String.fromCharCodes(slip.take(4)), '%PDF');
    final run = await payrollPdf(s.settings.name, '2026-11', lines, finalised: false);
    expect(run.length, greaterThan(slip.length));
    final y = s.yearTotals(2026);
    final year = await yearPdf(s.settings.name, 2026, [
      for (final r in y) (name: r.name, ic: r.ic, gross: r.gross, epf: r.epf, socso: r.socso, eis: r.eis, pcb: r.pcb, months: r.months)
    ]);
    expect(String.fromCharCodes(year.take(4)), '%PDF');
  });
}
