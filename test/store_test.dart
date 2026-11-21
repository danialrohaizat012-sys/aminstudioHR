import 'package:flutter_test/flutter_test.dart';
import 'package:pejabat_hr/models.dart';
import 'package:pejabat_hr/store.dart';

void main() {
  // Wednesday 18 Nov 2026, 10:15. Amin Photo Studio closes on Friday.
  HrStore make() => HrStore(clock: () => DateTime(2026, 11, 18, 10, 15))..seedForTest();

  test('leave counts working days only (Friday closed) and supports half days', () {
    final s = make();
    expect(s.workdays('2026-11-19', '2026-11-22'), 3); // Thu, Sat, Sun
    expect(s.leaveDays('2026-11-19', '2026-11-19', 'am'), .5);
    expect(s.leaveDays('2026-11-20', '2026-11-20', null), 0); // Friday
  });

  test('approving leave reduces the balance', () async {
    final s = make();
    await s.signIn('e2');
    final before = s.leaveBalance('e2', 'Cuti Tahunan')!;
    await s.submitLeave(type: 'Cuti Tahunan', from: '2026-11-24', to: '2026-11-25');
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
    expect(line.overtime, closeTo(2800 / 26 / 8 * 2 * 4, .01));
    expect(line.gross, closeTo(2800 + 150 + line.overtime, .01));
  });

  test('finalised payroll produces payslips for the employee', () async {
    final s = make();
    await s.signIn('admin');
    await s.finalizePayroll('2026-11');
    expect(s.payslipsOf('e1').first.$1, '2026-11');
  });

  group('punch', () {
    // Office at Jalan Kuala Krai, Kota Bharu (approximate), 150 m radius.
    const officeLat = 6.1180, officeLng = 102.2420;
    const selfie = 'aGVsbG8='; // any base64 payload

    test('punch inside the radius records distance and selfie', () async {
      final s = make();
      await s.setOffice(officeLat, officeLng);
      await s.signIn('e2');
      expect(await s.punchIn(lat: 6.1182, lng: 102.2421, accuracy: 12, photo: selfie), isNull);
      final rec = s.attendanceOn('e2', '2026-11-18')!;
      expect(rec.clockIn, '10:15');
      expect(rec.inMark!.distance, lessThan(50));
      expect(rec.inMark!.photo, selfie);
      expect(s.isFlagged(rec.inMark), isFalse);
      expect(s.dayStatus(s.employeeById('e2')!, '2026-11-18'), DayStatus.late);
    });

    test('punch is refused while the phone location is off', () async {
      final s = make();
      await s.signIn('e2');
      final err = await s.punchIn(photo: selfie);
      expect(err, contains('Lokasi'));
      expect(s.attendanceOn('e2', '2026-11-18'), isNull);
    });

    test('selfie is required by default and can be switched off by the manager', () async {
      final s = make();
      await s.signIn('e2');
      expect(s.settings.requireSelfie, isTrue);
      expect(await s.punchIn(lat: officeLat, lng: officeLng), contains('Selfie'));
      s.settings.requireSelfie = false;
      expect(await s.punchIn(lat: officeLat, lng: officeLng), isNull);
    });

    test('punch far away needs a reason and is flagged for HR', () async {
      final s = make();
      await s.setOffice(officeLat, officeLng);
      await s.signIn('e2');
      final d = s.distanceToOffice(6.0570, 102.2040);
      expect(d, greaterThan(5000));
      expect(await s.punchIn(lat: 6.0570, lng: 102.2040, photo: selfie), contains('sebab'));
      expect(await s.punchIn(lat: 6.0570, lng: 102.2040, photo: selfie, note: 'Penggambaran kahwin'), isNull);
      expect(s.isFlagged(s.attendanceOn('e2', '2026-11-18')!.inMark), isTrue);
    });

    test('cannot punch in twice or punch out before punching in', () async {
      final s = make();
      await s.signIn('e2');
      expect(await s.punchOut(lat: officeLat, lng: officeLng, photo: selfie), isNotNull);
      expect(await s.punchIn(lat: officeLat, lng: officeLng, photo: selfie), isNull);
      expect(await s.punchIn(lat: officeLat, lng: officeLng, photo: selfie), isNotNull);
      expect(await s.punchOut(lat: officeLat, lng: officeLng, photo: selfie), isNull);
      expect(s.attendanceOn('e2', '2026-11-18')!.clockOut, '10:15');
    });

    test('only HR can correct attendance', () async {
      final s = make();
      await s.signIn('e2');
      await s.correctAttendance('e2', '2026-11-17', '08:00', '17:00');
      expect(s.attendanceOn('e2', '2026-11-17')?.clockIn, isNot('08:00'));
      await s.signIn('admin');
      await s.correctAttendance('e2', '2026-11-17', '08:00', '17:00');
      final rec = s.attendanceOn('e2', '2026-11-17')!;
      expect(rec.clockIn, '08:00');
      expect(rec.editedBy, 'Nurul Huda Ismail');
    });
  });
}
