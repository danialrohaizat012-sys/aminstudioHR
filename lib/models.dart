// Data model for Amin Studio HR.
//
// Every record serialises to plain JSON so the local store can persist it,
// and so a remote backend (Supabase, Firebase, REST) can replace it later
// without touching the screens.

enum ReqStatus { pending, approved, rejected }

extension ReqStatusLabel on ReqStatus {
  String get label => switch (this) {
        ReqStatus.pending => 'Menunggu',
        ReqStatus.approved => 'Diluluskan',
        ReqStatus.rejected => 'Ditolak',
      };
}

enum ReqKind { leave, claim, overtime }

extension ReqKindLabel on ReqKind {
  String get label => switch (this) {
        ReqKind.leave => 'Cuti',
        ReqKind.claim => 'Tuntutan',
        ReqKind.overtime => 'Lebih masa',
      };
}

const leaveTypes = <String>[
  'Cuti Tahunan',
  'Cuti Sakit',
  'Cuti Kecemasan',
  'Cuti Tanpa Gaji',
  'Cuti Bersalin',
  'Cuti Paterniti',
];

const claimCategories = <String>[
  'Perjalanan / Minyak',
  'Tol & Parkir',
  'Makan',
  'Perubatan',
  'Telefon',
  'Penginapan',
  'Lain-lain',
];

class Employee {
  Employee({
    required this.id,
    required this.name,
    this.position = '',
    this.dept = '',
    this.email = '',
    this.phone = '',
    this.ic = '',
    this.bank = '',
    this.bankAcc = '',
    required this.joinDate,
    this.salary = 0,
    this.allowance = 0,
    this.leaveAnnual = 8,
    this.leaveMedical = 14,
    this.isAdmin = false,
    this.active = true,
  });

  final String id;
  String name, position, dept, email, phone, ic, bank, bankAcc;
  DateTime joinDate;
  double salary, allowance;
  int leaveAnnual, leaveMedical;
  bool isAdmin, active;

  String get firstName => name.split(' ').first;
  String get initials => name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'position': position,
        'dept': dept,
        'email': email,
        'phone': phone,
        'ic': ic,
        'bank': bank,
        'bankAcc': bankAcc,
        'joinDate': joinDate.toIso8601String(),
        'salary': salary,
        'allowance': allowance,
        'leaveAnnual': leaveAnnual,
        'leaveMedical': leaveMedical,
        'isAdmin': isAdmin,
        'active': active,
      };

  factory Employee.fromJson(Map<String, dynamic> j) => Employee(
        id: j['id'],
        name: j['name'] ?? '',
        position: j['position'] ?? '',
        dept: j['dept'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        ic: j['ic'] ?? '',
        bank: j['bank'] ?? '',
        bankAcc: j['bankAcc'] ?? '',
        joinDate: DateTime.parse(j['joinDate']),
        salary: (j['salary'] ?? 0).toDouble(),
        allowance: (j['allowance'] ?? 0).toDouble(),
        leaveAnnual: j['leaveAnnual'] ?? 8,
        leaveMedical: j['leaveMedical'] ?? 14,
        isAdmin: j['isAdmin'] ?? false,
        active: j['active'] ?? true,
      );
}

/// One request type for leave, claims and overtime, so approvals, history
/// and notifications are handled by the same code.
class HrRequest {
  HrRequest({
    required this.id,
    required this.kind,
    required this.empId,
    required this.createdAt,
    this.status = ReqStatus.pending,
    this.decidedAt,
    this.leaveType,
    this.from,
    this.to,
    this.days = 0,
    this.halfDay,
    this.category,
    this.amount = 0,
    this.date,
    this.hours = 0,
    this.rate = 1.5,
    this.note = '',
  });

  final String id;
  final ReqKind kind;
  final String empId;
  final DateTime createdAt;
  ReqStatus status;
  DateTime? decidedAt;

  // leave
  String? leaveType;
  String? from, to; // yyyy-mm-dd
  double days;
  String? halfDay; // 'am' | 'pm'
  // claim
  String? category;
  double amount;
  // claim + overtime
  String? date; // yyyy-mm-dd
  // overtime
  double hours, rate;

  String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'empId': empId,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'decidedAt': decidedAt?.toIso8601String(),
        'leaveType': leaveType,
        'from': from,
        'to': to,
        'days': days,
        'halfDay': halfDay,
        'category': category,
        'amount': amount,
        'date': date,
        'hours': hours,
        'rate': rate,
        'note': note,
      };

  factory HrRequest.fromJson(Map<String, dynamic> j) => HrRequest(
        id: j['id'],
        kind: ReqKind.values.byName(j['kind']),
        empId: j['empId'],
        createdAt: DateTime.parse(j['createdAt']),
        status: ReqStatus.values.byName(j['status']),
        decidedAt:
            j['decidedAt'] == null ? null : DateTime.parse(j['decidedAt']),
        leaveType: j['leaveType'],
        from: j['from'],
        to: j['to'],
        days: (j['days'] ?? 0).toDouble(),
        halfDay: j['halfDay'],
        category: j['category'],
        amount: (j['amount'] ?? 0).toDouble(),
        date: j['date'],
        hours: (j['hours'] ?? 0).toDouble(),
        rate: (j['rate'] ?? 1.5).toDouble(),
        note: j['note'] ?? '',
      );
}

/// One side of a punch: where and how it was made.
class PunchMark {
  PunchMark({required this.time, this.lat, this.lng, this.accuracy, this.distance, this.photo, this.note = ''});

  final String time; // HH:mm
  final double? lat, lng, accuracy; // accuracy in metres
  final double? distance; // metres from the office, when both are known
  final String? photo; // base64 JPEG selfie
  final String note; // reason given when punching outside the area

  bool get hasLocation => lat != null && lng != null;

  Map<String, dynamic> toJson() => {
        'time': time,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'distance': distance,
        'photo': photo,
        'note': note,
      };

  factory PunchMark.fromJson(Map<String, dynamic> j) => PunchMark(
        time: j['time'],
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        accuracy: (j['accuracy'] as num?)?.toDouble(),
        distance: (j['distance'] as num?)?.toDouble(),
        photo: j['photo'],
        note: j['note'] ?? '',
      );
}

class AttendanceRecord {
  AttendanceRecord({
    required this.empId,
    required this.date,
    this.clockIn,
    this.clockOut,
    this.inMark,
    this.outMark,
    this.editedBy,
  });

  final String empId;
  final String date; // yyyy-mm-dd
  String? clockIn, clockOut; // HH:mm
  PunchMark? inMark, outMark; // null for records entered by HR
  String? editedBy; // set when HR corrected the times

  String get key => '${empId}_$date';

  Map<String, dynamic> toJson() => {
        'empId': empId,
        'date': date,
        'in': clockIn,
        'out': clockOut,
        'inMark': inMark?.toJson(),
        'outMark': outMark?.toJson(),
        'editedBy': editedBy,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        empId: j['empId'],
        date: j['date'],
        clockIn: j['in'],
        clockOut: j['out'],
        inMark: j['inMark'] == null ? null : PunchMark.fromJson(Map<String, dynamic>.from(j['inMark'])),
        outMark: j['outMark'] == null ? null : PunchMark.fromJson(Map<String, dynamic>.from(j['outMark'])),
        editedBy: j['editedBy'],
      );
}

class Announcement {
  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.pinned = false,
  });

  final String id;
  String title, body;
  final DateTime createdAt;
  bool pinned;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'createdAt': createdAt.toIso8601String(),
        'pinned': pinned,
      };

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'],
        title: j['title'],
        body: j['body'],
        createdAt: DateTime.parse(j['createdAt']),
        pinned: j['pinned'] ?? false,
      );
}

/// One employee's computed pay for one month. Stored as a snapshot when the
/// month is finalised, so later salary edits never change an issued slip.
class PayLine {
  PayLine({
    required this.empId,
    required this.name,
    required this.position,
    required this.ic,
    required this.bank,
    required this.bankAcc,
    required this.basic,
    required this.allowance,
    required this.overtime,
    required this.unpaidLeave,
    required this.gross,
    required this.epfEe,
    required this.epfEr,
    required this.socsoEe,
    required this.socsoEr,
    required this.eisEe,
    required this.eisEr,
    required this.pcb,
    required this.claims,
    required this.net,
  });

  final String empId, name, position, ic, bank, bankAcc;
  final double basic, allowance, overtime, unpaidLeave, gross;
  final double epfEe, epfEr, socsoEe, socsoEr, eisEe, eisEr, pcb;
  final double claims, net;

  double get deductions => epfEe + socsoEe + eisEe + pcb;
  double get employerCost => gross + epfEr + socsoEr + eisEr + claims;

  Map<String, dynamic> toJson() => {
        'empId': empId,
        'name': name,
        'position': position,
        'ic': ic,
        'bank': bank,
        'bankAcc': bankAcc,
        'basic': basic,
        'allowance': allowance,
        'overtime': overtime,
        'unpaidLeave': unpaidLeave,
        'gross': gross,
        'epfEe': epfEe,
        'epfEr': epfEr,
        'socsoEe': socsoEe,
        'socsoEr': socsoEr,
        'eisEe': eisEe,
        'eisEr': eisEr,
        'pcb': pcb,
        'claims': claims,
        'net': net,
      };

  factory PayLine.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] ?? 0).toDouble();
    return PayLine(
      empId: j['empId'],
      name: j['name'],
      position: j['position'] ?? '',
      ic: j['ic'] ?? '',
      bank: j['bank'] ?? '',
      bankAcc: j['bankAcc'] ?? '',
      basic: d('basic'),
      allowance: d('allowance'),
      overtime: d('overtime'),
      unpaidLeave: d('unpaidLeave'),
      gross: d('gross'),
      epfEe: d('epfEe'),
      epfEr: d('epfEr'),
      socsoEe: d('socsoEe'),
      socsoEr: d('socsoEr'),
      eisEe: d('eisEe'),
      eisEr: d('eisEr'),
      pcb: d('pcb'),
      claims: d('claims'),
      net: d('net'),
    );
  }
}

class PayRun {
  PayRun({required this.month, required this.createdAt, required this.lines});

  final String month; // yyyy-mm
  final DateTime createdAt;
  final List<PayLine> lines;

  double get totalNet => lines.fold(0, (s, l) => s + l.net);
  double get totalGross => lines.fold(0, (s, l) => s + l.gross);

  Map<String, dynamic> toJson() => {
        'month': month,
        'createdAt': createdAt.toIso8601String(),
        'lines': lines.map((l) => l.toJson()).toList(),
      };

  factory PayRun.fromJson(Map<String, dynamic> j) => PayRun(
        month: j['month'],
        createdAt: DateTime.parse(j['createdAt']),
        lines: (j['lines'] as List)
            .map((e) => PayLine.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class CompanySettings {
  CompanySettings({
    this.name = 'Amin Photo Studio',
    this.startTime = '09:00',
    List<int>? weekendDays,
    List<String>? holidays,
    this.officeLat,
    this.officeLng,
    this.radiusM = 150,
    this.requireLocation = true,
    this.requireSelfie = true,
  })  : holidays = holidays ?? [],
        weekendDays = weekendDays ?? [DateTime.friday];

  String name;
  String startTime; // HH:mm, punch after this is late
  List<int> weekendDays; // DateTime.monday (1) .. DateTime.sunday (7); the shop closes on Friday
  List<String> holidays; // yyyy-mm-dd

  // Punch rules. The area check only applies once HR has set the office
  // location (Profil > Tetapan syarikat > Guna lokasi semasa).
  double? officeLat, officeLng;
  double radiusM;
  bool requireLocation; // outside the radius needs a reason and is flagged
  bool requireSelfie; // photo proof on every punch (on by default)

  bool get hasOffice => officeLat != null && officeLng != null;

  Map<String, dynamic> toJson() => {
        'name': name,
        'startTime': startTime,
        'weekendDays': weekendDays,
        'holidays': holidays,
        'officeLat': officeLat,
        'officeLng': officeLng,
        'radiusM': radiusM,
        'requireLocation': requireLocation,
        'requireSelfie': requireSelfie,
      };

  factory CompanySettings.fromJson(Map<String, dynamic> j) => CompanySettings(
        name: j['name'] ?? '',
        startTime: j['startTime'] ?? '09:00',
        weekendDays: j['weekendDays'] != null
            ? List<int>.from(j['weekendDays'])
            : j['weekendFriSat'] == true
                ? [DateTime.friday, DateTime.saturday]
                : j['weekendFriSat'] == false
                    ? [DateTime.saturday, DateTime.sunday]
                    : null,
        holidays: List<String>.from(j['holidays'] ?? const []),
        officeLat: (j['officeLat'] as num?)?.toDouble(),
        officeLng: (j['officeLng'] as num?)?.toDouble(),
        radiusM: (j['radiusM'] as num?)?.toDouble() ?? 150,
        requireLocation: j['requireLocation'] ?? true,
        requireSelfie: j['requireSelfie'] ?? true,
      );
}
