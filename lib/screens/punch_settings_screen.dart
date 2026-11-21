import 'package:material_ui/material_ui.dart';

import '../services/punch_devices.dart';
import '../store.dart';
import '../widgets/common.dart';
import 'punch_screen.dart';

/// Manager's punch rules: shop location, allowed radius, area check, selfie.
class PunchSettingsScreen extends StatefulWidget {
  const PunchSettingsScreen({super.key});
  @override
  State<PunchSettingsScreen> createState() => _PunchSettingsScreenState();
}

class _PunchSettingsScreenState extends State<PunchSettingsScreen> {
  final coords = TextEditingController();
  double? lat, lng;
  late double radius;
  late bool requireLocation, requireSelfie;
  bool locating = false;
  bool _ready = false;
  String? coordsError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _ready = true;
    final s = StoreScope.of(context).settings;
    lat = s.officeLat;
    lng = s.officeLng;
    if (s.hasOffice) coords.text = '${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}';
    radius = s.radiusM;
    requireLocation = s.requireLocation;
    requireSelfie = s.requireSelfie;
  }

  @override
  void dispose() {
    coords.dispose();
    super.dispose();
  }

  Future<void> _useHere() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => locating = true);
    final f = await punchDevices.locate();
    if (!mounted) return;
    setState(() => locating = false);
    if (!f.ok) {
      messenger.showSnackBar(SnackBar(content: Text(f.error ?? 'Lokasi tidak dapat dibaca.')));
      return;
    }
    setState(() {
      lat = f.lat;
      lng = f.lng;
      coords.text = '${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}';
      coordsError = null;
    });
    messenger.showSnackBar(SnackBar(content: Text('Lokasi semasa diambil (ketepatan ±${f.accuracy?.round() ?? '?'} m)')));
  }

  /// Accepts "6.118, 102.242" as copied from Google Maps.
  void _parse(String v) {
    final parts = v.split(RegExp(r'[,\s]+')).where((p) => p.isNotEmpty).toList();
    final a = parts.length == 2 ? double.tryParse(parts[0]) : null;
    final b = parts.length == 2 ? double.tryParse(parts[1]) : null;
    setState(() {
      if (v.trim().isEmpty) {
        lat = lng = null;
        coordsError = null;
      } else if (a == null || b == null || a.abs() > 90 || b.abs() > 180) {
        coordsError = 'Format: latitud, longitud (contoh 6.118000, 102.242000)';
      } else {
        lat = a;
        lng = b;
        coordsError = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Tetapan punch')),
      body: PageList(children: [
        Section(
          title: 'Lokasi kedai',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Pekerja mesti berada dalam radius dari titik ini semasa punch.',
                style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: coords,
              onChanged: _parse,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: 'Koordinat',
                hintText: '6.118000, 102.242000',
                helperText: 'Tampal dari Google Maps, atau guna lokasi semasa di kedai',
                errorText: coordsError,
                prefixIcon: const Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: locating ? null : _useHere,
              icon: locating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, size: 18),
              label: const Text('Guna lokasi semasa saya'),
            ),
          ]),
        ),
        Section(
          title: 'Radius kawasan',
          action: Text(fmtDistance(radius), style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Slider(
              value: radius,
              min: 50,
              max: 1000,
              divisions: 19,
              label: fmtDistance(radius),
              onChanged: (v) => setState(() => radius = v),
            ),
            Text('GPS telefon biasanya tepat dalam 10 hingga 50 m. 100 hingga 200 m sesuai untuk kedai.',
                style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            SwitchListTile(
              value: requireSelfie,
              onChanged: (v) => setState(() => requireSelfie = v),
              title: const Text('Wajib selfie'),
              subtitle: const Text('Gambar muka disimpan sebagai bukti setiap punch'),
            ),
            const Divider(),
            SwitchListTile(
              value: requireLocation,
              onChanged: (v) => setState(() => requireLocation = v),
              title: const Text('Semak kawasan kedai'),
              subtitle: const Text('Punch di luar radius perlu sebab dan ditanda untuk HR'),
            ),
            const Divider(),
            const ListTile(
              leading: Icon(Icons.location_on_outlined),
              title: Text('Lokasi telefon sentiasa wajib'),
              subtitle: Text('Punch disekat jika lokasi telefon dimatikan atau tidak dibenarkan'),
            ),
          ]),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          onPressed: coordsError != null
              ? null
              : () async {
                  final s = store.settings
                    ..officeLat = lat
                    ..officeLng = lng
                    ..radiusM = radius
                    ..requireLocation = requireLocation
                    ..requireSelfie = requireSelfie;
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  await store.updateSettings(s);
                  nav.pop();
                  messenger.showSnackBar(const SnackBar(content: Text('Tetapan punch disimpan')));
                },
          child: const Text('Simpan'),
        ),
      ]),
    );
  }
}
