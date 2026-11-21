import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Sign-in with a 6-digit PIN, or choose one on first sign-in.
Future<void> showPinSheet(BuildContext context, Employee e) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PinSheet(employee: e),
    );

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.employee});
  final Employee employee;
  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String pin = '';
  String? first; // when creating: the PIN entered the first time
  String? error;
  bool busy = false;

  bool get creating => StoreScope.of(context).needsPin(widget.employee.id);

  Future<void> _press(String k) async {
    if (busy) return;
    if (k == '<') {
      setState(() => pin = pin.isEmpty ? '' : pin.substring(0, pin.length - 1));
      return;
    }
    if (pin.length >= 6) return;
    setState(() {
      pin += k;
      error = null;
    });
    if (pin.length == 6) await _submit();
  }

  Future<void> _submit() async {
    final store = StoreScope.of(context);
    final nav = Navigator.of(context);
    setState(() => busy = true);
    String? err;
    if (creating) {
      if (first == null) {
        err = HrStore.pinProblem(pin);
        if (err == null) {
          setState(() {
            first = pin;
            pin = '';
            busy = false;
          });
          return;
        }
      } else if (first != pin) {
        err = 'PIN tidak sama. Mula semula.';
        first = null;
      } else {
        err = await store.createPin(widget.employee.id, pin);
      }
    } else {
      err = await store.signIn(widget.employee.id, pin);
    }
    if (!mounted) return;
    if (err == null) {
      nav.pop();
      return;
    }
    setState(() {
      error = err;
      pin = '';
      busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final locked = store.lockMinutesLeft(widget.employee.id);
    final title = creating ? (first == null ? 'Cipta PIN 6 digit' : 'Masukkan PIN sekali lagi') : 'Masukkan PIN';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Avatar(widget.employee, radius: 28),
        const SizedBox(height: 10),
        Text(widget.employee.name, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(title, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < 6; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              margin: const EdgeInsets.symmetric(horizontal: 7),
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < pin.length ? cs.primary : Colors.transparent,
                border: Border.all(color: i < pin.length ? cs.primary : cs.outline, width: 1.5),
              ),
            ),
        ]),
        SizedBox(
          height: 40,
          child: Center(
            child: Text(
              locked > 0 ? 'Akaun dikunci. Cuba lagi dalam $locked minit.' : (error ?? ''),
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: statusColors(context, 'bad').fg, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        if (creating && first == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Elak tarikh lahir atau nombor berturutan.', style: t.bodySmall),
          ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final k in row)
              Padding(
                padding: const EdgeInsets.all(6),
                child: SizedBox(
                  width: 76,
                  height: 60,
                  child: k.isEmpty
                      ? null
                      : TextButton(
                          key: ValueKey('pin-$k'),
                          onPressed: locked > 0 ? null : () => _press(k),
                          style: TextButton.styleFrom(
                            backgroundColor: k == '<' ? null : cs.surfaceContainer,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: k == '<'
                              ? const Icon(Icons.backspace_outlined)
                              : Text(k, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                ),
              ),
          ]),
      ]),
    );
  }
}
