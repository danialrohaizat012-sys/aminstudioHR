import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';
import 'models.dart';
import 'payroll.dart';

/// Single source of truth for the app. Screens read from it and call its
/// methods; it notifies listeners and persists to the device.
///
/// To move to a real backend, keep these method signatures and replace
/// [_load]/[_save] with API calls.
class HrStore extends ChangeNotifier {
  HrStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const _key = 'pejabat_hr_v1';
  final DateTime Function() _clock;
  DateTime get now => _clock();

  List<Employee> employees = [];
  List<HrRequest> requests = [];
  Map<String, AttendanceRecord> attendance = {};
  List<Announcement> announcements = [];
  List<PayRun> payruns = [];
  CompanySettings settings = CompanySettings();
  List<AuditEntry> audit = [];
  Map<String, int> failedPins = {};
  Map<String, String> lockedUntil = {}; // empId -> ISO time
  Map<String, PayAdjustment> adjustments = {}; // '<yyyy-mm>_<empId>'
  Map<String, String> seenUpTo = {}; // empId -> ISO time the employee last opened their requests

  static const maxPinAttempts = 5;
  static const demoPin = '246810';
  static const lockMinutes = 5;

  String? currentUserId;
  bool loaded = false;

  /// Appearance on this device: 'system', 'light' or 'dark'.
  String themeChoice = 'system';

  Future<void> setTheme(String choice) async {
    themeChoice = choice;
    await _commit();
  }

  // ---------------------------------------------------------------- session
  Employee? get me => currentUserId == null ? null : employeeById(currentUserId!);
  bool get isAdmin => me?.isAdmin ?? false;

  static String hashPin(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  bool needsPin(String empId) => employeeById(empId)?.pinHash == null;

  /// Minutes left on a lockout after too many wrong PINs, or 0.
  int lockMinutesLeft(String empId) {
    final until = lockedUntil[empId];
    if (until == null) return 0;
    final left = DateTime.parse(until).difference(now).inSeconds;
    return left <= 0 ? 0 : (left / 60).ceil();
  }

  /// Signs in with a PIN. Returns null on success or the reason it failed.
  Future<String?> signIn(String empId, String pin) async {
    final e = employeeById(empId);
    if (e == null || !e.active) return 'Akaun tidak aktif.';
    final locked = lockMinutesLeft(empId);
    if (locked > 0) return 'Terlalu banyak cubaan salah. Cuba lagi dalam $locked minit.';
    if (e.pinHash == null) return 'PIN belum ditetapkan.';
    if (hashPin(pin, e.pinSalt ?? '') != e.pinHash) {
      final n = (failedPins[empId] ?? 0) + 1;
      failedPins[empId] = n;
      if (n >= maxPinAttempts) {
        failedPins.remove(empId);
        lockedUntil[empId] = now.add(const Duration(minutes: lockMinutes)).toIso8601String();
        await _commit();
        return 'PIN salah $maxPinAttempts kali. Akaun dikunci $lockMinutes minit.';
      }
      await _commit();
      return 'PIN salah. ${maxPinAttempts - n} cubaan lagi.';
    }
    failedPins.remove(empId);
    lockedUntil.remove(empId);
    currentUserId = empId;
    await _commit();
    return null;
  }

  /// First sign-in on an account without a PIN: choose one.
  Future<String?> createPin(String empId, String pin) async {
    final e = employeeById(empId);
    if (e == null || e.pinHash != null) return 'PIN sudah ditetapkan.';
    final err = pinProblem(pin);
    if (err != null) return err;
    _setPin(e, pin);
    currentUserId = empId;
    await _commit();
    return null;
  }

  Future<String?> changePin(String oldPin, String newPin) async {
    final e = me!;
    if (hashPin(oldPin, e.pinSalt ?? '') != e.pinHash) return 'PIN lama salah.';
    final err = pinProblem(newPin);
    if (err != null) return err;
    _setPin(e, newPin);
    await _commit();
    return null;
  }

  /// Manager clears an employee's PIN; they choose a new one at next sign-in.
  Future<void> resetPin(String empId) async {
    if (!isAdmin) return;
    final e = employeeById(empId)!;
    e.pinHash = null;
    e.pinSalt = null;
    lockedUntil.remove(empId);
    failedPins.remove(empId);
    _log('Set semula PIN', e.name);
    await _commit();
  }

  static String? pinProblem(String pin) {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) return 'PIN mesti 6 digit.';
    if (RegExp(r'^(\d)\1{5}$').hasMatch(pin) || '0123456789'.contains(pin) || '9876543210'.contains(pin)) {
      return 'PIN terlalu mudah diteka. Elak nombor berulang atau berturutan.';
    }
    return null;
  }

  void _setPin(Employee e, String pin) {
    final salt = List.generate(16, (_) => math.Random.secure().nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    e.pinSalt = salt;
    e.pinHash = hashPin(pin, salt);
  }

  @visibleForTesting
  Future<void> signInForTest(String empId) async {
    currentUserId = empId;
    notifyListeners();
  }

  void _log(String action, [String detail = '']) {
    audit.insert(0, AuditEntry(at: now, by: me?.name ?? 'Sistem', action: action, detail: detail));
    if (audit.length > 500) audit.removeRange(500, audit.length);
  }

  /// Decisions on my requests I have not looked at yet.
  List<HrRequest> unseenDecisions() {
    final e = me;
    if (e == null) return [];
    final since = seenUpTo[e.id];
    return requests
        .where((r) =>
            r.empId == e.id &&
            r.decidedAt != null &&
            (since == null || r.decidedAt!.isAfter(DateTime.parse(since))))
        .toList();
  }

  Future<void> markDecisionsSeen() async {
    if (me == null || unseenDecisions().isEmpty) return;
    seenUpTo[me!.id] = now.toIso8601String();
    await _commit();
  }

  /// Full years of service on [at] (default today).
  static int serviceYears(Employee e, DateTime at) {
    var y = at.year - e.joinDate.year;
    if (at.month < e.joinDate.month || (at.month == e.joinDate.month && at.day < e.joinDate.day)) y--;
    return y < 0 ? 0 : y;
  }

  /// Employment Act 1955 minimum paid leave for the length of service:
  /// annual 8/12/16 days and sick 14/18/22 days (<2, 2–5, 5+ years).
  static ({int annual, int sick}) statutoryLeave(Employee e, DateTime at) {
    final y = serviceYears(e, at);
    if (y < 2) return (annual: 8, sick: 14);
    if (y < 5) return (annual: 12, sick: 18);
    return (annual: 16, sick: 22);
  }

  /// Active employees whose leave entitlement is below the statutory minimum.
  List<Employee> belowStatutoryLeave() => activeEmployees.where((e) {
        final m = statutoryLeave(e, now);
        return e.leaveAnnual < m.annual || e.leaveMedical < m.sick;
      }).toList();

  /// Days of [type] still available after approved and pending requests.
  double? availableLeave(String empId, String type) {
    final b = leaveBalance(empId, type);
    return b == null ? null : b - usedLeave(empId, type, status: ReqStatus.pending);
  }

  Future<void> addHoliday(String date, String name) async {
    if (!isAdmin) return;
    if (!settings.holidays.contains(date)) settings.holidays.add(date);
    settings.holidays.sort();
    settings.holidayNames[date] = name;
    _log('Tambah cuti umum', '$date $name');
    await _commit();
  }

  Future<void> removeHoliday(String date) async {
    if (!isAdmin) return;
    settings.holidays.remove(date);
    final name = settings.holidayNames.remove(date) ?? '';
    _log('Buang cuti umum', '$date $name');
    await _commit();
  }

  Future<void> deleteAnnouncement(String id) async {
    if (!isAdmin) return;
    final a = announcements.where((x) => x.id == id).firstOrNull;
    if (a == null) return;
    announcements.remove(a);
    _log('Padam pengumuman', a.title);
    await _commit();
  }

  /// Set or clear a profile picture: your own, or anyone's as a manager.
  Future<void> setProfilePhoto(String empId, String? photo) async {
    if (me == null || (empId != me!.id && !isAdmin)) return;
    final e = employeeById(empId)!;
    e.photo = photo;
    if (empId != me!.id) _log(photo == null ? 'Buang gambar profil' : 'Tukar gambar profil', e.name);
    await _commit();
  }

  Future<void> recordConsent() async {
    me!.consentAt = now.toIso8601String();
    await _commit();
  }

  Future<void> signOut() async {
    currentUserId = null;
    await _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------- queries
  Employee? employeeById(String id) {
    for (final e in employees) {
      if (e.id == id) return e;
    }
    return null;
  }

  String nameOf(String id) => employeeById(id)?.name ?? '(bekas pekerja)';

  List<Employee> get activeEmployees =>
      employees.where((e) => e.active).toList()..sort((a, b) => a.name.compareTo(b.name));

  /// Staff who clock in (everyone active except pure admin accounts).
  List<Employee> get staff => activeEmployees.where((e) => !e.isAdmin || e.salary > 0).toList();

  List<HrRequest> requestsOf(String empId, [ReqKind? kind]) => requests
      .where((r) => r.empId == empId && (kind == null || r.kind == kind))
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<HrRequest> pending([ReqKind? kind]) => requests
      .where((r) => r.status == ReqStatus.pending && (kind == null || r.kind == kind))
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  bool isWorkday(DateTime d) {
    final wd = d.weekday; // Mon=1 .. Sun=7
    return !settings.weekendDays.contains(wd) && !settings.holidays.contains(ymd(d));
  }

  double workdays(String from, String to) {
    var d = parseYmd(from);
    final end = parseYmd(to);
    var n = 0;
    while (!d.isAfter(end)) {
      if (isWorkday(d)) n++;
      d = d.add(const Duration(days: 1));
    }
    return n.toDouble();
  }

  double leaveDays(String from, String to, String? half) {
    final n = workdays(from, to);
    return half != null && from == to ? math.min(n, 0.5) : n;
  }

  int entitlement(Employee e, String type) => switch (type) {
        'Cuti Tahunan' => e.leaveAnnual,
        'Cuti Sakit' => e.leaveMedical,
        _ => -1,
      };

  double usedLeave(String empId, String type, {ReqStatus status = ReqStatus.approved}) {
    final yr = '${now.year}';
    return requests
        .where((r) =>
            r.kind == ReqKind.leave &&
            r.empId == empId &&
            r.leaveType == type &&
            r.status == status &&
            (r.from ?? '').startsWith(yr))
        .fold(0.0, (s, r) => s + r.days);
  }

  /// Remaining days, or null for leave types without a fixed entitlement.
  double? leaveBalance(String empId, String type) {
    final e = employeeById(empId);
    if (e == null) return null;
    final ent = entitlement(e, type);
    if (ent < 0) return null;
    return ent - usedLeave(empId, type);
  }

  AttendanceRecord? attendanceOn(String empId, String date) => attendance['${empId}_$date'];

  List<AttendanceRecord> attendanceOf(String empId, String monthKey) =>
      attendance.values.where((a) => a.empId == empId && a.date.startsWith(monthKey)).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  bool isLate(AttendanceRecord a) => a.clockIn != null && a.clockIn!.compareTo(settings.startTime) > 0;

  List<HrRequest> onLeave(String date) => requests
      .where((r) =>
          r.kind == ReqKind.leave &&
          r.status == ReqStatus.approved &&
          r.from!.compareTo(date) <= 0 &&
          r.to!.compareTo(date) >= 0)
      .toList();

  PayRun? payrun(String month) {
    for (final p in payruns) {
      if (p.month == month) return p;
    }
    return null;
  }

  List<(String, PayLine)> payslipsOf(String empId) {
    final out = <(String, PayLine)>[];
    for (final p in payruns) {
      for (final l in p.lines) {
        if (l.empId == empId) out.add((p.month, l));
      }
    }
    out.sort((a, b) => b.$1.compareTo(a.$1));
    return out;
  }

  double overtimePay(HrRequest r) {
    final e = employeeById(r.empId);
    if (e == null) return 0;
    return round2(hourlyOrp(e.salary) * r.rate * r.hours);
  }

  PayLine computeLine(Employee e, String month) {
    final ot = round2(requests
        .where((r) =>
            r.kind == ReqKind.overtime &&
            r.empId == e.id &&
            r.status == ReqStatus.approved &&
            (r.date ?? '').startsWith(month))
        .fold(0.0, (s, r) => s + overtimePay(r)));
    final claims = round2(requests
        .where((r) =>
            r.kind == ReqKind.claim &&
            r.empId == e.id &&
            r.status == ReqStatus.approved &&
            (r.date ?? '').startsWith(month))
        .fold(0.0, (s, r) => s + r.amount));
    final unpaidDays = requests
        .where((r) =>
            r.kind == ReqKind.leave &&
            r.empId == e.id &&
            r.leaveType == 'Cuti Tanpa Gaji' &&
            r.status == ReqStatus.approved)
        .fold(0.0, (s, r) => s + _daysInMonth(r, month));
    final unpaid = round2(e.salary / 26 * unpaidDays);
    final adj = adjustments['${month}_${e.id}'] ?? PayAdjustment();
    // Bonus and commission are treated as part of this month's wages for EPF,
    // SOCSO, EIS and the simplified PCB.
    final gross = round2(e.salary + e.allowance + ot + adj.bonus + adj.commission + adj.extraAllowance - unpaid);
    final st = statutory(gross);
    final ded = st.epfEe + st.socsoEe + st.eisEe + st.pcb;
    return PayLine(
      empId: e.id,
      name: e.name,
      position: e.position,
      ic: e.ic,
      bank: e.bank,
      bankAcc: e.bankAcc,
      basic: e.salary,
      allowance: e.allowance,
      overtime: ot,
      unpaidLeave: unpaid,
      gross: gross,
      epfEe: st.epfEe,
      epfEr: st.epfEr,
      socsoEe: st.socsoEe,
      socsoEr: st.socsoEr,
      eisEe: st.eisEe,
      eisEr: st.eisEr,
      pcb: st.pcb,
      claims: claims,
      net: round2(gross - ded - adj.otherDeduction + claims),
      bonus: adj.bonus,
      commission: adj.commission,
      extraAllowance: adj.extraAllowance,
      otherDeduction: adj.otherDeduction,
      adjustNote: adj.note,
    );
  }

  double _daysInMonth(HrRequest r, String month) {
    if (r.from == r.to) return r.from!.startsWith(month) ? r.days : 0;
    final start = '$month-01';
    final p = month.split('-');
    final end = ymd(DateTime(int.parse(p[0]), int.parse(p[1]) + 1, 0));
    final a = r.from!.compareTo(start) > 0 ? r.from! : start;
    final b = r.to!.compareTo(end) < 0 ? r.to! : end;
    return b.compareTo(a) < 0 ? 0 : workdays(a, b);
  }

  List<PayLine> draftLines(String month) =>
      staff.where((e) => e.salary > 0).map((e) => computeLine(e, month)).toList();

  // ---------------------------------------------------------------- actions
  String _id() => '${now.microsecondsSinceEpoch}${math.Random().nextInt(999)}';

  /// Metres from the office, or null when either point is unknown.
  double? distanceToOffice(double? lat, double? lng) {
    if (lat == null || lng == null || !settings.hasOffice) return null;
    return haversineM(lat, lng, settings.officeLat!, settings.officeLng!);
  }

  /// Whether a punch at this distance needs a reason (and is flagged for HR).
  bool outsideArea(double? distance) =>
      settings.requireLocation && settings.hasOffice && (distance == null || distance > settings.radiusM);

  bool isFlagged(PunchMark? m) => m != null && m.note.isNotEmpty;

  PunchMark _mark(
          {double? lat, double? lng, double? accuracy, String? photo, String note = '', String? address, String? device}) =>
      PunchMark(
        time: hm(now),
        lat: lat,
        lng: lng,
        accuracy: accuracy,
        distance: distanceToOffice(lat, lng),
        photo: photo,
        note: note,
        address: address,
        device: device,
      );

  /// Why a punch cannot be recorded, or null when it can. Location is always
  /// required: a punch is refused while the phone's location is off.
  String? punchBlocker({double? lat, double? lng, String? photo, String note = '', bool mocked = false}) {
    if (lat == null || lng == null) {
      return 'Lokasi telefon perlu dihidupkan untuk punch.';
    }
    if (mocked) {
      return 'Lokasi palsu (mock location) dikesan. Matikan app lokasi palsu dan cuba lagi.';
    }
    if (settings.requireSelfie && (photo == null || photo.isEmpty)) {
      return 'Selfie wajib sebagai bukti punch.';
    }
    if (outsideArea(distanceToOffice(lat, lng)) && note.trim().isEmpty) {
      return 'Nyatakan sebab punch di luar kawasan kedai.';
    }
    return null;
  }

  /// Returns null on success, or the reason the punch was refused.
  Future<String?> punchIn(
      {double? lat,
      double? lng,
      double? accuracy,
      String? photo,
      String note = '',
      bool mocked = false,
      String? address,
      String? device}) async {
    final e = me!;
    final d = ymd(now);
    if (attendanceOn(e.id, d)?.clockIn != null) return 'Anda sudah punch masuk hari ini.';
    final blocked = punchBlocker(lat: lat, lng: lng, photo: photo, note: note, mocked: mocked);
    if (blocked != null) return blocked;
    attendance['${e.id}_$d'] = AttendanceRecord(
      empId: e.id,
      date: d,
      clockIn: hm(now),
      inMark: _mark(lat: lat, lng: lng, accuracy: accuracy, photo: photo, note: note, address: address, device: device),
    );
    await _commit();
    return null;
  }

  /// Returns null on success, or the reason the punch was refused.
  Future<String?> punchOut(
      {double? lat,
      double? lng,
      double? accuracy,
      String? photo,
      String note = '',
      bool mocked = false,
      String? address,
      String? device}) async {
    final rec = attendanceOn(me!.id, ymd(now));
    if (rec == null || rec.clockIn == null) return 'Punch masuk dahulu.';
    if (rec.clockOut != null) return 'Anda sudah punch keluar hari ini.';
    final blocked = punchBlocker(lat: lat, lng: lng, photo: photo, note: note, mocked: mocked);
    if (blocked != null) return blocked;
    rec.openBreak?.end = hm(now); // punching out ends any break still running
    rec.clockOut = hm(now);
    rec.outMark = _mark(lat: lat, lng: lng, accuracy: accuracy, photo: photo, note: note, address: address, device: device);
    await _commit();
    return null;
  }

  /// Start a break (meal, prayers) while clocked in.
  Future<String?> startBreak(String label) async {
    final rec = attendanceOn(me!.id, ymd(now));
    if (rec?.clockIn == null || rec!.clockOut != null) return 'Punch masuk dahulu.';
    if (rec.openBreak != null) return 'Anda sedang berehat.';
    rec.breaks.add(BreakSession(label: label, start: hm(now)));
    await _commit();
    return null;
  }

  Future<String?> endBreak() async {
    final rec = attendanceOn(me!.id, ymd(now));
    final b = rec?.openBreak;
    if (b == null) return 'Tiada rehat yang sedang berjalan.';
    b.end = hm(now);
    await _commit();
    return null;
  }

  static int _min(String t) => int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(3, 5));

  /// Minutes of one break; a running break counts up to now (today) or to
  /// clock-out.
  int breakMinutes(BreakSession b, {String? until}) {
    final end = b.end ?? until ?? hm(now);
    return math.max(0, _min(end) - _min(b.start));
  }

  /// Minutes worked: clock-in to clock-out (or now while still clocked in
  /// today), less breaks.
  int workedMinutes(AttendanceRecord r) {
    if (r.clockIn == null) return 0;
    final end = r.clockOut ?? (r.date == ymd(now) ? hm(now) : r.clockIn!);
    final gross = math.max(0, _min(end) - _min(r.clockIn!));
    final breaks = r.breaks.fold<int>(0, (s, b) => s + breakMinutes(b, until: end));
    return math.max(0, gross - breaks);
  }

  /// Minutes after the start time, or 0.
  int lateMinutes(AttendanceRecord r) =>
      r.clockIn == null ? 0 : math.max(0, _min(r.clockIn!) - _min(settings.startTime));

  /// One employee's month: days present, late (with total minutes and dates),
  /// absent, on leave, early leaves and hours worked. Counts up to today.
  MonthSummary monthSummary(Employee e, String month) {
    final p = month.split('-');
    final first = DateTime(int.parse(p[0]), int.parse(p[1]), 1);
    final last = DateTime(first.year, first.month + 1, 0);
    final today = DateTime(now.year, now.month, now.day);
    final sum = MonthSummary();
    for (var d = first; !d.isAfter(last) && !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      final key = ymd(d);
      if (e.joinDate.isAfter(d)) continue;
      final status = dayStatus(e, key);
      final rec = attendanceOn(e.id, key);
      if (status == DayStatus.restDay && rec?.clockIn == null) continue;
      sum.workdays++;
      switch (status) {
        case DayStatus.present:
        case DayStatus.late:
          sum.present++;
          sum.workedMinutes += workedMinutes(rec!);
          if (status == DayStatus.late) {
            sum.lateDays.add(key);
            sum.lateMinutes += lateMinutes(rec);
          }
          if (isEarlyLeave(rec)) sum.earlyLeave++;
          if (isFlagged(rec.inMark) || isFlagged(rec.outMark)) sum.outside++;
        case DayStatus.onLeave:
          sum.leave++;
        case DayStatus.absent:
          // Today does not count as absent until the day is over.
          if (key != ymd(now)) sum.absentDays.add(key);
        case DayStatus.restDay:
        case DayStatus.upcoming:
          break;
      }
    }
    return sum;
  }

  bool isEarlyLeave(AttendanceRecord r) =>
      r.clockOut != null && r.clockOut!.compareTo(settings.endTime) < 0 && isWorkday(parseYmd(r.date));

  /// HR correction of a day's times. Clearing both removes the record.
  Future<void> correctAttendance(String empId, String date, String? clockIn, String? clockOut) async {
    if (!isAdmin) return;
    final key = '${empId}_$date';
    if (clockIn == null && clockOut == null) {
      attendance.remove(key);
    } else {
      final rec = attendance[key] ?? AttendanceRecord(empId: empId, date: date);
      rec.clockIn = clockIn;
      rec.clockOut = clockOut;
      rec.editedBy = me!.name;
      attendance[key] = rec;
    }
    _log('Betulkan kehadiran', '${nameOf(empId)} · $date · ${clockIn ?? '—'} → ${clockOut ?? '—'}');
    await _commit();
  }

  /// Status of one employee on one day, for the HR attendance board.
  DayStatus dayStatus(Employee e, String date) {
    final rec = attendanceOn(e.id, date);
    if (rec?.clockIn != null) {
      return isLate(rec!) ? DayStatus.late : DayStatus.present;
    }
    if (onLeave(date).any((r) => r.empId == e.id)) return DayStatus.onLeave;
    if (!isWorkday(parseYmd(date))) return DayStatus.restDay;
    if (date.compareTo(ymd(now)) > 0) return DayStatus.upcoming;
    return DayStatus.absent;
  }

  /// Dates the owner should not miss in the next [days] days (and anything
  /// already overdue in the last 7): probation and contract ends, birthdays,
  /// work anniversaries.
  List<Reminder> reminders({int days = 30}) {
    final today = DateTime(now.year, now.month, now.day);
    final out = <Reminder>[];
    void add(String? ymdStr, String title, Employee e, String tone) {
      if (ymdStr == null) return;
      final d = parseYmd(ymdStr);
      final diff = d.difference(today).inDays;
      if (diff >= -7 && diff <= days) out.add(Reminder(date: d, title: title, empId: e.id, tone: diff < 0 ? 'bad' : tone));
    }

    DateTime nextYearly(int month, int day) {
      final d = DateTime(today.year, month, day);
      return d.isBefore(today) ? DateTime(today.year + 1, month, day) : d;
    }

    for (final e in activeEmployees) {
      add(e.probationEnd, 'Tamat percubaan ${e.firstName}', e, 'warn');
      add(e.contractEnd, 'Kontrak ${e.firstName} tamat', e, 'warn');
      final b = e.birthDate;
      if (b != null) {
        final d = nextYearly(b.month, b.day);
        if (d.difference(today).inDays <= 14) out.add(Reminder(date: d, title: 'Hari jadi ${e.firstName}', empId: e.id));
      }
      final j = e.joinDate;
      final a = nextYearly(j.month, j.day);
      final years = a.year - j.year;
      if (years > 0 && a.difference(today).inDays <= 14) {
        out.add(Reminder(date: a, title: '$years tahun ${e.firstName} bersama syarikat', empId: e.id));
      }
    }
    for (final e in belowStatutoryLeave()) {
      out.add(Reminder(date: today, title: 'Cuti ${e.firstName} bawah minimum Akta Kerja', empId: e.id, tone: 'warn'));
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  Future<void> setOffice(double lat, double lng) async {
    if (!isAdmin) return;
    _log('Tetapkan lokasi kedai', '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}');
    settings.officeLat = lat;
    settings.officeLng = lng;
    await _commit();
  }

  Future<void> submitLeave({
    required String type,
    required String from,
    required String to,
    String? half,
    String note = '',
  }) async {
    final days = leaveDays(from, to, from == to ? half : null);
    final avail = availableLeave(me!.id, type);
    if (days <= 0 || (type == 'Cuti Tahunan' && avail != null && avail - days < 0)) return;
    requests.add(HrRequest(
      id: _id(),
      kind: ReqKind.leave,
      empId: me!.id,
      createdAt: now,
      leaveType: type,
      from: from,
      to: to,
      halfDay: from == to ? half : null,
      days: leaveDays(from, to, half),
      note: note,
    ));
    await _commit();
  }

  Future<void> submitClaim({
    required String category,
    required String date,
    required double amount,
    String note = '',
    String? receipt,
  }) async {
    if (amount <= 0 || amount > 50000) return;
    requests.add(HrRequest(
      id: _id(),
      kind: ReqKind.claim,
      empId: me!.id,
      createdAt: now,
      category: category,
      date: date,
      amount: amount,
      note: note,
      receipt: receipt,
    ));
    await _commit();
  }

  Future<void> submitOvertime({
    required String date,
    required double hours,
    required double rate,
    String note = '',
  }) async {
    if (hours <= 0 || hours > 12) return;
    requests.add(HrRequest(
      id: _id(),
      kind: ReqKind.overtime,
      empId: me!.id,
      createdAt: now,
      date: date,
      hours: hours,
      rate: rate,
      note: note,
    ));
    await _commit();
  }

  Future<void> withdraw(String id) async {
    requests.removeWhere((r) => r.id == id && r.empId == me?.id && r.status == ReqStatus.pending);
    await _commit();
  }

  /// Approve or reject. Returns null on success, or why it was refused.
  Future<String?> decide(String id, ReqStatus status, {String note = ''}) async {
    if (!isAdmin) return 'Hanya pengurus boleh membuat keputusan.';
    final r = requests.firstWhere((r) => r.id == id);
    if (r.empId == me!.id) return 'Permohonan anda sendiri perlu diputuskan oleh pengurus lain.';
    if (r.status != ReqStatus.pending) return 'Permohonan ini sudah diputuskan.';
    r.status = status;
    r.decidedAt = now;
    r.decisionNote = note.trim();
    _log(status == ReqStatus.approved ? 'Lulus ${r.kind.label.toLowerCase()}' : 'Tolak ${r.kind.label.toLowerCase()}',
        '${nameOf(r.empId)} · ${_reqSummary(r)}${r.decisionNote.isNotEmpty ? ' · "${r.decisionNote}"' : ''}');
    await _commit();
    return null;
  }

  /// Undo a decision made by mistake (the request goes back to pending).
  Future<void> undoDecision(String id) async {
    if (!isAdmin) return;
    final r = requests.firstWhere((r) => r.id == id);
    r.status = ReqStatus.pending;
    r.decidedAt = null;
    r.decisionNote = '';
    _log('Batal keputusan ${r.kind.label.toLowerCase()}', '${nameOf(r.empId)} · ${_reqSummary(r)}');
    await _commit();
  }

  String _reqSummary(HrRequest r) => switch (r.kind) {
        ReqKind.leave => '${r.leaveType} ${r.from}${r.to != r.from ? ' – ${r.to}' : ''}',
        ReqKind.claim => 'RM ${r.amount.toStringAsFixed(2)} ${r.category}',
        ReqKind.overtime => '${r.hours} jam ${r.date}',
      };

  /// Approved plus pending overtime hours in a month (Employment Act cap: 104).
  double overtimeHours(String empId, String month) => requests
      .where((r) =>
          r.kind == ReqKind.overtime &&
          r.empId == empId &&
          r.status != ReqStatus.rejected &&
          (r.date ?? '').startsWith(month))
      .fold(0.0, (s, r) => s + r.hours);

  static const overtimeCapHours = 104.0;

  Future<void> finalizePayroll(String month) async {
    if (!isAdmin) return;
    payruns.removeWhere((p) => p.month == month);
    final lines = draftLines(month);
    payruns.add(PayRun(month: month, createdAt: now, lines: lines));
    _log('Muktamadkan gaji', '$month · ${lines.length} pekerja');
    await _commit();
  }

  PayAdjustment adjustmentFor(String month, String empId) =>
      adjustments['${month}_$empId'] ?? PayAdjustment();

  Future<String?> setAdjustment(String month, String empId, PayAdjustment a) async {
    if (!isAdmin) return 'Hanya pengurus boleh mengubah gaji.';
    if (payrun(month) != null) return 'Gaji bulan ini sudah dimuktamadkan. Buka semula dahulu.';
    for (final v in [a.bonus, a.commission, a.extraAllowance, a.otherDeduction]) {
      if (v < 0 || v > 100000) return 'Nilai tidak sah.';
    }
    final key = '${month}_$empId';
    if (a.isEmpty) {
      adjustments.remove(key);
    } else {
      adjustments[key] = a;
    }
    _log('Pelarasan gaji', '${nameOf(empId)} · $month · bonus ${a.bonus.toStringAsFixed(2)}, '
        'komisen ${a.commission.toStringAsFixed(2)}, elaun ${a.extraAllowance.toStringAsFixed(2)}, '
        'potongan ${a.otherDeduction.toStringAsFixed(2)}');
    await _commit();
    return null;
  }

  /// Year-to-date totals per employee from finalised payroll, for Borang EA.
  List<({Employee? emp, String name, String ic, double gross, double epf, double socso, double eis, double pcb, int months})>
      yearTotals(int year) {
    final acc = <String, Map<String, double>>{};
    final names = <String, (String, String)>{};
    for (final p in payruns.where((p) => p.month.startsWith('$year-'))) {
      for (final l in p.lines) {
        final m = acc.putIfAbsent(l.empId, () => {'gross': 0, 'epf': 0, 'socso': 0, 'eis': 0, 'pcb': 0, 'n': 0});
        m['gross'] = m['gross']! + l.gross;
        m['epf'] = m['epf']! + l.epfEe;
        m['socso'] = m['socso']! + l.socsoEe;
        m['eis'] = m['eis']! + l.eisEe;
        m['pcb'] = m['pcb']! + l.pcb;
        m['n'] = m['n']! + 1;
        names[l.empId] = (l.name, l.ic);
      }
    }
    return [
      for (final e in acc.entries)
        (
          emp: employeeById(e.key),
          name: names[e.key]!.$1,
          ic: names[e.key]!.$2,
          gross: round2(e.value['gross']!),
          epf: round2(e.value['epf']!),
          socso: round2(e.value['socso']!),
          eis: round2(e.value['eis']!),
          pcb: round2(e.value['pcb']!),
          months: e.value['n']!.toInt(),
        )
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<void> reopenPayroll(String month) async {
    if (!isAdmin) return;
    payruns.removeWhere((p) => p.month == month);
    _log('Buka semula gaji', month);
    await _commit();
  }

  Future<void> saveEmployee(Employee e) async {
    if (!isAdmin) return;
    final i = employees.indexWhere((x) => x.id == e.id);
    if (i >= 0) {
      final old = employees[i];
      final changes = <String>[
        if (old.salary != e.salary) 'gaji ${old.salary.toStringAsFixed(2)} → ${e.salary.toStringAsFixed(2)}',
        if (old.allowance != e.allowance) 'elaun ${old.allowance.toStringAsFixed(2)} → ${e.allowance.toStringAsFixed(2)}',
        if (old.bankAcc != e.bankAcc) 'akaun bank ditukar',
        if (old.active != e.active) e.active ? 'diaktifkan semula' : 'ditanda berhenti',
      ];
      if (old.isAdmin && !e.isAdmin && old.id == me!.id) e.isAdmin = true; // cannot demote yourself
      if (old.isAdmin != e.isAdmin) changes.add(e.isAdmin ? 'dilantik pengurus' : 'akses pengurus ditarik');
      // Keep credentials and consent; the form never edits them.
      e
        ..pinHash = old.pinHash
        ..pinSalt = old.pinSalt
        ..consentAt = old.consentAt
        ..photo = old.photo;
      employees[i] = e;
      _log('Kemas kini pekerja', [e.name, ...changes].join(' · '));
    } else {
      employees.add(e);
      _log('Tambah pekerja', '${e.name} · gaji ${e.salary.toStringAsFixed(2)}');
    }
    await _commit();
  }

  String newEmployeeId() => 'e${_id()}';

  Future<void> postAnnouncement(String title, String body, bool pinned) async {
    if (!isAdmin) return;
    _log('Terbit pengumuman', title);
    announcements.add(Announcement(id: _id(), title: title, body: body, createdAt: now, pinned: pinned));
    await _commit();
  }

  Future<void> updateSettings(CompanySettings s) async {
    if (!isAdmin) return;
    settings = s;
    _log('Kemas kini tetapan',
        'mula ${s.startTime} · radius ${s.radiusM.round()} m · selfie ${s.requireSelfie ? 'wajib' : 'tidak wajib'}');
    await _commit();
  }

  Future<void> resetDemo() async {
    _seed();
    audit = [];
    adjustments = {};
    seenUpTo = {};
    failedPins = {};
    lockedUntil = {};
    currentUserId = null;
    await _commit();
  }

  // ---------------------------------------------------------------- persistence
  Future<void> _commit() async {
    notifyListeners();
    await _save();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) {
      _seed();
      await _save();
    } else {
      try {
        _fromJson(jsonDecode(raw));
      } catch (_) {
        _seed();
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_toJson()));
    } catch (_) {
      // Storage unavailable (tests, private browsing): keep working in memory.
    }
  }

  Map<String, dynamic> _toJson() => {
        'employees': employees.map((e) => e.toJson()).toList(),
        'requests': requests.map((e) => e.toJson()).toList(),
        'attendance': attendance.values.map((e) => e.toJson()).toList(),
        'announcements': announcements.map((e) => e.toJson()).toList(),
        'payruns': payruns.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
        'audit': audit.map((a) => a.toJson()).toList(),
        'failedPins': failedPins,
        'lockedUntil': lockedUntil,
        'seenUpTo': seenUpTo,
        'themeChoice': themeChoice,
        'adjustments': adjustments.map((k, v) => MapEntry(k, v.toJson())),
        'currentUserId': currentUserId,
      };

  void _fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> list(String k) =>
        (j[k] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    employees = list('employees').map(Employee.fromJson).toList();
    requests = list('requests').map(HrRequest.fromJson).toList();
    attendance = {
      for (final a in list('attendance').map(AttendanceRecord.fromJson)) a.key: a,
    };
    announcements = list('announcements').map(Announcement.fromJson).toList();
    payruns = list('payruns').map(PayRun.fromJson).toList();
    settings = CompanySettings.fromJson(Map<String, dynamic>.from(j['settings'] ?? {}));
    audit = list('audit').map(AuditEntry.fromJson).toList();
    failedPins = Map<String, int>.from(j['failedPins'] ?? {});
    lockedUntil = Map<String, String>.from(j['lockedUntil'] ?? {});
    seenUpTo = Map<String, String>.from(j['seenUpTo'] ?? {});
    themeChoice = j['themeChoice'] ?? 'system';
    adjustments = (j['adjustments'] as Map? ?? {})
        .map((k, v) => MapEntry(k as String, PayAdjustment.fromJson(Map<String, dynamic>.from(v))));
    currentUserId = j['currentUserId'];
  }

  /// Example company so every screen has something to show on first launch.
  /// "Set semula data demo" in Profil restores it.
  void seedForTest() => _seed();

  void _seed() {
    final t = now;
    employees = [
      Employee(
        id: 'admin', name: 'Nurul Huda Ismail', position: 'Pengurus HR', dept: 'Sumber Manusia',
        email: 'nurul@contoh.my', joinDate: DateTime(2018, 4, 2), salary: 7200, allowance: 300,
        ic: '880412-10-5566', bank: 'Maybank', bankAcc: '5140 2233 8890',
        leaveAnnual: 16, leaveMedical: 22, isAdmin: true,
      ),
      Employee(
        id: 'e1', name: 'Aisyah Rahman', position: 'Pengurus Operasi', dept: 'Operasi',
        email: 'aisyah@contoh.my', phone: '012-345 6789', joinDate: DateTime(2019, 3, 1),
        salary: 6500, allowance: 300, ic: '920315-10-5522', bank: 'Maybank', bankAcc: '5140 1234 5678',
        leaveAnnual: 16, leaveMedical: 22,
      ),
      Employee(
        id: 'e2', name: 'Hafiz Kamal', position: 'Eksekutif Akaun', dept: 'Kewangan',
        email: 'hafiz@contoh.my', phone: '013-222 3344', joinDate: DateTime(2023, 6, 12),
        salary: 3800, ic: '970822-14-6631', bank: 'CIMB', bankAcc: '8001 234 567',
        leaveAnnual: 12, leaveMedical: 18,
      ),
      Employee(
        id: 'e3', name: 'Mei Ling Tan', position: 'Juruteknik', dept: 'Operasi',
        email: 'meiling@contoh.my', phone: '016-778 8990', joinDate: DateTime(2025, 2, 3),
        salary: 2800, allowance: 150, ic: '990105-07-4410', bank: 'Bank Islam', bankAcc: '1203 4010 5566',
      ),
      Employee(
        id: 'e4', name: 'Arun Kumar', position: 'Eksekutif Jualan', dept: 'Jualan',
        email: 'arun@contoh.my', phone: '017-552 1180', joinDate: DateTime(2021, 9, 15),
        salary: 4200, allowance: 400, ic: '940728-08-6013', bank: 'Public Bank', bankAcc: '3198 7765 01',
        leaveAnnual: 12, leaveMedical: 18,
      ),
    ];

    // Ten working days of attendance, today only for some staff.
    attendance = {};
    final rnd = math.Random(7);
    var d = t.subtract(const Duration(days: 35)); // a full month for the summary
    while (!d.isAfter(t)) {
      if (isWorkday(d)) {
        for (final e in employees) {
          final isToday = ymd(d) == ymd(t);
          if (isToday && (e.id == 'e2' || e.id == 'e1' || t.hour < 8)) continue;
          final lateMin = rnd.nextInt(10) == 0 ? 10 + rnd.nextInt(25) : -rnd.nextInt(20);
          final inT = DateTime(d.year, d.month, d.day, 9).add(Duration(minutes: lateMin));
          final outT = DateTime(d.year, d.month, d.day, 18).add(Duration(minutes: rnd.nextInt(25) - (rnd.nextInt(12) == 0 ? 40 : 0)));
          const devices = {
            'admin': 'iPhone 15',
            'e1': 'Samsung SM-A556E',
            'e2': 'iPhone 14 Plus',
            'e3': 'Xiaomi Redmi Note 13',
            'e4': 'OPPO CPH2591',
          };
          PunchMark mark(DateTime at) => PunchMark(
                time: hm(at),
                lat: 6.1180 + (rnd.nextDouble() - .5) * .0006,
                lng: 102.2420 + (rnd.nextDouble() - .5) * .0006,
                accuracy: 8 + rnd.nextInt(20).toDouble(),
                address: 'Jalan Kuala Krai, Kampung Sireh, Kota Bharu, Kelantan, 15050',
                device: devices[e.id],
              );
          attendance['${e.id}_${ymd(d)}'] = AttendanceRecord(
            empId: e.id,
            date: ymd(d),
            clockIn: hm(inT),
            clockOut: isToday ? null : hm(outT),
            inMark: mark(inT),
            outMark: isToday ? null : mark(outT),
            breaks: isToday ? [] : [BreakSession(label: 'Rehat makan & solat', start: '13:0${rnd.nextInt(9)}', end: '14:0${rnd.nextInt(9)}')],
          );
        }
      }
      d = d.add(const Duration(days: 1));
    }

    String day(int offset) => ymd(t.add(Duration(days: offset)));
    DateTime ago(int days) => t.subtract(Duration(days: days));
    requests = [
      HrRequest(id: 'r1', kind: ReqKind.leave, empId: 'e2', createdAt: ago(1), leaveType: 'Cuti Tahunan',
          from: day(3), to: day(5), days: workdays(day(3), day(5)), note: 'Balik kampung'),
      HrRequest(id: 'r2', kind: ReqKind.claim, empId: 'e3', createdAt: ago(2), category: 'Tol & Parkir',
          date: day(-3), amount: 42, note: 'Servis pelanggan di Klang'),
      HrRequest(id: 'r3', kind: ReqKind.overtime, empId: 'e3', createdAt: ago(4), date: day(-5), hours: 4,
          rate: 2, note: 'Penyelenggaraan mesin', status: ReqStatus.approved, decidedAt: ago(3)),
      HrRequest(id: 'r4', kind: ReqKind.claim, empId: 'e1', createdAt: ago(6), category: 'Perjalanan / Minyak',
          date: day(-7), amount: 186.40, note: 'Lawatan tapak Shah Alam', status: ReqStatus.approved, decidedAt: ago(5)),
      HrRequest(id: 'r5', kind: ReqKind.leave, empId: 'e1', createdAt: ago(20), leaveType: 'Cuti Sakit',
          from: day(-18), to: day(-18), days: 1, note: 'Demam', status: ReqStatus.approved, decidedAt: ago(18)),
      HrRequest(id: 'r6', kind: ReqKind.leave, empId: 'e4', createdAt: ago(0), leaveType: 'Cuti Tahunan',
          from: day(1), to: day(1), days: 0.5, halfDay: 'pm', note: 'Urusan bank'),
    ];

    announcements = [
      Announcement(id: 'a1', title: 'Gaji dikreditkan pada 28 haribulan', pinned: true, createdAt: ago(3),
          body: 'Sila hantar tuntutan bulan ini sebelum 25 haribulan supaya dibayar bersama gaji.'),
      Announcement(id: 'a2', title: 'Latihan keselamatan kebakaran', createdAt: ago(8),
          body: 'Semua staf diminta berkumpul di lobi pada Jumaat ini jam 3 petang.'),
    ];

    // Demo PIN for every sample account; change it under Profil.
    for (final e in employees) {
      _setPin(e, demoPin);
    }
    employees.firstWhere((e) => e.id == 'e3').probationEnd = day(12);
    employees.firstWhere((e) => e.id == 'e4').contractEnd = day(25);

    final prev = addMonths(ym(t), -1);
    payruns = [
      PayRun(
        month: prev,
        createdAt: ago(t.day + 2),
        lines: employees.where((e) => e.salary > 0).map((e) => computeLine(e, prev)).toList(),
      ),
    ];
    settings = CompanySettings();
  }
}

class MonthSummary {
  int workdays = 0, present = 0, leave = 0, earlyLeave = 0, outside = 0;
  int lateMinutes = 0, workedMinutes = 0;
  final List<String> lateDays = [], absentDays = [];

  int get late => lateDays.length;
  int get absent => absentDays.length;
}

class Reminder {
  const Reminder({required this.date, required this.title, this.empId, this.tone = 'mute'});
  final DateTime date;
  final String title;
  final String? empId;
  final String tone;
}

enum DayStatus { present, late, onLeave, absent, restDay, upcoming }

extension DayStatusLabel on DayStatus {
  String get label => switch (this) {
        DayStatus.present => 'Hadir',
        DayStatus.late => 'Lewat',
        DayStatus.onLeave => 'Bercuti',
        DayStatus.absent => 'Tiada rekod',
        DayStatus.restDay => 'Hari rehat',
        DayStatus.upcoming => '—',
      };
  String get tone => switch (this) {
        DayStatus.present => 'ok',
        DayStatus.late => 'warn',
        DayStatus.absent => 'bad',
        _ => 'mute',
      };
}

/// Great-circle distance in metres.
double haversineM(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Makes the store available to every widget below it and rebuilds them
/// when it changes.
class StoreScope extends InheritedNotifier<HrStore> {
  const StoreScope({super.key, required HrStore store, required super.child})
      : super(notifier: store);

  static HrStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
