import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});
  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ql = q.toLowerCase();
    final list = store.employees
        .where((e) => ql.isEmpty || '${e.name} ${e.dept} ${e.position}'.toLowerCase().contains(ql))
        .toList()
      ..sort((a, b) => a.active == b.active ? a.name.compareTo(b.name) : (a.active ? -1 : 1));
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Pekerja (${store.activeEmployees.length})')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmployeeForm())),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Tambah'),
      ),
      body: PageList(children: [
        SearchBar(
          hintText: 'Cari nama, jabatan atau jawatan',
          leading: const Icon(Icons.search),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(cs.surface),
          side: WidgetStatePropertyAll(BorderSide(color: cs.outlineVariant)),
          onChanged: (v) => setState(() => q = v),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: list.isEmpty
              ? Padding(padding: const EdgeInsets.all(24), child: Text('Tiada pekerja sepadan dengan “$q”.'))
              : Column(children: [
                  for (var i = 0; i < list.length; i++) ...[
                    if (i > 0) const Divider(indent: 68),
                    ListTile(
                      leading: Avatar(list[i]),
                      title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${list[i].position} · ${list[i].dept}', style: t.bodySmall),
                      trailing: list[i].active
                          ? (list[i].isAdmin ? const Tag('Admin', tone: 'mute') : const Icon(Icons.chevron_right))
                          : const Tag('Berhenti', tone: 'bad'),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => EmployeeDetail(empId: list[i].id))),
                    ),
                  ],
                ]),
        ),
      ]),
    );
  }
}

class EmployeeDetail extends StatelessWidget {
  const EmployeeDetail({super.key, required this.empId});
  final String empId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final e = store.employeeById(empId);
    if (e == null) return const Scaffold(body: Center(child: Text('Pekerja tidak dijumpai')));
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final month = ym(store.now);
    final att = store.attendanceOf(empId, month);
    final reqs = store.requestsOf(empId).take(5).toList();

    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(k, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
            Expanded(child: Text(v.isEmpty ? '—' : v, style: t.bodyMedium)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(actions: [
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EmployeeForm(existing: e))),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Ubah'),
        ),
        const SizedBox(width: 8),
      ]),
      body: PageList(children: [
        Row(children: [
          Avatar(e, radius: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.name, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text('${e.position} · ${e.dept}', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
        ]),
        FigureStrip(items: [
          Figure(label: 'Cuti tahunan', value: daysLabel(store.leaveBalance(empId, 'Cuti Tahunan') ?? 0), note: 'daripada ${e.leaveAnnual}'),
          Figure(label: 'Cuti sakit', value: daysLabel(store.leaveBalance(empId, 'Cuti Sakit') ?? 0), note: 'daripada ${e.leaveMedical}'),
          Figure(label: 'Hadir ${monthsMs[store.now.month - 1].substring(0, 3)}', value: '${att.length} hari'),
          Figure(label: 'Lewat', value: '${att.where(store.isLate).length}', note: 'bulan ini'),
        ]),
        Section(
          title: 'Maklumat',
          child: Column(children: [
            kv('Mula kerja', '${fmtDate(ymd(e.joinDate))} (${tenure(e.joinDate)})'),
            kv('Emel', e.email),
            kv('Telefon', e.phone),
          ]),
        ),
        _SalarySection(e: e),
        Section(
          title: 'Kontrak',
          child: Column(children: [
            kv('Tamat percubaan', e.probationEnd == null ? '—' : fmtDate(e.probationEnd)),
            kv('Tamat kontrak', e.contractEnd == null ? 'Tetap' : fmtDate(e.contractEnd)),
            kv('Hari jadi', e.birthDate == null ? '—' : '${e.birthDate!.day} ${monthsMs[e.birthDate!.month - 1]}'),
          ]),
        ),
        Section(
          title: 'Akses',
          child: Row(children: [
            Expanded(
              child: Text(
                store.lockMinutesLeft(e.id) > 0
                    ? 'Dikunci ${store.lockMinutesLeft(e.id)} minit kerana PIN salah'
                    : store.needsPin(e.id)
                        ? 'Belum cipta PIN'
                        : 'PIN ditetapkan',
                style: t.bodyMedium,
              ),
            ),
            if (!store.needsPin(e.id) && e.id != store.me!.id)
              OutlinedButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text('Set semula PIN ${e.firstName}?'),
                      content: const Text('Pekerja akan cipta PIN baharu semasa log masuk seterusnya.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Set semula')),
                      ],
                    ),
                  );
                  if (ok == true) await store.resetPin(e.id);
                },
                child: const Text('Set semula PIN'),
              ),
          ]),
        ),
        Section(
          title: 'Permohonan terkini',
          child: reqs.isEmpty
              ? const QuietText('Tiada permohonan.')
              : Column(children: [
                  for (final r in reqs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(requestTitle(r), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text(requestDetail(r), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                          ]),
                        ),
                        StatusChip(r.status),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}

class EmployeeForm extends StatefulWidget {
  const EmployeeForm({super.key, this.existing});
  final Employee? existing;
  @override
  State<EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<EmployeeForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> c;
  late DateTime join;
  late bool active;
  String? probation, contract;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    c = {
      'name': TextEditingController(text: e?.name ?? ''),
      'position': TextEditingController(text: e?.position ?? ''),
      'dept': TextEditingController(text: e?.dept ?? ''),
      'email': TextEditingController(text: e?.email ?? ''),
      'phone': TextEditingController(text: e?.phone ?? ''),
      'ic': TextEditingController(text: e?.ic ?? ''),
      'salary': TextEditingController(text: e == null ? '' : e.salary.toStringAsFixed(2)),
      'allowance': TextEditingController(text: e == null ? '0' : e.allowance.toStringAsFixed(2)),
      'bank': TextEditingController(text: e?.bank ?? ''),
      'bankAcc': TextEditingController(text: e?.bankAcc ?? ''),
      'leaveAnnual': TextEditingController(text: '${e?.leaveAnnual ?? 8}'),
      'leaveMedical': TextEditingController(text: '${e?.leaveMedical ?? 14}'),
    };
    join = e?.joinDate ?? DateTime.now();
    active = e?.active ?? true;
    probation = e?.probationEnd ??
        (e == null ? ymd(DateTime(join.year, join.month + 3, join.day)) : null); // 3-month default
    contract = e?.contractEnd;
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Widget field(String k, String label, {TextInputType? type, bool required = false, String? prefix}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: c[k],
          keyboardType: type,
          decoration: InputDecoration(labelText: label, prefixText: prefix),
          validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final editing = widget.existing != null;
    const money = TextInputType.numberWithOptions(decimal: true);

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Ubah pekerja' : 'Tambah pekerja')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          Text('Pekerjaan', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          field('name', 'Nama penuh', required: true),
          field('position', 'Jawatan'),
          field('dept', 'Jabatan'),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: join, firstDate: DateTime(1990), lastDate: DateTime(2100));
                if (d != null) setState(() => join = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Tarikh mula', suffixIcon: Icon(Icons.calendar_today_outlined, size: 20)),
                child: Text(fmtDate(ymd(join))),
              ),
            ),
          ),
          _OptionalDate(
            label: 'Tamat percubaan',
            value: probation,
            onChanged: (v) => setState(() => probation = v),
          ),
          _OptionalDate(
            label: 'Tamat kontrak (kosong = tetap)',
            value: contract,
            onChanged: (v) => setState(() => contract = v),
          ),
          Row(children: [
            Expanded(child: field('leaveAnnual', 'Cuti tahunan', type: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: field('leaveMedical', 'Cuti sakit', type: TextInputType.number)),
          ]),
          Text('Akta Kerja 1955: minimum 8/12/16 hari cuti tahunan dan 14/18/22 hari cuti sakit ikut tempoh khidmat.',
              style: t.bodySmall),
          const SizedBox(height: 20),
          Text('Gaji & peribadi (sulit)', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: c['salary'],
              keyboardType: money,
              decoration: const InputDecoration(labelText: 'Gaji pokok', prefixText: 'RM ',
                  helperText: 'Gaji minimum RM1,700 sebulan (Perintah Gaji Minimum 2024)'),
              validator: (v) {
                final x = double.tryParse((v ?? '').replaceAll(',', ''));
                if (x == null || x <= 0) return 'Masukkan gaji yang sah';
                if (x > 1000000) return 'Nilai terlalu besar';
                return null;
              },
            ),
          ),
          field('allowance', 'Elaun tetap', type: money, prefix: 'RM '),
          field('ic', 'No. KP'),
          field('email', 'Emel', type: TextInputType.emailAddress),
          field('phone', 'Telefon', type: TextInputType.phone),
          field('bank', 'Bank'),
          field('bankAcc', 'No. akaun bank'),
          if (editing)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: active,
              onChanged: (v) => setState(() => active = v),
              title: const Text('Masih bekerja'),
              subtitle: const Text('Matikan untuk pekerja yang sudah berhenti'),
            ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: () async {
              if (!_form.currentState!.validate()) return;
              final old = widget.existing;
              final e = Employee(
                id: old?.id ?? store.newEmployeeId(),
                name: c['name']!.text.trim(),
                position: c['position']!.text.trim(),
                dept: c['dept']!.text.trim(),
                email: c['email']!.text.trim(),
                phone: c['phone']!.text.trim(),
                ic: c['ic']!.text.trim(),
                bank: c['bank']!.text.trim(),
                bankAcc: c['bankAcc']!.text.trim(),
                joinDate: join,
                salary: double.tryParse(c['salary']!.text) ?? 0,
                allowance: double.tryParse(c['allowance']!.text) ?? 0,
                leaveAnnual: int.tryParse(c['leaveAnnual']!.text) ?? 8,
                leaveMedical: int.tryParse(c['leaveMedical']!.text) ?? 14,
                isAdmin: old?.isAdmin ?? false,
                active: active,
                probationEnd: probation,
                contractEnd: contract,
              );
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              await store.saveEmployee(e);
              nav.pop();
              messenger.showSnackBar(SnackBar(content: Text(editing ? 'Maklumat ${e.name} disimpan' : '${e.name} ditambah')));
            },
            child: Text(editing ? 'Simpan' : 'Tambah pekerja'),
          ),
        ]),
      ),
    );
  }
}

class _SalarySection extends StatefulWidget {
  const _SalarySection({required this.e});
  final Employee e;
  @override
  State<_SalarySection> createState() => _SalarySectionState();
}

class _SalarySectionState extends State<_SalarySection> {
  bool shown = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    String mask(String v) => shown ? v : '••••••';
    Widget kv(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(width: 120, child: Text(k, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
            Expanded(child: Text(v, style: t.bodyMedium)),
          ]),
        );
    return Section(
      title: 'Gaji (sulit)',
      action: TextButton.icon(
        onPressed: () => setState(() => shown = !shown),
        icon: Icon(shown ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
        label: Text(shown ? 'Sembunyi' : 'Tunjuk'),
      ),
      child: Column(children: [
        kv('Gaji pokok', mask(rm(e.salary))),
        kv('Elaun tetap', mask(rm(e.allowance))),
        kv('No. KP', mask(e.ic)),
        kv('Bank', mask('${e.bank} ${e.bankAcc}'.trim())),
      ]),
    );
  }
}

class _OptionalDate extends StatelessWidget {
  const _OptionalDate({required this.label, required this.value, required this.onChanged});
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: value == null ? DateTime.now() : parseYmd(value!),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (d != null) onChanged(ymd(d));
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: value == null
                  ? const Icon(Icons.calendar_today_outlined, size: 20)
                  : IconButton(icon: const Icon(Icons.clear), onPressed: () => onChanged(null)),
            ),
            child: Text(value == null ? 'Tiada' : fmtDate(value)),
          ),
        ),
      );
}
