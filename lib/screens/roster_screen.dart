import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

const _dayShort = ['Isn', 'Sel', 'Rab', 'Kha', 'Jum', 'Sab', 'Ahd'];

/// Colour per shift so the week reads at a glance; the normal day stays plain.
Color shiftColor(BuildContext context, String id) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  const palette = [Color(0xFFFFCE00), Color(0xFF7FB2FF), Color(0xFFFF9E80), Color(0xFF9CE3B4), Color(0xFFD7A6FF)];
  final i = id.hashCode.abs() % palette.length;
  return palette[i].withValues(alpha: dark ? .35 : .55);
}

/// Manager's weekly roster: one row per person, one column per day.
class RosterScreen extends StatefulWidget {
  const RosterScreen({super.key});
  @override
  State<RosterScreen> createState() => _RosterScreenState();
}

class _RosterScreenState extends State<RosterScreen> {
  late DateTime monday = mondayOf(DateTime.now());
  late int dayIndex = DateTime.now().weekday - 1; // phone view: one day at a time

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final days = [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
    final today = ymd(store.now);

    return Scaffold(
      appBar: AppBar(title: const Text('Roster syif'), actions: [
        IconButton(
          tooltip: 'Urus syif',
          icon: const Icon(Icons.schedule_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShiftsScreen())),
        ),
      ]),
      body: PageList(maxWidth: 1000, children: [
        Row(children: [
          IconButton(
              onPressed: () => setState(() => monday = monday.subtract(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Column(children: [
              Text('${fmtShort(ymd(days.first))} – ${fmtDate(ymd(days.last))}',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              if (mondayOf(store.now) == monday) Text('Minggu ini', style: t.bodySmall),
            ]),
          ),
          IconButton(
              onPressed: () => setState(() => monday = monday.add(const Duration(days: 7))),
              icon: const Icon(Icons.chevron_right)),
        ]),
        LayoutBuilder(builder: (context, box) {
          if (box.maxWidth >= 640) return _table(context, days, today);
          final d = days[dayIndex];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < 7; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      showCheckmark: false,
                      selected: i == dayIndex,
                      onSelected: (_) => setState(() => dayIndex = i),
                      label: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_dayShort[i], style: t.labelSmall),
                        Text('${days[i].day}',
                            style: t.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                decoration: ymd(days[i]) == today ? TextDecoration.underline : null)),
                      ]),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 10),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                ListTile(
                  title: Text(longDate(d), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: store.settings.holidayNames[ymd(d)] != null
                      ? Text(store.settings.holidayNames[ymd(d)]!)
                      : !store.isWorkday(d)
                          ? const Text('Kedai tutup')
                          : null,
                ),
                for (final e in store.staff) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
                    child: Row(children: [
                      Avatar(e, radius: 16),
                      const SizedBox(width: 12),
                      Expanded(child: Text(e.name, overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 120, child: _Cell(emp: e, date: ymd(d), wide: true)),
                    ]),
                  ),
                ],
              ]),
            ),
          ]);
        }),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final sh in store.settings.allShifts)
            Chip(
              avatar: CircleAvatar(backgroundColor: sh.id == 'biasa' ? cs.surfaceContainerHighest : shiftColor(context, sh.id)),
              label: Text(sh.label),
            ),
          const Chip(label: Text('Off = hari rehat')),
        ]),
        OutlinedButton.icon(
          onPressed: () async {
            final store = StoreScope.of(context);
            final messenger = ScaffoldMessenger.of(context);
            final n = await store.copyRosterWeek(monday.subtract(const Duration(days: 7)), monday);
            messenger.showSnackBar(SnackBar(content: Text('$n entri disalin dari minggu lepas')));
          },
          icon: const Icon(Icons.copy_all_outlined, size: 18),
          label: const Text('Salin roster minggu lepas ke minggu ini'),
        ),
        Text('Tekan petak untuk tukar syif. Lewat dan balik awal dikira ikut syif setiap pekerja. '
            'Hari tanpa tetapan ikut waktu biasa dan hari tutup kedai.',
            style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
      ]),
    );
  }

  Widget _table(BuildContext context, List<DateTime> days, String today) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Card(
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(76),
              columnWidths: const {0: FixedColumnWidth(120)},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: cs.surfaceContainer),
                  children: [
                    const Padding(padding: EdgeInsets.all(10), child: Text('Pekerja', style: TextStyle(fontWeight: FontWeight.w700))),
                    for (final d in days)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(children: [
                          Text(_dayShort[d.weekday - 1],
                              style: t.labelSmall?.copyWith(
                                  color: store.settings.holidays.contains(ymd(d))
                                      ? statusColors(context, 'bad').fg
                                      : cs.onSurfaceVariant)),
                          Text('${d.day}',
                              style: t.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  decoration: ymd(d) == today ? TextDecoration.underline : null)),
                        ]),
                      ),
                  ],
                ),
                for (final e in store.staff)
                  TableRow(
                    decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                        child: Row(children: [
                          Avatar(e, radius: 13),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.firstName, overflow: TextOverflow.ellipsis, style: t.bodyMedium)),
                        ]),
                      ),
                      for (final d in days) _Cell(emp: e, date: ymd(d)),
                    ],
                  ),
              ],
            ),
          ),
        );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.emp, required this.date, this.wide = false});
  final Employee emp;
  final String date;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final explicit = store.roster['${emp.id}_$date'];
    final onLeave = store.onLeave(date).any((r) => r.empId == emp.id);
    final sh = store.shiftFor(emp.id, date);

    final String label;
    final Color? bg;
    if (onLeave) {
      label = 'Cuti';
      bg = statusColors(context, 'warn').bg;
    } else if (sh == null) {
      label = 'Off';
      bg = null;
    } else {
      // The normal day stays quiet so changes stand out.
      label = sh.id == 'biasa' ? (wide ? sh.label : '·') : (wide ? sh.label : sh.name);
      bg = sh.id == 'biasa' ? null : shiftColor(context, sh.id);
    }

    return InkWell(
      onTap: () => _pick(context),
      child: Container(
        height: 44,
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: explicit != null ? Border.all(color: cs.outline, width: 1) : null,
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: t.labelMedium?.copyWith(
                color: (sh == null || sh.id == 'biasa') && !onLeave ? cs.onSurfaceVariant : null,
                fontWeight: explicit != null ? FontWeight.w700 : null)),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final store = StoreScope.of(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text('${emp.name} · ${longDate(parseYmd(date))}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          for (final sh in store.settings.allShifts)
            ListTile(leading: const Icon(Icons.schedule), title: Text(sh.label), onTap: () => Navigator.pop(c, sh.id)),
          ListTile(leading: const Icon(Icons.weekend_outlined), title: const Text('Off (hari rehat)'), onTap: () => Navigator.pop(c, 'off')),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: const Text('Ikut biasa'),
            subtitle: const Text('Waktu biasa pada hari bekerja, off pada hari tutup'),
            onTap: () => Navigator.pop(c, ''),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (choice == null) return;
    final before = store.roster['${emp.id}_$date'];
    await store.setRoster(emp.id, date, choice.isEmpty ? null : choice);
    if (context.mounted) {
      showUndo(context, 'Syif ${emp.firstName} ${fmtShort(date)} dikemas kini',
          () => store.setRoster(emp.id, date, before));
    }
  }
}

/// Add, edit and remove shift patterns.
class ShiftsScreen extends StatelessWidget {
  const ShiftsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Syif kerja')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Syif baharu'),
      ),
      body: PageList(children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(s.defaultShift.label),
              subtitle: const Text('Waktu biasa. Ubah di Tetapan syarikat.'),
            ),
            for (final sh in s.shifts) ...[
              const Divider(indent: 56),
              ListTile(
                leading: CircleAvatar(radius: 10, backgroundColor: shiftColor(context, sh.id)),
                title: Text(sh.label),
                subtitle: sh.overnight ? const Text('Melepasi tengah malam') : null,
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(context, sh),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Future<void> _edit(BuildContext context, Shift? sh) async {
    final store = StoreScope.of(context);
    final name = TextEditingController(text: sh?.name ?? '');
    var start = sh?.start ?? '09:00', end = sh?.end ?? '18:00';
    TimeOfDay tod(String v) => TimeOfDay(hour: int.parse(v.substring(0, 2)), minute: int.parse(v.substring(3)));
    String fmt(TimeOfDay v) => '${two(v.hour)}:${two(v.minute)}';
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(sh == null ? 'Syif baharu' : 'Ubah syif'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nama', hintText: 'Contoh: Kahwin')),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mula'),
              trailing: Text(start, style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final v = await showTimePicker(context: c, initialTime: tod(start));
                if (v != null) set(() => start = fmt(v));
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tamat'),
              trailing: Text(end, style: const TextStyle(fontWeight: FontWeight.w700)),
              onTap: () async {
                final v = await showTimePicker(context: c, initialTime: tod(end));
                if (v != null) set(() => end = fmt(v));
              },
            ),
          ]),
          actions: [
            if (sh != null)
              TextButton(
                onPressed: () async {
                  await store.deleteShift(sh.id);
                  if (c.mounted) Navigator.pop(c);
                },
                child: const Text('Padam'),
              ),
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await store.saveShift(Shift(id: sh?.id ?? 's${store.newId()}', name: name.text.trim(), start: start, end: end));
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
  }
}

/// The next seven days for one employee: their shift or day off.
class MyScheduleCard extends StatelessWidget {
  const MyScheduleCard({super.key, required this.empId});
  final String empId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final start = DateTime(store.now.year, store.now.month, store.now.day);
    return Section(
      title: 'Jadual 7 hari',
      child: Column(children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (context) {
            final d = start.add(Duration(days: i));
            final key = ymd(d);
            final sh = store.shiftFor(empId, key);
            final leave = store.onLeave(key).any((r) => r.empId == empId);
            final hol = store.settings.holidayNames[key];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(
                  width: 86,
                  child: Text(i == 0 ? 'Hari ini' : '${_dayShort[d.weekday - 1]} ${d.day}',
                      style: t.bodyMedium?.copyWith(fontWeight: i == 0 ? FontWeight.w700 : null)),
                ),
                Expanded(
                  child: Text(
                    leave ? 'Cuti' : sh == null ? (hol ?? 'Off') : sh.label,
                    style: t.bodyMedium?.copyWith(color: sh == null || leave ? cs.onSurfaceVariant : null),
                  ),
                ),
                if (sh != null && sh.id != 'biasa' && !leave)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: shiftColor(context, sh.id), shape: BoxShape.circle),
                  ),
              ]),
            );
          }),
      ]),
    );
  }
}
