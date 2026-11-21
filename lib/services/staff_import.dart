// Reads a staff list pasted from Excel / Google Sheets (tab separated) or a
// CSV file, matching columns by their header in Malay or English.

import '../format.dart';
import '../models.dart';
import '../store.dart';

class ImportRow {
  ImportRow(this.line, this.employee, this.problems);
  final int line; // 1-based line in the source, for messages
  final Employee? employee;
  final List<String> problems; // empty means it can be imported

  bool get ok => employee != null && problems.isEmpty;
}

const _columns = <String, List<String>>{
  'name': ['nama', 'name', 'nama penuh', 'full name'],
  'position': ['jawatan', 'position', 'job title', 'title'],
  'dept': ['jabatan', 'department', 'dept', 'bahagian'],
  'join': ['tarikh mula', 'mula', 'join date', 'start date', 'tarikh masuk', 'mula kerja'],
  'salary': ['gaji', 'gaji pokok', 'salary', 'basic', 'basic salary'],
  'allowance': ['elaun', 'allowance', 'elaun tetap'],
  'ic': ['no kp', 'no. kp', 'kp', 'ic', 'nric', 'mykad', 'no ic'],
  'phone': ['telefon', 'phone', 'tel', 'no telefon', 'no. telefon', 'mobile'],
  'email': ['emel', 'email', 'e-mel'],
  'bank': ['bank', 'nama bank'],
  'bankAcc': ['no akaun', 'no. akaun', 'akaun', 'account', 'account no', 'akaun bank'],
};

/// Splits one CSV/TSV line, honouring quotes ("a, b").
List<String> _split(String line, String sep) {
  final out = <String>[];
  final buf = StringBuffer();
  var quoted = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (quoted && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (ch == sep && !quoted) {
      out.add(buf.toString().trim());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  out.add(buf.toString().trim());
  return out;
}

/// dd/mm/yyyy, d-m-yyyy, yyyy-mm-dd; null if unreadable.
DateTime? parseDateLoose(String s) {
  s = s.trim();
  if (s.isEmpty) return null;
  var m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(s);
  if (m != null) return _date(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  m = RegExp(r'^(\d{1,2})[/.-](\d{1,2})[/.-](\d{2,4})$').firstMatch(s);
  if (m != null) {
    var y = int.parse(m[3]!);
    if (y < 100) y += y > 50 ? 1900 : 2000;
    return _date(y, int.parse(m[2]!), int.parse(m[1]!));
  }
  return null;
}

DateTime? _date(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  final dt = DateTime(y, m, d);
  return dt.month == m ? dt : null;
}

double? _money(String s) {
  final v = s.replaceAll(RegExp(r'rm|\s|,', caseSensitive: false), '');
  return v.isEmpty ? null : double.tryParse(v);
}

/// Parses [text] into rows. [existing] is used to flag duplicates by name or IC.
List<ImportRow> parseStaff(String text, {required List<Employee> existing, required DateTime today, required String Function() newId}) {
  final lines = text.replaceAll('﻿', '').split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  if (lines.isEmpty) return [];
  final sep = lines.first.contains('\t') ? '\t' : (lines.first.contains(';') && !lines.first.contains(',') ? ';' : ',');
  final header = _split(lines.first, sep).map((h) => h.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim()).toList();
  final col = <String, int>{};
  for (final entry in _columns.entries) {
    final i = header.indexWhere((h) => entry.value.contains(h));
    if (i >= 0) col[entry.key] = i;
  }
  if (!col.containsKey('name')) {
    return [ImportRow(1, null, ['Lajur "Nama" tidak dijumpai pada baris pertama (tajuk).'])];
  }

  final seenNames = {for (final e in existing) e.name.toLowerCase()};
  final seenIc = {for (final e in existing) if (e.ic.isNotEmpty) e.ic.replaceAll('-', '')};
  final out = <ImportRow>[];
  for (var li = 1; li < lines.length; li++) {
    final cells = _split(lines[li], sep);
    String v(String k) => col[k] != null && col[k]! < cells.length ? cells[col[k]!] : '';
    final problems = <String>[];
    final name = v('name');
    if (name.isEmpty) problems.add('Nama kosong');
    final join = v('join').isEmpty ? today : parseDateLoose(v('join'));
    if (join == null) problems.add('Tarikh mula "${v('join')}" tidak dikenali (guna dd/mm/yyyy)');
    final salary = _money(v('salary'));
    if (salary == null || salary <= 0) problems.add('Gaji tidak sah');
    final ic = v('ic');
    if (name.isNotEmpty && seenNames.contains(name.toLowerCase())) problems.add('Nama sudah wujud');
    if (ic.isNotEmpty && seenIc.contains(ic.replaceAll('-', ''))) problems.add('No. KP sudah wujud');
    Employee? e;
    if (name.isNotEmpty) {
      e = Employee(
        id: 'e${newId()}',
        name: name,
        position: v('position'),
        dept: v('dept'),
        joinDate: join ?? today,
        salary: salary ?? 0,
        allowance: _money(v('allowance')) ?? 0,
        ic: ic,
        phone: v('phone'),
        email: v('email'),
        bank: v('bank'),
        bankAcc: v('bankAcc'),
      );
      final m = HrStore.statutoryLeave(e, today);
      e
        ..leaveAnnual = m.annual
        ..leaveMedical = m.sick
        ..probationEnd = today.difference(e.joinDate).inDays < 90
            ? ymd(DateTime(e.joinDate.year, e.joinDate.month + 3, e.joinDate.day))
            : null;
      seenNames.add(name.toLowerCase());
      if (ic.isNotEmpty) seenIc.add(ic.replaceAll('-', ''));
    }
    out.add(ImportRow(li + 1, e, problems));
  }
  return out;
}

/// Header row to show people what to paste.
const importTemplate = 'Nama\tJawatan\tJabatan\tTarikh mula\tGaji\tNo KP\tTelefon\tEmel\tBank\tNo akaun';
