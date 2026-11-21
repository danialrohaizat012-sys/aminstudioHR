import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../services/punch_devices.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

String fmtDistance(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

/// Full-screen punch in / punch out: live clock, location check against the
/// office radius, optional selfie, and a reason when outside the area.
class PunchScreen extends StatefulWidget {
  const PunchScreen({super.key, required this.clockIn});
  final bool clockIn;

  @override
  State<PunchScreen> createState() => _PunchScreenState();
}

class _PunchScreenState extends State<PunchScreen> {
  LocationFix? fix;
  String? address, device;
  bool locating = true;
  String? photo;
  bool saving = false;
  final note = TextEditingController();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    punchDevices.deviceName().then((d) => device = d);
    _locate();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    note.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() => locating = true);
    final f = await punchDevices.locate();
    if (!mounted) return;
    setState(() {
      fix = f;
      locating = false;
      address = null;
    });
    if (f.ok && !f.mocked) {
      final a = await punchDevices.address(f.lat!, f.lng!);
      if (mounted) setState(() => address = a);
    }
  }

  Future<void> _selfie() async {
    final p = await punchDevices.selfie();
    if (p != null && mounted) setState(() => photo = p);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final now = store.now;
    final distance =
        fix?.ok == true ? store.distanceToOffice(fix!.lat, fix!.lng) : null;
    final needsReason = !locating && store.outsideArea(distance);
    final hasLocation = fix?.ok == true && !fix!.mocked;
    final ready = !locating &&
        !saving &&
        hasLocation &&
        (!s.requireSelfie || photo != null) &&
        (!needsReason || note.text.trim().isNotEmpty);
    final action = widget.clockIn ? 'Punch masuk' : 'Punch keluar';
    final late = widget.clockIn &&
        hm(now).compareTo(s.startTime) > 0 &&
        store.isWorkday(now);

    return Scaffold(
      appBar: AppBar(title: Text(action)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Center(
                child: Column(children: [
                  Text('${two(now.hour)}:${two(now.minute)}',
                      style: t.displayLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -3,
                          height: 1)),
                  const SizedBox(height: 6),
                  Text(longDate(now),
                      style: t.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                  if (late)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Tag('Selepas waktu mula ${s.startTime}',
                          tone: 'warn'),
                    ),
                ]),
              ),
              const SizedBox(height: 24),
              _LocationCard(
                locating: locating,
                fix: fix,
                distance: distance,
                address: address,
                onRetry: _locate,
              ),
              if (s.requireSelfie) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: cs.surfaceContainer,
                        backgroundImage: photo == null
                            ? null
                            : MemoryImage(base64Decode(photo!)),
                        child: photo == null
                            ? Icon(Icons.face_outlined,
                                color: cs.onSurfaceVariant)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Selfie',
                                  style: t.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              Text(
                                  photo == null
                                      ? 'Wajib sebagai bukti punch'
                                      : 'Gambar sedia. Akan disimpan bersama punch.',
                                  style: t.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant)),
                            ]),
                      ),
                      OutlinedButton.icon(
                        onPressed: _selfie,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(photo == null ? 'Ambil' : 'Ambil semula'),
                      ),
                    ]),
                  ),
                ),
              ],
              if (needsReason) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Sebab punch di luar kawasan',
                    hintText: 'Contoh: penggambaran perkahwinan di Pasir Mas',
                    helperText: 'Punch ini akan ditanda untuk semakan HR.',
                  ),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: t.titleMedium),
                onPressed: ready ? () => _submit(store, distance) : null,
                icon: Icon(widget.clockIn ? Icons.login : Icons.logout),
                label: Text(saving ? 'Menyimpan…' : '$action sekarang'),
              ),
              if (!ready && !locating && !saving)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    fix?.mocked == true
                        ? 'Punch disekat kerana lokasi palsu dikesan.'
                        : !hasLocation
                            ? 'Punch tidak boleh dibuat selagi lokasi telefon dimatikan atau tidak dibenarkan.'
                            : s.requireSelfie && photo == null
                                ? 'Ambil selfie dahulu sebagai bukti.'
                                : 'Nyatakan sebab punch di luar kawasan.',
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(
                        color: !hasLocation
                            ? statusColors(context, 'bad').fg
                            : cs.onSurfaceVariant,
                        fontWeight: !hasLocation ? FontWeight.w600 : null),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(HrStore store, double? distance) async {
    setState(() => saving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final f = fix;
    final reason = note.text.trim();
    final error = widget.clockIn
        ? await store.punchIn(
            lat: f?.lat,
            lng: f?.lng,
            accuracy: f?.accuracy,
            photo: photo,
            note: reason,
            mocked: f?.mocked ?? false,
            address: address,
            device: device)
        : await store.punchOut(
            lat: f?.lat,
            lng: f?.lng,
            accuracy: f?.accuracy,
            photo: photo,
            note: reason,
            mocked: f?.mocked ?? false,
            address: address,
            device: device);
    if (error != null) {
      if (mounted) setState(() => saving = false);
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    HapticFeedback.mediumImpact();
    if (mounted) await showPunchDone(context, widget.clockIn);
    nav.pop(true);
    messenger.showSnackBar(SnackBar(
      content: Text(
          '${widget.clockIn ? 'Punch masuk' : 'Punch keluar'} ${hm(store.now)} direkod'
          '${distance != null ? ' · ${fmtDistance(distance)} dari kedai' : ''}'),
    ));
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard(
      {required this.locating,
      required this.fix,
      required this.distance,
      required this.onRetry,
      this.address});
  final bool locating;
  final LocationFix? fix;
  final double? distance;
  final VoidCallback onRetry;
  final String? address;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = store.settings;
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    late final String title, detail, tone;
    late final IconData icon;
    if (locating) {
      title = 'Mencari lokasi…';
      detail = 'Pastikan GPS dihidupkan.';
      tone = 'mute';
      icon = Icons.my_location;
    } else if (fix == null || !fix!.ok) {
      title = 'Lokasi tidak tersedia';
      detail = fix?.error ?? 'Hidupkan lokasi telefon dan cuba lagi.';
      tone = 'bad';
      icon = Icons.location_off_outlined;
    } else if (fix!.mocked) {
      title = 'Lokasi palsu dikesan';
      detail = 'Matikan app lokasi palsu (mock location) dan cuba lagi.';
      tone = 'bad';
      icon = Icons.gpp_bad_outlined;
    } else if (!s.hasOffice) {
      title = 'Lokasi direkod';
      detail =
          'Ketepatan ±${fix!.accuracy?.round() ?? '?'} m. HR belum tetapkan lokasi kedai.';
      tone = 'mute';
      icon = Icons.location_on_outlined;
    } else if (distance! <= s.radiusM) {
      title = 'Dalam kawasan kedai';
      detail =
          '${fmtDistance(distance!)} dari kedai · ketepatan ±${fix!.accuracy?.round() ?? '?'} m';
      tone = 'ok';
      icon = Icons.where_to_vote_outlined;
    } else {
      title = 'Luar kawasan kedai';
      detail =
          '${fmtDistance(distance!)} dari kedai (had ${fmtDistance(s.radiusM)})';
      tone = s.requireLocation ? 'warn' : 'mute';
      icon = Icons.wrong_location_outlined;
    }
    final c = statusColors(context, tone);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: c.bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: c.fg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: t.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(detail,
                        style:
                            t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    if (address != null && !locating)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(address!, style: t.bodySmall),
                      ),
                  ]),
            ),
            if (!locating && (fix == null || !fix!.ok || fix!.mocked))
              TextButton(onPressed: onRetry, child: const Text('Cuba lagi')),
          ]),
          if (locating) ...[
            const SizedBox(height: 12),
            ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: const LinearProgressIndicator(minHeight: 4)),
          ],
        ]),
      ),
    );
  }
}

/// PDPA 2010 notice shown once before the first punch: what is collected,
/// why, who sees it. Returns true when the employee agrees.
Future<bool?> showPrivacyNotice(BuildContext context) => showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.privacy_tip_outlined),
        title: const Text('Notis privasi punch'),
        content: const SingleChildScrollView(
          child: Text(
            'Setiap kali anda punch masuk atau keluar, app ini merekod:\n\n'
            '• Lokasi GPS telefon dan jaraknya dari kedai\n'
            '• Selfie sebagai bukti (jika diwajibkan majikan)\n'
            '• Masa punch\n\n'
            'Data ini digunakan untuk rekod kehadiran dan gaji sahaja, hanya boleh dilihat oleh anda dan pengurus HR, '
            'dan lokasi hanya dibaca ketika anda menekan butang punch, bukan sepanjang masa.\n\n'
            'Anda boleh bertanya kepada HR untuk melihat atau membetulkan data anda di bawah Akta Perlindungan Data Peribadi 2010.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Tidak setuju')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Setuju')),
        ],
      ),
    );

/// A big tick for a moment, so staff know the punch went through.
Future<void> showPunchDone(BuildContext context, bool clockIn) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final cs = Theme.of(context).colorScheme;
  final t = Theme.of(context).textTheme;
  final done = showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Selesai',
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (c, _, __) => Center(
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .4, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: statusColors(c, 'ok').bg, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 52, color: statusColors(c, 'ok').fg),
              ),
            ),
            const SizedBox(height: 16),
            Text(clockIn ? 'Punch masuk berjaya' : 'Punch keluar berjaya',
                style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    ),
    transitionBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  );
  var open = true;
  done.then((_) => open = false);
  await Future.any([done, Future<void>.delayed(const Duration(milliseconds: 1100))]);
  if (open) nav.pop();
}
