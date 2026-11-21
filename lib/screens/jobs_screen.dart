import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../widgets/common.dart';

/// Studio jobs (weddings, events, studio sessions, album edits) with the
/// staff who worked on them. Commission is paid with that month's salary.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});
  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  late String month = ym(DateTime.now());
  String? staffFilter, typeFilter;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final list = store.jobsIn(month);
    final shown = list
        .where((j) => (staffFilter == null || j.staff.containsKey(staffFilter)) && (typeFilter == null || j.typeId == typeFilter))
        .toList();
    final total = list.fold(0.0, (s, j) => s + j.total);
    final finalised = store.payrun(month) != null;
    final perStaff = <String, double>{};
    for (final j in list) {
      j.staff.forEach((k, v) => perStaff[k] = (perStaff[k] ?? 0) + v);
    }
    final ranking = perStaff.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      appBar: AppBar(title: const Text('Job & komisen'), actions: [
        IconButton(
          tooltip: 'Jenis job & kadar',
          icon: const Icon(Icons.tune),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JobTypesScreen())),
        ),
      ]),
      floatingActionButton: finalised
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobForm(month: month))),
              icon: const Icon(Icons.add),
              label: const Text('Rekod job'),
            ),
      body: PageList(children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => month = addMonths(month, -1)), icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Column(children: [
              Text(monthLabel(month), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (finalised) const Padding(padding: EdgeInsets.only(top: 4), child: Tag('Gaji dimuktamadkan', tone: 'ok')),
            ]),
          ),
          IconButton(onPressed: () => setState(() => month = addMonths(month, 1)), icon: const Icon(Icons.chevron_right)),
        ]),
        FigureStrip(items: [
          Figure(label: 'Job', value: '${list.length}'),
          Figure(label: 'Jumlah komisen', value: rm(total), note: 'dibayar bersama gaji'),
        ]),
        if (ranking.isNotEmpty)
          Section(
            title: 'Komisen ikut staf',
            child: Column(children: [
              for (final r in ranking)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Avatar(store.employeeById(r.key), radius: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(store.nameOf(r.key)),
                        Text('${list.where((j) => j.staff.containsKey(r.key)).length} job',
                            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(rm(r.value), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ),
        if (list.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _filter<String>(
                context,
                icon: Icons.person_outline,
                label: staffFilter == null ? 'Semua staf' : store.nameOf(staffFilter!),
                value: staffFilter,
                options: {for (final r in ranking) r.key: store.nameOf(r.key)},
                onChanged: (v) => setState(() => staffFilter = v),
              ),
              const SizedBox(width: 8),
              _filter<String>(
                context,
                icon: Icons.category_outlined,
                label: typeFilter == null ? 'Semua jenis' : store.jobType(typeFilter!)?.name ?? 'Job',
                value: typeFilter,
                options: {for (final ty in store.settings.jobTypes) ty.id: ty.name},
                onChanged: (v) => setState(() => typeFilter = v),
              ),
            ]),
          ),
        if (list.isEmpty)
          Card(
            child: EmptyState(
              icon: Icons.photo_camera_outlined,
              title: 'Belum ada job ${monthLabel(month)}',
              message: 'Rekod setiap kahwin, event atau sesi studio supaya komisen masuk gaji.',
              action: finalised
                  ? null
                  : FilledButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobForm(month: month))),
                      icon: const Icon(Icons.add),
                      label: const Text('Rekod job pertama'),
                    ),
            ),
          )
        else if (shown.isEmpty)
          const Card(child: EmptyState(icon: Icons.filter_alt_off_outlined, title: 'Tiada job ikut penapis ini'))
        else
          for (final j in shown) JobCard(job: j, editable: !finalised),
      ]),
    );
  }
}

Widget _filter<T>(BuildContext context,
    {required IconData icon,
    required String label,
    required T? value,
    required Map<T, String> options,
    required ValueChanged<T?> onChanged}) {
  return InputChip(
    avatar: Icon(icon, size: 18),
    label: Text(label),
    selected: value != null,
    showCheckmark: false,
    onDeleted: value == null ? null : () => onChanged(null),
    onPressed: () async {
      final v = await showModalBottomSheet<T>(
        context: context,
        builder: (c) => SafeArea(
          child: ListView(shrinkWrap: true, children: [
            for (final o in options.entries)
              ListTile(
                title: Text(o.value),
                trailing: o.key == value ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(c, o.key),
              ),
          ]),
        ),
      );
      if (v != null) onChanged(v);
    },
  );
}

class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, this.editable = false, this.onlyEmpId});
  final Job job;
  final bool editable;
  final String? onlyEmpId; // employee view: show only their own amount

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final type = store.jobType(job.typeId);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: editable
            ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobForm(existing: job)))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(job.title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text('${fmtDate(job.date)} · ${type?.name ?? 'Job'}',
                      style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ]),
              ),
              Text(rm(onlyEmpId == null ? job.total : job.staff[onlyEmpId] ?? 0),
                  style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            ]),
            if (onlyEmpId == null) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final e in job.staff.entries)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Avatar(store.employeeById(e.key), radius: 10),
                    label: Text('${store.employeeById(e.key)?.firstName ?? '?'} ${rm(e.value)}'),
                  ),
              ]),
            ],
            if (job.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(job.note, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
          ]),
        ),
      ),
    );
  }
}

class JobForm extends StatefulWidget {
  const JobForm({super.key, this.existing, this.month});
  final Job? existing;
  final String? month;
  @override
  State<JobForm> createState() => _JobFormState();
}

class _JobFormState extends State<JobForm> {
  final title = TextEditingController();
  final note = TextEditingController();
  late DateTime date;
  String? typeId;
  final amounts = <String, TextEditingController>{};
  String? error;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final store = StoreScope.of(context);
    final j = widget.existing;
    title.text = j?.title ?? '';
    note.text = j?.note ?? '';
    final now = store.now;
    date = j != null
        ? parseYmd(j.date)
        : (widget.month == null || widget.month == ym(now))
            ? DateTime(now.year, now.month, now.day)
            : parseYmd('${widget.month}-01');
    typeId = j?.typeId ?? store.settings.jobTypes.firstOrNull?.id;
    j?.staff.forEach((k, v) => amounts[k] = TextEditingController(text: v.toStringAsFixed(2)));
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    for (final c in amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get rate => StoreScope.of(context).jobType(typeId ?? '')?.rate ?? 0;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final editing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Ubah job' : 'Rekod job'), actions: [
        if (editing)
          IconButton(
            tooltip: 'Padam job',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final old = widget.existing!;
              final err = await store.deleteJob(old.id);
              if (err == null) {
                nav.pop();
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(SnackBar(
                  content: Text('"${old.title}" dipadam'),
                  action: SnackBarAction(label: 'Batal', onPressed: () => store.saveJob(old)),
                ));
              } else {
                setState(() => error = err);
              }
            },
          ),
      ]),
      body: PageList(children: [
        DropdownButtonFormField<String>(
          initialValue: typeId,
          decoration: const InputDecoration(labelText: 'Jenis job'),
          items: [
            for (final ty in store.settings.jobTypes)
              DropdownMenuItem(value: ty.id, child: Text('${ty.name} · ${rm(ty.rate)} seorang')),
          ],
          onChanged: (v) => setState(() {
            typeId = v;
            for (final c in amounts.values) {
              c.text = rate.toStringAsFixed(2);
            }
          }),
        ),
        TextField(
          controller: title,
          decoration: const InputDecoration(labelText: 'Nama job', hintText: 'Contoh: Kahwin Nadia & Irfan (Kota Bharu)'),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final d = await showDatePicker(
                context: context, initialDate: date, firstDate: DateTime(store.now.year - 1), lastDate: DateTime(store.now.year + 1, 12, 31));
            if (d != null) setState(() => date = d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Tarikh', suffixIcon: Icon(Icons.calendar_today_outlined, size: 20)),
            child: Text(longDate(date)),
          ),
        ),
        Section(
          title: 'Staf & komisen',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in store.staff)
                FilterChip(
                  avatar: Avatar(e, radius: 10),
                  label: Text(e.firstName),
                  selected: amounts.containsKey(e.id),
                  onSelected: (on) => setState(() {
                    if (on) {
                      amounts[e.id] = TextEditingController(text: rate.toStringAsFixed(2));
                    } else {
                      amounts.remove(e.id)?.dispose();
                    }
                  }),
                ),
            ]),
            const SizedBox(height: 10),
            for (final e in amounts.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(child: Text(store.nameOf(e.key))),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: e.value,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(prefixText: 'RM ', isDense: true),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        TextField(controller: note, decoration: const InputDecoration(labelText: 'Catatan (pilihan)')),
        if (error != null) Text(error!, style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: () async {
            final nav = Navigator.of(context);
            final err = await store.saveJob(Job(
              id: widget.existing?.id ?? 'j${store.newId()}',
              date: ymd(date),
              title: title.text.trim(),
              typeId: typeId ?? '',
              staff: {for (final e in amounts.entries) e.key: double.tryParse(e.value.text.replaceAll(',', '')) ?? 0},
              note: note.text.trim(),
              createdAt: widget.existing?.createdAt ?? store.now,
            ));
            if (err != null) {
              setState(() => error = err);
              return;
            }
            nav.pop();
          },
          child: const Text('Simpan job'),
        ),
      ]),
    );
  }
}

/// Edit the job types and their usual commission per person.
class JobTypesScreen extends StatelessWidget {
  const JobTypesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Jenis job & kadar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Jenis baharu'),
      ),
      body: PageList(children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < store.settings.jobTypes.length; i++) ...[
              if (i > 0) const Divider(indent: 16),
              ListTile(
                title: Text(store.settings.jobTypes[i].name),
                subtitle: Text('${rm(store.settings.jobTypes[i].rate)} seorang'),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(context, store.settings.jobTypes[i]),
              ),
            ],
          ]),
        ),
        const Text('Kadar ini diisi secara automatik semasa merekod job, dan boleh diubah untuk setiap staf.'),
      ]),
    );
  }

  Future<void> _edit(BuildContext context, JobType? ty) async {
    final store = StoreScope.of(context);
    final name = TextEditingController(text: ty?.name ?? '');
    final rate = TextEditingController(text: ty == null ? '' : ty.rate.toStringAsFixed(2));
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(ty == null ? 'Jenis job baharu' : 'Ubah jenis job'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nama')),
          const SizedBox(height: 10),
          TextField(
            controller: rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Komisen seorang', prefixText: 'RM '),
          ),
        ]),
        actions: [
          if (ty != null)
            TextButton(
              onPressed: () async {
                await store.saveJobTypes([...store.settings.jobTypes]..removeWhere((x) => x.id == ty.id));
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Padam'),
            ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              final r = double.tryParse(rate.text.replaceAll(',', ''));
              if (name.text.trim().isEmpty || r == null || r < 0) return;
              final list = [...store.settings.jobTypes];
              final updated = JobType(id: ty?.id ?? 't${store.newId()}', name: name.text.trim(), rate: r);
              final i = list.indexWhere((x) => x.id == updated.id);
              if (i >= 0) {
                list[i] = updated;
              } else {
                list.add(updated);
              }
              await store.saveJobTypes(list);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    name.dispose();
    rate.dispose();
  }
}
