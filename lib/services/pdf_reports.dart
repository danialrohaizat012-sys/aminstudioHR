import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../format.dart';
import '../models.dart';

// The built-in PDF font covers Latin-1 only, so money uses a plain hyphen.
String _rm(double v) => rm(v).replaceAll('−', '-');

const _ink = PdfColor.fromInt(0xFF141414);
const _muted = PdfColor.fromInt(0xFF5F5F5F);
const _line = PdfColor.fromInt(0xFFDDDDDD);
const _yellow = PdfColor.fromInt(0xFFFFCE00);

pw.Widget _header(String company, String title, String subtitle) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(children: [
          pw.Container(width: 6, height: 28, color: _yellow),
          pw.SizedBox(width: 8),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(company.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: _muted)),
          ]),
          pw.Spacer(),
          pw.Text(subtitle, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 10),
        pw.Divider(color: _line),
      ],
    );

pw.Widget _row(String k, String v, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Text(k, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null))),
        pw.Text(v, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : null)),
      ]),
    );

/// Single payslip, A5 portrait.
Future<Uint8List> payslipPdf(String company, String month, PayLine l) {
  final doc = pw.Document(title: 'Slip gaji ${l.name} ${monthLabel(month)}', author: company);
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5,
    margin: const pw.EdgeInsets.all(28),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      _header(company, 'Slip gaji', monthLabel(month)),
      pw.Text(l.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.Text([l.position, if (l.ic.isNotEmpty) 'KP ${l.ic}'].join(' | '), style: const pw.TextStyle(color: _muted)),
      if (l.bank.isNotEmpty) pw.Text('${l.bank} ${l.bankAcc}', style: const pw.TextStyle(color: _muted)),
      pw.SizedBox(height: 14),
      pw.Text('PENDAPATAN', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted)),
      _row('Gaji pokok', _rm(l.basic)),
      if (l.allowance > 0) _row('Elaun tetap', _rm(l.allowance)),
      if (l.extraAllowance > 0) _row('Elaun tambahan', _rm(l.extraAllowance)),
      if (l.overtime > 0) _row('Kerja lebih masa', _rm(l.overtime)),
      if (l.bonus > 0) _row('Bonus', _rm(l.bonus)),
      if (l.commission > 0) _row('Komisen', _rm(l.commission)),
      if (l.jobCommission > 0) _row('Komisen job (${l.jobCount} job)', _rm(l.jobCommission)),
      if (l.unpaidLeave > 0) _row('Cuti tanpa gaji', '-${_rm(l.unpaidLeave)}'),
      pw.Divider(color: _line),
      _row('Gaji kasar', _rm(l.gross), bold: true),
      pw.SizedBox(height: 10),
      pw.Text('POTONGAN', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _muted)),
      _row('KWSP (11%)', _rm(l.epfEe)),
      _row('PERKESO', _rm(l.socsoEe)),
      _row('SIP', _rm(l.eisEe)),
      _row('PCB / MTD', _rm(l.pcb)),
      if (l.otherDeduction > 0) _row('Potongan lain${l.adjustNote.isNotEmpty ? ' (${l.adjustNote})' : ''}', _rm(l.otherDeduction)),
      pw.Divider(color: _line),
      _row('Jumlah potongan', _rm(l.deductions), bold: true),
      if (l.claims > 0) ...[pw.SizedBox(height: 10), _row('Tuntutan dibayar balik', _rm(l.claims))],
      pw.SizedBox(height: 12),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        color: _yellow,
        child: _row('GAJI BERSIH', _rm(l.net), bold: true),
      ),
      pw.SizedBox(height: 12),
      pw.Text('Caruman majikan: KWSP ${_rm(l.epfEr)} | PERKESO ${_rm(l.socsoEr)} | SIP ${_rm(l.eisEr)}',
          style: const pw.TextStyle(fontSize: 8, color: _muted)),
      pw.Spacer(),
      pw.Text('Slip dijana oleh Amin Studio HR. Kiraan caruman ialah anggaran; rujuk jadual KWSP/PERKESO dan kalkulator PCB LHDN.',
          style: const pw.TextStyle(fontSize: 7, color: _muted)),
    ]),
  ));
  return doc.save();
}

/// Month payroll: totals for statutory payments and the bank transfer list.
Future<Uint8List> payrollPdf(String company, String month, List<PayLine> lines, {required bool finalised}) {
  double sum(double Function(PayLine) f) => lines.fold(0.0, (s, l) => s + f(l));
  final doc = pw.Document(title: 'Gaji ${monthLabel(month)}', author: company);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    header: (_) => _header(company, finalised ? 'Ringkasan gaji (dimuktamadkan)' : 'Ringkasan gaji (DRAF)', monthLabel(month)),
    build: (_) => [
      pw.Text('Bayaran bank', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['Nama', 'No. KP', 'Bank', 'No. akaun', 'Gaji bersih'],
        data: [for (final l in lines) [l.name, l.ic, l.bank, l.bankAcc, _rm(l.net)]],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: _yellow),
        cellAlignments: {4: pw.Alignment.centerRight},
        border: pw.TableBorder.all(color: _line),
      ),
      pw.SizedBox(height: 4),
      _row('Jumlah dipindahkan', _rm(sum((l) => l.net)), bold: true),
      pw.SizedBox(height: 18),
      pw.Text('Caruman berkanun untuk dibayar', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['Nama', 'Kasar', 'KWSP pekerja', 'KWSP majikan', 'PERKESO', 'SIP', 'PCB'],
        data: [
          for (final l in lines)
            [l.name, _rm(l.gross), _rm(l.epfEe), _rm(l.epfEr), _rm(l.socsoEe + l.socsoEr), _rm(l.eisEe + l.eisEr), _rm(l.pcb)],
          ['JUMLAH', _rm(sum((l) => l.gross)), _rm(sum((l) => l.epfEe)), _rm(sum((l) => l.epfEr)),
            _rm(sum((l) => l.socsoEe + l.socsoEr)), _rm(sum((l) => l.eisEe + l.eisEr)), _rm(sum((l) => l.pcb))],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: _yellow),
        cellAlignments: {for (var i = 1; i < 7; i++) i: pw.Alignment.centerRight},
        border: pw.TableBorder.all(color: _line),
      ),
      pw.SizedBox(height: 10),
      _row('KWSP (pekerja + majikan)', _rm(sum((l) => l.epfEe + l.epfEr))),
      _row('PERKESO (pekerja + majikan)', _rm(sum((l) => l.socsoEe + l.socsoEr))),
      _row('SIP (pekerja + majikan)', _rm(sum((l) => l.eisEe + l.eisEr))),
      _row('PCB / MTD ke LHDN', _rm(sum((l) => l.pcb))),
      _row('Jumlah kos majikan', _rm(sum((l) => l.employerCost)), bold: true),
      pw.SizedBox(height: 16),
      pw.Text('Anggaran. Sahkan dengan jadual caruman KWSP/PERKESO dan Kalkulator PCB LHDN sebelum pembayaran.',
          style: const pw.TextStyle(fontSize: 8, color: _muted)),
    ],
  ));
  return doc.save();
}

/// Year totals per employee from finalised payroll, to help fill Borang EA.
Future<Uint8List> yearPdf(
    String company, int year, List<({String name, String ic, double gross, double epf, double socso, double eis, double pcb, int months})> rows) {
  final doc = pw.Document(title: 'Ringkasan saraan $year', author: company);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4.landscape,
    margin: const pw.EdgeInsets.all(32),
    header: (_) => _header(company, 'Ringkasan saraan tahunan (untuk Borang EA)', '$year'),
    build: (_) => [
      pw.TableHelper.fromTextArray(
        headers: ['Nama', 'No. KP', 'Bulan', 'Saraan kasar', 'KWSP', 'PERKESO', 'SIP', 'PCB'],
        data: [
          for (final r in rows)
            [r.name, r.ic, '${r.months}', _rm(r.gross), _rm(r.epf), _rm(r.socso), _rm(r.eis), _rm(r.pcb)],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
        cellStyle: const pw.TextStyle(fontSize: 9),
        headerDecoration: const pw.BoxDecoration(color: _yellow),
        cellAlignments: {for (var i = 2; i < 8; i++) i: pw.Alignment.centerRight},
        border: pw.TableBorder.all(color: _line),
      ),
      pw.SizedBox(height: 10),
      pw.Text('Hanya bulan yang sudah dimuktamadkan dikira. Borang EA mesti diberi kepada pekerja sebelum 28 Februari.',
          style: const pw.TextStyle(fontSize: 8, color: _muted)),
    ],
  ));
  return doc.save();
}

/// Download on the web, share sheet on phones.
Future<void> sharePdf(Uint8List bytes, String filename) => Printing.sharePdf(bytes: bytes, filename: filename);
