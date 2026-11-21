import 'package:material_ui/material_ui.dart';

import '../store.dart';
import '../widgets/brand.dart';

/// Three short pages shown the first time an employee signs in on a device.
class WelcomeTour extends StatefulWidget {
  const WelcomeTour({super.key});
  @override
  State<WelcomeTour> createState() => _WelcomeTourState();
}

class _WelcomeTourState extends State<WelcomeTour> {
  final pager = PageController();
  int page = 0;

  static const pages = [
    (
      Icons.fingerprint,
      'Punch masuk di kedai',
      'Tekan Punch masuk di skrin Utama. Hidupkan lokasi telefon dan ambil selfie. '
          'Punch di luar kawasan kedai perlu sebab.',
    ),
    (
      Icons.event_available_outlined,
      'Mohon cuti dan tuntutan',
      'Buka Permohonan untuk mohon cuti, tuntutan (snap resit) atau lebih masa. '
          'Anda akan nampak bila pengurus lulus atau tolak.',
    ),
    (
      Icons.receipt_long_outlined,
      'Slip gaji dan jadual',
      'Slip gaji keluar di tab Gaji setiap bulan. Jadual syif 7 hari dan job anda ada di skrin Kehadiran dan Utama.',
    ),
  ];

  @override
  void dispose() {
    pager.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final store = StoreScope.of(context);
    final nav = Navigator.of(context);
    await store.markTourSeen();
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final last = page == pages.length - 1;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(children: [
                    const BrandMark(size: 36),
                    const Spacer(),
                    TextButton(onPressed: _done, child: const Text('Langkau')),
                  ]),
                ),
                Expanded(
                  child: PageView(
                    controller: pager,
                    onPageChanged: (i) => setState(() => page = i),
                    children: [
                      for (final (icon, title, body) in pages)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                              child: Icon(icon, size: 56, color: cs.onPrimaryContainer),
                            ),
                            const SizedBox(height: 32),
                            Text(title,
                                textAlign: TextAlign.center,
                                style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 12),
                            Text(body,
                                textAlign: TextAlign.center,
                                style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant, height: 1.45)),
                          ]),
                        ),
                    ],
                  ),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < pages.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == page ? cs.onSurface : cs.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                ]),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                      onPressed: last
                          ? _done
                          : () => pager.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut),
                      child: Text(last ? 'Mula, ${store.me?.firstName ?? ''}' : 'Seterusnya'),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
