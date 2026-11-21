import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../services/staff_import.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'punch_settings_screen.dart';

/// Import staff by pasting cells from Excel / Google Sheets or choosing a
/// CSV file. Rows are checked before anything is saved.
class StaffImportScreen extends StatefulWidget {
  const StaffImportScreen({super.key});
  @override
  State<StaffImportScreen> createState() => _StaffImportScreenState();
}

class _StaffImportScreenState extends State<StaffImportScreen> {
  final text = TextEditingController();
  List<ImportRow> rows = [];

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  void _parse() {
    final store = StoreScope.of(context);
    setState(() => rows = parseStaff(text.text, existing: store.employees, today: store.now, newId: store.newId));
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt', 'tsv']);
    if (files.isEmpty) return;
    final bytes = await files.single.readAsBytes();
    if (!mounted) return;
    text.text = utf8.decode(bytes, allowMalformed: true);
    _parse();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final good = rows.where((r) => r.ok).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Import pekerja')),
      body: PageList(children: [
        Section(
          title: 'Cara import',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('1. Dalam Excel atau Google Sheets, susun lajur dengan tajuk di baris pertama.'),
            const Text('2. Pilih semua sel (termasuk tajuk), salin, dan tampal di bawah. Atau simpan sebagai CSV dan pilih fail.'),
            const SizedBox(height: 8),
            Text('Tajuk yang dikenali: Nama (wajib), Jawatan, Jabatan, Tarikh mula, Gaji (wajib), No KP, Telefon, Emel, Bank, No akaun.',
                style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(const ClipboardData(text: '$importTemplate\n'));
                  messenger.showSnackBar(const SnackBar(content: Text('Tajuk templat disalin. Tampal dalam Excel.')));
                },
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Salin tajuk templat'),
              ),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Pilih fail CSV'),
              ),
            ]),
          ]),
        ),
        TextField(
          controller: text,
          minLines: 5,
          maxLines: 12,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          decoration: const InputDecoration(
            labelText: 'Tampal dari Excel di sini',
            hintText: 'Nama\tJawatan\tGaji\nAhmad Ali\tJurugambar\t2500',
            alignLabelWithHint: true,
          ),
          onChanged: (_) => _parse(),
        ),
        if (rows.isNotEmpty)
          Section(
            title: 'Semakan (${good.length} boleh diimport, ${rows.length - good.length} bermasalah)',
            child: Column(children: [
              for (final r in rows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(r.ok ? Icons.check_circle : Icons.error_outline,
                      color: statusColors(context, r.ok ? 'ok' : 'bad').fg),
                  title: Text(r.employee?.name ?? 'Baris ${r.line}'),
                  subtitle: Text(
                    r.ok
                        ? '${r.employee!.position.isEmpty ? '—' : r.employee!.position} · ${rm(r.employee!.salary)} · mula ${fmtDate(ymd(r.employee!.joinDate))} · cuti ${r.employee!.leaveAnnual} hari'
                        : 'Baris ${r.line}: ${r.problems.join('; ')}',
                    style: t.bodySmall?.copyWith(color: r.ok ? cs.onSurfaceVariant : statusColors(context, 'bad').fg),
                  ),
                ),
            ]),
          ),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: good.isEmpty
              ? null
              : () async {
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final n = await store.importEmployees([for (final r in good) r.employee!]);
                  nav.pop(n);
                  messenger.showSnackBar(SnackBar(content: Text('$n pekerja diimport. Mereka cipta PIN sendiri semasa log masuk pertama.')));
                },
          icon: const Icon(Icons.group_add_outlined),
          label: Text(good.isEmpty ? 'Tiada baris sah' : 'Import ${good.length} pekerja'),
        ),
        Text('Kelayakan cuti diisi ikut minimum Akta Kerja untuk tempoh khidmat setiap pekerja, dan boleh diubah selepas import.',
            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

/// First-time setup for a real company: details and hours, shop location,
/// public holidays, staff.
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});
  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  int step = 0;
  late final TextEditingController name;
  late TimeOfDay start, end;
  late Set<int> closed;
  final picked = <String>{};
  bool _ready = false;

  static const _days = ['Isn', 'Sel', 'Rab', 'Kha', 'Jum', 'Sab', 'Ahd'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final store = StoreScope.of(context);
    final s = store.settings;
    name = TextEditingController(text: s.name);
    TimeOfDay tod(String v) => TimeOfDay(hour: int.parse(v.substring(0, 2)), minute: int.parse(v.substring(3)));
    start = tod(s.startTime);
    end = tod(s.endTime);
    closed = {...s.weekendDays};
    for (final (d, _) in HrStore.fixedHolidays(store.now.year)) {
      if (!s.holidays.contains(d)) picked.add(d);
    }
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay v) => '${two(v.hour)}:${two(v.minute)}';

  Future<void> _saveCompany() async {
    final store = StoreScope.of(context);
    final s = store.settings
      ..name = name.text.trim().isEmpty ? store.settings.name : name.text.trim()
      ..startTime = _fmt(start)
      ..endTime = _fmt(end)
      ..weekendDays = (closed.toList()..sort());
    await store.updateSettings(s);
  }

  Future<void> _saveHolidays() async {
    final store = StoreScope.of(context);
    for (final (d, n) in HrStore.fixedHolidays(store.now.year)) {
      if (picked.contains(d)) await store.addHoliday(d, n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    Future<void> next() async {
      final nav = Navigator.of(context);
      if (step == 0) await _saveCompany();
      if (step == 2) await _saveHolidays();
      if (step == 3) {
        await store.finishSetup();
        nav.pop();
        return;
      }
      setState(() => step++);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tetapan permulaan')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Stepper(
            currentStep: step,
            onStepTapped: (i) => setState(() => step = i),
            onStepContinue: next,
            onStepCancel: step == 0 ? null : () => setState(() => step--),
            controlsBuilder: (context, d) => Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(children: [
                FilledButton(onPressed: d.onStepContinue, child: Text(step == 3 ? 'Selesai' : 'Seterusnya')),
                const SizedBox(width: 8),
                if (d.onStepCancel != null) TextButton(onPressed: d.onStepCancel, child: const Text('Kembali')),
              ]),
            ),
            steps: [
              Step(
                title: const Text('Syarikat & waktu kerja'),
                isActive: step >= 0,
                state: step > 0 ? StepState.complete : StepState.indexed,
                content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama syarikat')),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Mula'),
                        trailing: Text(_fmt(start), style: const TextStyle(fontWeight: FontWeight.w700)),
                        onTap: () async {
                          final v = await showTimePicker(context: context, initialTime: start);
                          if (v != null) setState(() => start = v);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Tamat'),
                        trailing: Text(_fmt(end), style: const TextStyle(fontWeight: FontWeight.w700)),
                        onTap: () async {
                          final v = await showTimePicker(context: context, initialTime: end);
                          if (v != null) setState(() => end = v);
                        },
                      ),
                    ),
                  ]),
                  Text('Hari kedai tutup', style: t.bodyMedium),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(_days[d - 1]),
                        selected: closed.contains(d),
                        onSelected: (v) => setState(() => v ? closed.add(d) : closed.remove(d)),
                      ),
                  ]),
                ]),
              ),
              Step(
                title: const Text('Lokasi kedai'),
                isActive: step >= 1,
                state: step > 1 ? StepState.complete : StepState.indexed,
                content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(s.hasOffice
                      ? 'Ditetapkan: ${s.officeLat!.toStringAsFixed(5)}, ${s.officeLng!.toStringAsFixed(5)} · radius ${s.radiusM.round()} m'
                      : 'Belum ditetapkan. Pekerja perlu punch dalam radius kedai.'),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PunchSettingsScreen())),
                    icon: const Icon(Icons.storefront_outlined, size: 18),
                    label: Text(s.hasOffice ? 'Ubah lokasi dan radius' : 'Tetapkan lokasi kedai'),
                  ),
                  const SizedBox(height: 6),
                  Text('Boleh dilangkau dan ditetapkan kemudian di dashboard.', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              Step(
                title: Text('Cuti umum ${store.now.year}'),
                isActive: step >= 2,
                state: step > 2 ? StepState.complete : StepState.indexed,
                content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final (d, n) in HrStore.fixedHolidays(store.now.year))
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: s.holidays.contains(d) || picked.contains(d),
                      onChanged: s.holidays.contains(d) ? null : (v) => setState(() => v! ? picked.add(d) : picked.remove(d)),
                      title: Text(n),
                      subtitle: Text(longDate(parseYmd(d))),
                    ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: statusColors(context, 'warn').bg, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      'Cuti yang tarikhnya berubah setiap tahun (Hari Raya, Awal Muharram, Maulidur Rasul, Tahun Baru Cina, '
                      'Deepavali, Hari Keputeraan Sultan Kelantan dan lain-lain) perlu ditambah sendiri di Tetapan syarikat > Cuti umum '
                      'mengikut senarai rasmi negeri Kelantan.',
                      style: t.bodySmall?.copyWith(color: statusColors(context, 'warn').fg),
                    ),
                  ),
                ]),
              ),
              Step(
                title: const Text('Pekerja'),
                isActive: step >= 3,
                content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('${store.activeEmployees.length} pekerja dalam sistem.'),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StaffImportScreen())),
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Import dari Excel / CSV'),
                  ),
                  const SizedBox(height: 6),
                  Text('Atau tambah satu per satu di tab Pekerja.', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
