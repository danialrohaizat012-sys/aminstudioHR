import 'package:flutter_test/flutter_test.dart';
import 'package:pejabat_hr/models.dart';
import 'package:pejabat_hr/store.dart';

void main() {
  // Wednesday 18 Nov 2026, 10:15
  HrStore make() => HrStore(clock: () => DateTime(2026, 11, 18, 10, 15))..seedForTest();

  test('leave counts working days only and supports half days', () {
    final s = make();
    expect(s.workdays('2026-11-20', '2026-11-23'), 2); // Fri + Mon
    expect(s.leaveDays('2026-11-20', '2026-11-20', 'am'), .5);
    expect(s.leaveDays('2026-11-21', '2026-11-21', null), 0); // Saturday
  });

  test('approving leave reduces the balance', () async {
    final s = make();
    await s.signIn('e2');
    final before = s.leaveBalance('e2', 'Cuti Tahunan')!;
    await s.submitLeave(type: 'Cuti Tahunan', from: '2026-11-25', to: '2026-11-26');
    final id = s.requestsOf('e2', ReqKind.leave).first.id;
    await s.signIn('admin');
    await s.decide(id, ReqStatus.approved);
    expect(s.leaveBalance('e2', 'Cuti Tahunan'), before - 2);
  });

  test('employees cannot approve requests', () async {
    final s = make();
    await s.signIn('e3');
    final id = s.pending().first.id;
    await s.decide(id, ReqStatus.approved);
    expect(s.requests.firstWhere((r) => r.id == id).status, ReqStatus.pending);
  });

  test('approved overtime and claims flow into payroll', () async {
    final s = make();
    final e3 = s.employeeById('e3')!;
    final line = s.computeLine(e3, '2026-11');
    // r3: 4h at 2x on RM2,800 basic
    expect(line.overtime, closeTo(2800 / 26 / 8 * 2 * 4, .01));
    expect(line.gross, closeTo(2800 + 150 + line.overtime, .01));
  });

  test('finalised payroll produces payslips for the employee', () async {
    final s = make();
    await s.signIn('admin');
    await s.finalizePayroll('2026-11');
    expect(s.payslipsOf('e1').first.$1, '2026-11');
  });
}
