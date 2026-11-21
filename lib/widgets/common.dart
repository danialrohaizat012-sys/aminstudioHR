import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// A titled card. Most screens are a column of these.
class Section extends StatelessWidget {
  const Section({super.key, required this.title, this.action, required this.child, this.padding});

  final String title;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              if (action != null) action!,
            ]),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class TextAction extends StatelessWidget {
  const TextAction(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(label),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final ReqStatus status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      ReqStatus.pending => 'warn',
      ReqStatus.approved => 'ok',
      ReqStatus.rejected => 'bad',
    };
    return Tag(status.label, tone: tone);
  }
}

class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone = 'mute'});
  final String label;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final c = statusColors(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.fg, fontWeight: FontWeight.w700)),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.employee, {super.key, this.radius = 18});
  final Employee? employee;
  final double radius;

  static const _shades = [
    Color(0xFF141414), Color(0xFFC21F17), Color(0xFF3A3A3A), Color(0xFF8A5A00),
    Color(0xFF5B5B5B), Color(0xFF9E2A1E),
  ];

  @override
  Widget build(BuildContext context) {
    final e = employee;
    final color = _shades[(e?.id.hashCode ?? 0).abs() % _shades.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        e?.initials ?? '?',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: radius * .72),
      ),
    );
  }
}

/// A row of figures inside one card, divided by hairlines.
class FigureStrip extends StatelessWidget {
  const FigureStrip({super.key, required this.items});
  final List<Figure> items;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outlineVariant;
    final rows = <List<Figure>>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(items.sublist(i, i + 2 > items.length ? items.length : i + 2));
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) Divider(height: 1, color: line),
            IntrinsicHeight(
              child: Row(children: [
                for (var c = 0; c < rows[r].length; c++) ...[
                  if (c > 0) VerticalDivider(width: 1, color: line),
                  Expanded(child: rows[r][c]),
                ],
                if (rows[r].length == 1) const Expanded(child: SizedBox()),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class Figure extends StatelessWidget {
  const Figure({super.key, required this.label, required this.value, this.note, this.onTap, this.progress});
  final String label, value;
  final String? note;
  final VoidCallback? onTap;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.3)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: progress, minHeight: 5, backgroundColor: cs.surfaceContainer),
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(note!, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}

class QuietText extends StatelessWidget {
  const QuietText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

/// Title line for a request, used in lists across the app.
String requestTitle(HrRequest r) => switch (r.kind) {
      ReqKind.leave =>
        '${r.leaveType}${r.halfDay == null ? '' : r.halfDay == 'am' ? ' (pagi)' : ' (petang)'} · ${daysLabel(r.days)}',
      ReqKind.claim => 'Tuntutan ${rm(r.amount)}',
      ReqKind.overtime => 'Lebih masa ${r.hours.toStringAsFixed(r.hours % 1 == 0 ? 0 : 1)} jam',
    };

String requestDetail(HrRequest r) => switch (r.kind) {
      ReqKind.leave => r.from == r.to ? fmtDate(r.from) : '${fmtShort(r.from)} – ${fmtDate(r.to)}',
      ReqKind.claim => '${r.category} · ${fmtDate(r.date)}',
      ReqKind.overtime => '${fmtDate(r.date)} · ${r.rate}×',
    };

IconData requestIcon(ReqKind k) => switch (k) {
      ReqKind.leave => Icons.event_available_outlined,
      ReqKind.claim => Icons.receipt_long_outlined,
      ReqKind.overtime => Icons.more_time_outlined,
    };

/// Pending request row with approve / reject, used on the manager home and
/// in the approvals inbox.
class ApprovalTile extends StatelessWidget {
  const ApprovalTile(this.r, {super.key, this.showBalance = false});
  final HrRequest r;
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final e = store.employeeById(r.empId);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    String? balanceNote, receipt;
    var overdraw = false;
    if (showBalance && r.kind == ReqKind.leave) {
      final b = store.leaveBalance(r.empId, r.leaveType!);
      if (b != null) {
        balanceNote = 'Baki selepas: ${daysLabel(b - r.days)}';
        overdraw = b - r.days < 0;
      }
    }
    if (showBalance && r.kind == ReqKind.overtime) {
      final month = (r.date ?? '').substring(0, 7);
      final total = store.overtimeHours(r.empId, month);
      overdraw = total > HrStore.overtimeCapHours;
      balanceNote = 'Anggaran bayaran ${rm(store.overtimePay(r))} · '
          '${total.toStringAsFixed(1)} / ${HrStore.overtimeCapHours.toInt()} jam OT bulan ini'
          '${overdraw ? ' (melebihi had Akta Kerja)' : ''}';
    }
    if (r.kind == ReqKind.claim && r.receipt != null) receipt = r.receipt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(e),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.nameOf(r.empId), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              Text(requestTitle(r), style: t.bodyMedium),
              Text(requestDetail(r), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              if (r.note.isNotEmpty)
                Text('“${r.note}”', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              if (receipt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InkWell(
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (c) => Dialog(
                        clipBehavior: Clip.antiAlias,
                        child: InteractiveViewer(child: Image.memory(base64Decode(receipt!))),
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(base64Decode(receipt), width: 44, height: 44, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 8),
                      Text('Lihat resit', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              if (balanceNote != null)
                Text(balanceNote,
                    style: t.bodySmall?.copyWith(
                        color: overdraw ? statusColors(context, 'bad').fg : cs.onSurfaceVariant,
                        fontWeight: overdraw ? FontWeight.w700 : null)),
            ]),
          ),
          Text(ago(r.createdAt), style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ]),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 48),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _decide(context, ReqStatus.rejected),
                style: OutlinedButton.styleFrom(foregroundColor: statusColors(context, 'bad').fg),
                child: const Text('Tolak'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => _decide(context, ReqStatus.approved),
                child: const Text('Lulus'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _decide(BuildContext context, ReqStatus s) async {
    final store = StoreScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = store.nameOf(r.empId);
    await store.decide(r.id, s);
    messenger.showSnackBar(SnackBar(
      content: Text('${r.kind.label} $name ${s == ReqStatus.approved ? 'diluluskan' : 'ditolak'}'),
      action: SnackBarAction(label: 'Batal', onPressed: () => store.undoDecision(r.id)),
    ));
  }
}

/// Put one of these in a [PageList] to split it into two columns on wide
/// screens. On phones it is ignored and the page stays a single column.
class ColumnBreak extends StatelessWidget {
  const ColumnBreak({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Standard scrolling page body. Content is centred and capped at
/// [maxWidth] so it does not stretch across a desktop monitor; pages that
/// include a [ColumnBreak] become two columns from 1000 px.
class PageList extends StatelessWidget {
  const PageList({super.key, required this.children, this.onRefresh, this.maxWidth = 760});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final double maxWidth;

  static const gap = 12.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final breakAt = children.indexWhere((w) => w is ColumnBreak);
      final twoCol = breakAt >= 0 && box.maxWidth >= 1000;
      final cap = twoCol ? 1180.0 : maxWidth;
      final side = ((box.maxWidth - cap) / 2).clamp(16.0, double.infinity);
      final padding = EdgeInsets.fromLTRB(side, box.maxWidth >= 840 ? 16 : 8, side, 96);
      final items = children.where((w) => w is! ColumnBreak).toList();

      Widget column(List<Widget> ws) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < ws.length; i++) ...[if (i > 0) const SizedBox(height: gap), ws[i]],
            ],
          );

      final Widget list = twoCol
          ? ListView(padding: padding, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 11, child: column(children.sublist(0, breakAt))),
                const SizedBox(width: 16),
                Expanded(flex: 9, child: column(children.sublist(breakAt + 1))),
              ]),
            ])
          : ListView.separated(
              padding: padding,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: gap),
              itemBuilder: (_, i) => items[i],
            );
      return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
    });
  }
}
