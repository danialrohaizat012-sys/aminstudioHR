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

  group('attendance detail', () {
    test('breaks are subtracted from hours worked and closed at punch out', () async {
      var t = DateTime(2026, 11, 18, 9, 30);
      final s = HrStore(clock: () => t)..seedForTest();
      s.settings.requireSelfie = false;
      await s.signInForTest('e2');
      await s.punchIn(lat: 6.118, lng: 102.242, address: 'Jalan Kuala Krai', device: 'Pixel 7');
      t = DateTime(2026, 11, 18, 13, 0);
      expect(await s.startBreak('Rehat makan'), isNull);
      expect(await s.startBreak('Solat'), isNotNull); // one break at a time
      t = DateTime(2026, 11, 18, 14, 0);
      expect(await s.endBreak(), isNull);
      t = DateTime(2026, 11, 18, 15, 0);
      await s.startBreak('Solat');
      t = DateTime(2026, 11, 18, 17, 30); // leaves early, still on break
      await s.punchOut(lat: 6.118, lng: 102.242);
      final rec = s.attendanceOn('e2', '2026-11-18')!;
      expect(rec.breaks.map((b) => b.end), ['14:00', '17:30']);
      expect(s.workedMinutes(rec), 8 * 60 - 60 - 150); // 09:30–17:30 less 1h and 2h30
      expect(s.lateMinutes(rec), 30);
      expect(s.isEarlyLeave(rec), isTrue);
      expect(rec.inMark!.address, 'Jalan Kuala Krai');
      expect(rec.inMark!.device, 'Pixel 7');
      expect(rec.inMark!.mapUrl, contains('6.118,102.242'));
    });

    test('monthly summary counts late days, minutes and absences', () async {
      final s = HrStore(clock: () => DateTime(2026, 11, 30, 20, 0))..seedForTest();
      s.attendance.clear();
      void day(String d, String inT, String outT) =>
          s.attendance['e3_$d'] = AttendanceRecord(empId: 'e3', date: d, clockIn: inT, clockOut: outT);
      day('2026-11-02', '09:20', '18:00'); // late 20
      day('2026-11-03', '08:55', '18:00');
      day('2026-11-04', '09:05', '17:00'); // late 5, early leave
      final sum = s.monthSummary(s.employeeById('e3')!, '2026-11');
      expect(sum.late, 2);
      expect(sum.lateMinutes, 25);
      expect(sum.lateDays, ['2026-11-02', '2026-11-04']);
      expect(sum.present, 3);
      expect(sum.earlyLeave, 1);
      expect(sum.absent, greaterThan(15)); // the other working days of November
      expect(sum.absentDays, isNot(contains('2026-11-06'))); // Friday is a closed day
    });
  });

  group('audit round 2', () {
    test('approving your own request reports an error instead of success', () async {
      final s = make();
      await s.signInForTest('admin');
      await s.submitClaim(category: 'Makan', date: '2026-11-17', amount: 20);
      final id = s.requestsOf('admin').first.id;
      expect(await s.decide(id, ReqStatus.approved), contains('pengurus lain'));
    });

    test('reject reason is kept and shown to the employee as a new decision', () async {
      final s = make();
      await s.signInForTest('admin');
      final r = s.pending(ReqKind.leave).firstWhere((r) => r.empId == 'e2');
      expect(await s.decide(r.id, ReqStatus.rejected, note: 'Kedai sibuk'), isNull);
      expect(r.decisionNote, 'Kedai sibuk');
      await s.signInForTest('e2');
      expect(s.unseenDecisions().map((x) => x.id), contains(r.id));
      await s.markDecisionsSeen();
      expect(s.unseenDecisions(), isEmpty);
    });

    test('pending leave counts against the balance', () async {
      final s = make();
      await s.signInForTest('e2');
      final before = s.availableLeave('e2', 'Cuti Tahunan')!;
      expect(before, lessThan(s.leaveBalance('e2', 'Cuti Tahunan')!)); // seed has a pending request
      // Asking for more than what is left is refused by the store.
      final n = s.requests.length;
      await s.submitLeave(type: 'Cuti Tahunan', from: '2026-11-21', to: '2026-12-31');
      expect(s.requests.length, n);
    });

    test('public holidays are not working days', () async {
      final s = make();
      await s.signInForTest('admin');
      expect(s.workdays('2026-11-19', '2026-11-19'), 1);
      await s.addHoliday('2026-11-19', 'Cuti contoh');
      expect(s.workdays('2026-11-19', '2026-11-19'), 0);
      expect(s.settings.holidayNames['2026-11-19'], 'Cuti contoh');
      await s.removeHoliday('2026-11-19');
      expect(s.workdays('2026-11-19', '2026-11-19'), 1);
    });

    test('a manager can appoint another manager but cannot demote themself', () async {
      final s = make();
      await s.signInForTest('admin');
      Employee copy(Employee e, bool admin) =>
          Employee(id: e.id, name: e.name, joinDate: e.joinDate, salary: e.salary, isAdmin: admin);
      await s.saveEmployee(copy(s.employeeById('e1')!, true));
      expect(s.employeeById('e1')!.isAdmin, isTrue);
      await s.saveEmployee(copy(s.employeeById('admin')!, false));
      expect(s.employeeById('admin')!.isAdmin, isTrue);
    });

    test('profile photos: yourself, or anyone as a manager', () async {
      final s = make();
      await s.signInForTest('e2');
      await s.setProfilePhoto('e3', 'eA==');
      expect(s.employeeById('e3')!.photo, isNull);
      await s.setProfilePhoto('e2', 'eA==');
      expect(s.employeeById('e2')!.photo, 'eA==');
      await s.signInForTest('admin');
      await s.setProfilePhoto('e3', 'eQ==');
      expect(s.employeeById('e3')!.photo, 'eQ==');
    });

    test('bonus and deductions flow into the payslip and lock after finalising', () async {
      final s = make();
      await s.signInForTest('admin');
      final e = s.employeeById('e2')!;
      final base = s.computeLine(e, '2026-11');
      expect(await s.setAdjustment('2026-11', 'e2', PayAdjustment(bonus: 500, otherDeduction: 100, note: 'Pendahuluan')), isNull);
      final l = s.computeLine(e, '2026-11');
      expect(l.gross, base.gross + 500);
      expect(l.epfEe, greaterThan(base.epfEe));
      expect(l.net, closeTo(l.gross - l.epfEe - l.socsoEe - l.eisEe - l.pcb - 100 + l.claims, .01));
      await s.finalizePayroll('2026-11');
      expect(await s.setAdjustment('2026-11', 'e2', PayAdjustment(bonus: 1)), contains('dimuktamadkan'));
      final year = s.yearTotals(2026);
      expect(year.firstWhere((r) => r.name == e.name).gross, closeTo(l.gross + base.gross, 1)); // Oct + Nov
    });

    test('length of service and statutory leave minimums', () {
      final s = make();
      final e = s.employeeById('e1')!; // joined 1 Mar 2019
      expect(HrStore.serviceYears(e, s.now), 7);
      expect(HrStore.statutoryLeave(e, s.now).annual, 16);
      final e3 = s.employeeById('e3')!; // joined Feb 2025, 8 days annual
      expect(HrStore.statutoryLeave(e3, s.now).annual, 8);
      e.leaveAnnual = 12;
      expect(s.belowStatutoryLeave(), contains(e));
    });
  });
}
