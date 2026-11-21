import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../services/punch_devices.dart';
import '../store.dart';
import '../theme.dart';

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: child,
      ),
    );

Future<void> showLeaveForm(BuildContext context) => _sheet(context, const _LeaveForm());
Future<void> showClaimForm(BuildContext context) => _sheet(context, const _ClaimForm());
Future<void> showOvertimeForm(BuildContext context) => _sheet(context, const _OvertimeForm());

class _FormFrame extends StatelessWidget {
  const _FormFrame({required this.title, required this.subtitle, required this.children, required this.submit});
  final String title, subtitle;
  final List<Widget> children;
  final Widget submit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitle, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        for (final c in children) ...[c, const SizedBox(height: 14)],
        const SizedBox(height: 4),
        submit,
      ]),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onPick});
  final String label;
  final DateTime value;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20)),
          child: Text(longDate(value)),
        ),
      );
}

Future<DateTime?> _pickDate(BuildContext context, DateTime initial, {DateTime? first, DateTime? last}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(now.year - 1),
    lastDate: last ?? DateTime(now.year + 1, 12, 31),
  );
}

// ------------------------------------------------------------------ leave
class _LeaveForm extends StatefulWidget {
  const _LeaveForm();
  @override
  State<_LeaveForm> createState() => _LeaveFormState();
}

class _LeaveFormState extends State<_LeaveForm> {
  String type = leaveTypes.first;
  late DateTime from, to;
  String? half;
  final note = TextEditingController();
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    from = to = DateTime(n.year, n.month, n.day + 1);
  }

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final me = store.me!;
    final sameDay = ymd(from) == ymd(to);
    final days = store.leaveDays(ymd(from), ymd(to), sameDay ? half : null);
    final bal = store.leaveBalance(me.id, type);
    final after = bal == null ? null : bal - days;
    final overlap = store.requestsOf(me.id, ReqKind.leave).any((r) =>
        r.status != ReqStatus.rejected && r.from!.compareTo(ymd(to)) <= 0 && r.to!.compareTo(ymd(from)) >= 0);
    final blocked = days == 0 || (type == 'Cuti Tahunan' && after != null && after < 0);
    final t = Theme.of(context).textTheme;

    return _FormFrame(
      title: 'Mohon cuti',
      subtitle: 'Hari cuti dikira tanpa hujung minggu dan cuti umum.',
      children: [
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Jenis cuti'),
          items: [for (final l in leaveTypes) DropdownMenuItem(value: l, child: Text(l))],
          onChanged: (v) => setState(() => type = v!),
        ),
        Row(children: [
          Expanded(
            child: _DateField(
              label: 'Dari',
              value: from,
              onPick: () async {
                final d = await _pickDate(context, from);
                if (d != null) {
                  setState(() {
                    from = d;
                    if (to.isBefore(d)) to = d;
                  });
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _DateField(
              label: 'Hingga',
              value: to,
              onPick: () async {
                final d = await _pickDate(context, to.isBefore(from) ? from : to, first: from);
                if (d != null) setState(() => to = d);
              },
            ),
          ),
        ]),
        if (sameDay)
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'full', label: Text('Sehari')),
              ButtonSegment(value: 'am', label: Text('Pagi')),
              ButtonSegment(value: 'pm', label: Text('Petang')),
            ],
            selected: {half ?? 'full'},
            onSelectionChanged: (s) => setState(() => half = s.first == 'full' ? null : s.first),
          ),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Sebab (pilihan)')),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(days == 0 ? 'Tiada hari bekerja dalam tarikh ini' : '${daysLabel(days)} bekerja',
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            if (after != null)
              Text('Baki $type selepas ini: ${daysLabel(after)}',
                  style: t.bodySmall?.copyWith(color: after < 0 ? statusColors(context, 'bad').fg : null)),
            if (overlap)
              Text('Anda sudah ada cuti yang bertindih dengan tarikh ini.',
                  style: t.bodySmall?.copyWith(color: statusColors(context, 'warn').fg)),
          ]),
        ),
      ],
      submit: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: blocked || saving
            ? null
            : () async {
                setState(() => saving = true);
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await store.submitLeave(
                    type: type, from: ymd(from), to: ymd(to), half: sameDay ? half : null, note: note.text.trim());
                nav.pop();
                messenger.showSnackBar(const SnackBar(content: Text('Permohonan cuti dihantar')));
              },
        child: const Text('Hantar permohonan'),
      ),
    );
  }
}

// ------------------------------------------------------------------ claim
class _ClaimForm extends StatefulWidget {
  const _ClaimForm();
  @override
  State<_ClaimForm> createState() => _ClaimFormState();
}

class _ClaimFormState extends State<_ClaimForm> {
  String category = claimCategories.first;
  DateTime date = DateTime.now();
  final amount = TextEditingController();
  final note = TextEditingController();
  String? receipt;

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final value = double.tryParse(amount.text.replaceAll(',', '')) ?? 0;
    return _FormFrame(
      title: 'Tuntutan',
      subtitle: 'Tuntutan yang diluluskan dibayar bersama gaji bulan resit.',
      children: [
        DropdownButtonFormField<String>(
          initialValue: category,
          decoration: const InputDecoration(labelText: 'Kategori'),
          items: [for (final c in claimCategories) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => category = v!),
        ),
        _DateField(
          label: 'Tarikh resit',
          value: date,
          onPick: () async {
            final d = await _pickDate(context, date, last: DateTime.now());
            if (d != null) setState(() => date = d);
          },
        ),
        TextField(
          controller: amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Jumlah', prefixText: 'RM '),
          onChanged: (_) => setState(() {}),
        ),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Keterangan')),
        Row(children: [
          if (receipt != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(base64Decode(receipt!), width: 56, height: 56, fit: BoxFit.cover),
              ),
            ),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final r = await punchDevices.receipt();
                if (r != null && mounted) setState(() => receipt = r);
              },
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text(receipt == null ? 'Ambil gambar resit' : 'Ambil semula'),
            ),
          ),
        ]),
      ],
      submit: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: value <= 0 || value > 50000
            ? null
            : () async {
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await store.submitClaim(
                    category: category, date: ymd(date), amount: value, note: note.text.trim(), receipt: receipt);
                nav.pop();
                messenger.showSnackBar(SnackBar(content: Text('Tuntutan ${rm(value)} dihantar')));
              },
        child: const Text('Hantar tuntutan'),
      ),
    );
  }
}

// ------------------------------------------------------------------ overtime
class _OvertimeForm extends StatefulWidget {
  const _OvertimeForm();
  @override
  State<_OvertimeForm> createState() => _OvertimeFormState();
}

class _OvertimeFormState extends State<_OvertimeForm> {
  DateTime date = DateTime.now();
  double hours = 2;
  double rate = 1.5;
  final note = TextEditingController();

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    return _FormFrame(
      title: 'Lebih masa',
      subtitle: 'Kadar Akta Kerja: 1.5× hari biasa, 2× hari rehat, 3× cuti umum.',
      children: [
        _DateField(
          label: 'Tarikh',
          value: date,
          onPick: () async {
            final d = await _pickDate(context, date, last: DateTime.now());
            if (d != null) setState(() => date = d);
          },
        ),
        Row(children: [
          Text('Jam', style: t.bodyLarge),
          const Spacer(),
          IconButton.outlined(
            onPressed: hours > .5 ? () => setState(() => hours -= .5) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 64,
            child: Text(hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1),
                textAlign: TextAlign.center, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          ),
          IconButton.outlined(
            onPressed: hours < 12 ? () => setState(() => hours += .5) : null,
            icon: const Icon(Icons.add),
          ),
        ]),
        SegmentedButton<double>(
          segments: const [
            ButtonSegment(value: 1.5, label: Text('Biasa 1.5×')),
            ButtonSegment(value: 2, label: Text('Rehat 2×')),
            ButtonSegment(value: 3, label: Text('Umum 3×')),
          ],
          selected: {rate},
          onSelectionChanged: (s) => setState(() => rate = s.first),
        ),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Tugasan')),
        Builder(builder: (context) {
          final used = store.overtimeHours(store.me!.id, ymd(date).substring(0, 7));
          final after = used + hours;
          final over = after > HrStore.overtimeCapHours;
          return Text(
            'OT bulan ini: ${after.toStringAsFixed(1)} / ${HrStore.overtimeCapHours.toInt()} jam'
            '${over ? '. Melebihi had Akta Kerja 1955.' : ''}',
            style: t.bodySmall?.copyWith(
                color: over ? statusColors(context, 'bad').fg : null, fontWeight: over ? FontWeight.w700 : null),
          );
        }),
      ],
      submit: FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        onPressed: () async {
          final nav = Navigator.of(context);
          final messenger = ScaffoldMessenger.of(context);
          await store.submitOvertime(date: ymd(date), hours: hours, rate: rate, note: note.text.trim());
          nav.pop();
          messenger.showSnackBar(const SnackBar(content: Text('Permohonan lebih masa dihantar')));
        },
        child: const Text('Hantar permohonan'),
      ),
    );
  }
}
