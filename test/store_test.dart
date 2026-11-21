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
    await s.signInForTest('e2');
    final before = s.leaveBalance('e2', 'Cuti Tahunan')!;
    await s.submitLeave(type: 'Cuti Tahunan', from: '2026-11-24', to: '2026-11-25');
    final id = s.requestsOf('e2', ReqKind.leave).first.id;
    await s.signInForTest('admin');
    await s.decide(id, ReqStatus.approved);
    expect(s.leaveBalance('e2', 'Cuti Tahunan'), before - 2);
  });

  test('employees cannot approve requests', () async {
    final s = make();
    await s.signInForTest('e3');
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
    await s.signInForTest('admin');
    await s.finalizePayroll('2026-11');
    expect(s.payslipsOf('e1').first.$1, '2026-11');
  });

  group('punch', () {
    // Office at Jalan Kuala Krai, Kota Bharu (approximate), 150 m radius.
    const officeLat = 6.1180, officeLng = 102.2420;
    const selfie = 'aGVsbG8='; // any base64 payload

    test('punch inside the radius records distance and selfie', () async {
      final s = make();
      await s.signInForTest('admin');
      await s.setOffice(officeLat, officeLng);
      await s.signInForTest('e2');
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
      await s.signInForTest('e2');
      final err = await s.punchIn(photo: selfie);
      expect(err, contains('Lokasi'));
      expect(s.attendanceOn('e2', '2026-11-18'), isNull);
    });

    test('selfie is required by default and can be switched off by the manager', () async {
      final s = make();
      await s.signInForTest('e2');
      expect(s.settings.requireSelfie, isTrue);
      expect(await s.punchIn(lat: officeLat, lng: officeLng), contains('Selfie'));
      s.settings.requireSelfie = false;
      expect(await s.punchIn(lat: officeLat, lng: officeLng), isNull);
    });

    test('punch far away needs a reason and is flagged for HR', () async {
      final s = make();
      await s.signInForTest('admin');
      await s.setOffice(officeLat, officeLng);
      await s.signInForTest('e2');
      final d = s.distanceToOffice(6.0570, 102.2040);
      expect(d, greaterThan(5000));
      expect(await s.punchIn(lat: 6.0570, lng: 102.2040, photo: selfie), contains('sebab'));
      expect(await s.punchIn(lat: 6.0570, lng: 102.2040, photo: selfie, note: 'Penggambaran kahwin'), isNull);
      expect(s.isFlagged(s.attendanceOn('e2', '2026-11-18')!.inMark), isTrue);
    });

    test('cannot punch in twice or punch out before punching in', () async {
      final s = make();
      await s.signInForTest('e2');
      expect(await s.punchOut(lat: officeLat, lng: officeLng, photo: selfie), isNotNull);
      expect(await s.punchIn(lat: officeLat, lng: officeLng, photo: selfie), isNull);
      expect(await s.punchIn(lat: officeLat, lng: officeLng, photo: selfie), isNotNull);
      expect(await s.punchOut(lat: officeLat, lng: officeLng, photo: selfie), isNull);
      expect(s.attendanceOn('e2', '2026-11-18')!.clockOut, '10:15');
    });

    test('only HR can correct attendance', () async {
      final s = make();
      await s.signInForTest('e2');
      await s.correctAttendance('e2', '2026-11-17', '08:00', '17:00');
      expect(s.attendanceOn('e2', '2026-11-17')?.clockIn, isNot('08:00'));
      await s.signInForTest('admin');
      await s.correctAttendance('e2', '2026-11-17', '08:00', '17:00');
      final rec = s.attendanceOn('e2', '2026-11-17')!;
      expect(rec.clockIn, '08:00');
      expect(rec.editedBy, 'Nurul Huda Ismail');
    });
  });

  group('security', () {
    test('PIN is stored salted and hashed, never in plain text', () async {
      final s = make();
      final e = s.employeeById('e2')!;
      expect(e.pinHash, isNot(HrStore.demoPin));
      expect(e.pinHash, hasLength(64));
      expect(e.toJson().toString(), isNot(contains(HrStore.demoPin)));
      // Same PIN, different accounts, different hashes (per-account salt).
      expect(s.employeeById('e1')!.pinHash, isNot(e.pinHash));
    });

    test('wrong PINs count down and lock the account', () async {
      final s = make();
      expect(await s.signIn('e2', '000000'), contains('4 cubaan'));
      for (var i = 0; i < 3; i++) {
        await s.signIn('e2', '000000');
      }
      expect(await s.signIn('e2', '000000'), contains('dikunci'));
      expect(await s.signIn('e2', HrStore.demoPin), contains('Cuba lagi'));
      expect(s.me, isNull);
    });

    test('correct PIN signs in', () async {
      final s = make();
      expect(await s.signIn('e2', HrStore.demoPin), isNull);
      expect(s.me?.id, 'e2');
    });

    test('weak PINs are refused', () {
      expect(HrStore.pinProblem('111111'), isNotNull);
      expect(HrStore.pinProblem('123456'), isNotNull);
      expect(HrStore.pinProblem('12345'), isNotNull);
      expect(HrStore.pinProblem('739154'), isNull);
    });

    test('employees cannot change records, settings or the office location', () async {
      final s = make();
      await s.signInForTest('e2');
      final e = s.employeeById('e2')!;
      await s.saveEmployee(Employee(id: 'e2', name: e.name, joinDate: e.joinDate, salary: 99999));
      expect(s.employeeById('e2')!.salary, 3800);
      await s.setOffice(1, 1);
      expect(s.settings.hasOffice, isFalse);
      await s.postAnnouncement('x', 'y', false);
      expect(s.announcements.length, 2);
    });

    test('managers cannot approve their own requests', () async {
      final s = make();
      await s.signInForTest('admin');
      await s.submitClaim(category: 'Makan', date: '2026-11-17', amount: 20);
      final id = s.requestsOf('admin').first.id;
      await s.decide(id, ReqStatus.approved);
      expect(s.requests.firstWhere((r) => r.id == id).status, ReqStatus.pending);
    });

    test('decisions and salary changes are audited and can be undone', () async {
      final s = make();
      await s.signInForTest('admin');
      final id = s.pending().first.id;
      await s.decide(id, ReqStatus.approved);
      await s.undoDecision(id);
      expect(s.requests.firstWhere((r) => r.id == id).status, ReqStatus.pending);
      final e = s.employeeById('e2')!;
      await s.saveEmployee(Employee(id: 'e2', name: e.name, joinDate: e.joinDate, salary: 4000, pinHash: 'ignored'));
      expect(s.employeeById('e2')!.pinHash, e.pinHash); // the form cannot overwrite credentials
      expect(s.audit.map((a) => a.action), containsAll(['Lulus tuntutan', 'Batal keputusan tuntutan', 'Kemas kini pekerja']));
      expect(s.audit.first.detail, contains('3800.00 → 4000.00'));
    });

    test('mock (fake) GPS locations are refused', () async {
      final s = make();
      await s.signInForTest('e2');
      expect(await s.punchIn(lat: 6.118, lng: 102.242, photo: 'eA==', mocked: true), contains('palsu'));
      expect(s.attendanceOn('e2', '2026-11-18'), isNull);
    });
  });

  test('owner reminders list probation and contract ends', () {
    final s = make();
    final titles = s.reminders().map((r) => r.title).toList();
    expect(titles, contains('Tamat percubaan Mei'));
    expect(titles, contains('Kontrak Arun tamat'));
  });

  test('date of birth is read from the IC number', () {
    final s = make();
    expect(s.employeeById('e2')!.birthDate, DateTime(1997, 8, 22));
  });
}
