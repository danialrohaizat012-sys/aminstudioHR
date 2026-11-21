import 'package:flutter_test/flutter_test.dart';
import 'package:pejabat_hr/models.dart';
import 'package:pejabat_hr/services/staff_import.dart';
import 'package:pejabat_hr/store.dart';

void main() {
  // Wednesday 18 Nov 2026, 10:15. Amin Photo Studio closes on Friday.
  HrStore make() => HrStore(clock: () => DateTime(2026, 11, 18, 10, 15))..seedForTest();

  group('roster', () {
    test('shift decides late, early leave and days off', () async {
      final s = make();
      await s.signInForTest('admin');
      // Normal day by default; Friday closed.
      expect(s.shiftFor('e2', '2026-11-18')!.id, 'biasa');
      expect(s.shiftFor('e2', '2026-11-20'), isNull);
      // Petang shift 13:00-22:00: 12:55 is on time, 21:30 is early.
      await s.setRoster('e2', '2026-11-17', 'petang');
      s.attendance['e2_2026-11-17'] = AttendanceRecord(empId: 'e2', date: '2026-11-17', clockIn: '12:55', clockOut: '21:30');
      final r = s.attendanceOn('e2', '2026-11-17')!;
      expect(s.isLate(r), isFalse);
      expect(s.isEarlyLeave(r), isTrue);
      // Working the closed Friday through the roster makes it a working day.
      await s.setRoster('e2', '2026-11-20', 'kahwin');
      expect(s.dayStatus(s.employeeById('e2')!, '2026-11-20'), isNot(DayStatus.restDay));
      // Day off in lieu.
      await s.setRoster('e2', '2026-11-23', 'off');
      expect(s.dayStatus(s.employeeById('e2')!, '2026-11-23'), DayStatus.restDay);
    });

    test('overnight shifts are never flagged as early leave', () async {
      final s = make();
      await s.signInForTest('admin');
      await s.saveShift(Shift(id: 'malam', name: 'Malam', start: '18:00', end: '02:00'));
      await s.setRoster('e2', '2026-11-16', 'malam');
      s.attendance['e2_2026-11-16'] = AttendanceRecord(empId: 'e2', date: '2026-11-16', clockIn: '17:58', clockOut: '23:59');
      expect(s.isEarlyLeave(s.attendanceOn('e2', '2026-11-16')!), isFalse);
    });

    test('copy last week roster', () async {
      final s = make();
      await s.signInForTest('admin');
      await s.setRoster('e1', '2026-11-09', 'petang');
      final n = await s.copyRosterWeek(DateTime(2026, 11, 9), DateTime(2026, 11, 16));
      expect(n, greaterThan(0));
      expect(s.roster['e1_2026-11-16'], 'petang');
    });

    test('employees cannot change the roster', () async {
      final s = make();
      await s.signInForTest('e2');
      await s.setRoster('e2', '2026-11-18', 'off');
      expect(s.roster.containsKey('e2_2026-11-18'), isFalse);
    });
  });

  group('jobs', () {
    test('job commission is paid with the month and locks with payroll', () async {
      final s = make();
      await s.signInForTest('admin');
      final before = s.computeLine(s.employeeById('e2')!, '2026-11');
      final job = Job(
          id: 'jx', date: '2026-11-14', title: 'Kahwin Ali & Aina', typeId: 'kahwin', staff: {'e2': 150}, createdAt: s.now);
      expect(await s.saveJob(job), isNull);
      final after = s.computeLine(s.employeeById('e2')!, '2026-11');
      expect(after.jobCommission, before.jobCommission + 150);
      expect(after.gross, before.gross + 150);
      expect(after.jobCount, before.jobCount + 1);
      await s.finalizePayroll('2026-11');
      expect(await s.deleteJob('jx'), isNotNull);
      expect(await s.saveJob(job..title = 'Ubah'), contains('dimuktamadkan'));
    });

    test('a job needs a title and staff, and only managers record jobs', () async {
      final s = make();
      await s.signInForTest('admin');
      expect(await s.saveJob(Job(id: 'a', date: '2026-11-14', title: '', typeId: 'kahwin', staff: {'e2': 1}, createdAt: s.now)),
          isNotNull);
      expect(await s.saveJob(Job(id: 'b', date: '2026-11-14', title: 'X', typeId: 'kahwin', staff: {}, createdAt: s.now)),
          isNotNull);
      await s.signInForTest('e2');
      expect(await s.saveJob(Job(id: 'c', date: '2026-11-14', title: 'X', typeId: 'kahwin', staff: {'e2': 999}, createdAt: s.now)),
          isNotNull);
    });
  });

  group('import', () {
    final today = DateTime(2026, 11, 18);
    var n = 0;
    String id() => '${n++}';

    test('reads cells pasted from Excel with Malay headers', () {
      const text = 'Nama\tJawatan\tTarikh mula\tGaji\tNo KP\n'
          'Ahmad Ali\tJurugambar\t01/03/2020\tRM 2,500.00\t900101-03-5555\n'
          'Siti Aminah\tEditor\t15-10-2026\t2100\t\n';
      final rows = parseStaff(text, existing: [], today: today, newId: id);
      expect(rows.length, 2);
      expect(rows.every((r) => r.ok), isTrue);
      final a = rows.first.employee!;
      expect(a.salary, 2500);
      expect(a.joinDate, DateTime(2020, 3, 1));
      expect(a.leaveAnnual, 16); // 6+ years of service
      expect(rows[1].employee!.probationEnd, '2027-01-15'); // joined a month ago
    });

    test('reads CSV with quotes and English headers', () {
      const text = 'Name,Position,Salary,Department\n"Tan, Mei Ling",Technician,2800,"Operasi"\n';
      final rows = parseStaff(text, existing: [], today: today, newId: id);
      expect(rows.single.employee!.name, 'Tan, Mei Ling');
      expect(rows.single.employee!.dept, 'Operasi');
    });

    test('reports bad rows and duplicates instead of importing them', () {
      final existing = [Employee(id: 'x', name: 'Ahmad Ali', joinDate: today, ic: '900101-03-5555')];
      const text = 'Nama\tGaji\tTarikh mula\tNo KP\n'
          'Ahmad Ali\t2500\t01/01/2020\t\n'
          'Baru\t\t01/01/2020\t\n'
          'Lagi\t2000\t31/02/2020\t\n'
          'Orang IC\t2000\t\t900101035555\n';
      final rows = parseStaff(text, existing: existing, today: today, newId: id);
      expect(rows[0].problems, contains('Nama sudah wujud'));
      expect(rows[1].problems, contains('Gaji tidak sah'));
      expect(rows[2].problems.single, contains('Tarikh mula'));
      expect(rows[3].problems, contains('No. KP sudah wujud'));
    });

    test('missing Nama column is explained', () {
      final rows = parseStaff('Gaji\n2000\n', existing: [], today: today, newId: id);
      expect(rows.single.problems.single, contains('Nama'));
    });
  });

  test('starting a real company leaves one manager who must create a PIN', () async {
    final s = make();
    await s.startFresh('Amin bin Abdullah', 'Amin Photo Studio');
    expect(s.employees.single.isAdmin, isTrue);
    expect(s.needsPin(s.employees.single.id), isTrue);
    expect(s.settings.setupDone, isFalse);
    expect(s.requests, isEmpty);
    expect(s.attendance, isEmpty);
    expect(await s.createPin(s.employees.single.id, '739154'), isNull);
    expect(s.isAdmin, isTrue);
    await s.importEmployees([Employee(id: 'n1', name: 'Staf Baru', joinDate: s.now, salary: 2000)]);
    expect(s.activeEmployees.length, 2);
  });

  test('fixed federal holidays', () {
    final h = HrStore.fixedHolidays(2026);
    expect(h.map((x) => x.$1), containsAll(['2026-05-01', '2026-08-31', '2026-09-16', '2026-12-25']));
    final agong = DateTime.parse(h.firstWhere((x) => x.$2.contains('Agong')).$1);
    expect(agong.weekday, DateTime.monday);
    expect(agong.month, 6);
    expect(agong.day, lessThanOrEqualTo(7));
  });
}
