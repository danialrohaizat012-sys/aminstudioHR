import 'dart:async';
import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// Result of asking the device where it is.
class LocationFix {
  const LocationFix({this.lat, this.lng, this.accuracy, this.error, this.mocked = false});
  final double? lat, lng, accuracy;
  final String? error; // shown to the employee when the fix failed
  final bool mocked; // Android reported a mock provider, or the fix is implausibly exact

  bool get ok => error == null && lat != null && lng != null;
}

/// GPS and camera access used by the punch screen. Tests replace
/// [punchDevices] with a fake.
abstract class PunchDevices {
  Future<LocationFix> locate();

  /// A small front-camera JPEG as base64, or null if the employee cancelled.
  Future<String?> selfie();

  /// A photo of a claim receipt as base64 JPEG, or null if cancelled.
  Future<String?> receipt();

  /// Street address for a coordinate, or null when the lookup fails.
  Future<String?> address(double lat, double lng);

  /// Phone model (or browser on the web), e.g. "iPhone 14 Plus".
  Future<String?> deviceName();
}

PunchDevices punchDevices = DevicePunchDevices();

class DevicePunchDevices implements PunchDevices {
  @override
  Future<LocationFix> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationFix(error: 'Lokasi (GPS) telefon dimatikan. Hidupkan dan cuba lagi.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        return const LocationFix(error: 'Kebenaran lokasi ditolak. Benarkan lokasi untuk punch.');
      }
      if (perm == LocationPermission.deniedForever) {
        return const LocationFix(error: 'Kebenaran lokasi disekat. Buka tetapan telefon dan benarkan lokasi untuk app ini.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationFix(
        lat: p.latitude,
        lng: p.longitude,
        accuracy: p.accuracy,
        // Real GPS never reports 0 m accuracy; spoofing apps often do.
        mocked: p.isMocked || p.accuracy == 0,
      );
    } on TimeoutException {
      return const LocationFix(error: 'Lokasi mengambil masa terlalu lama. Cuba di kawasan terbuka.');
    } catch (_) {
      return const LocationFix(error: 'Lokasi tidak dapat dibaca pada peranti ini.');
    }
  }

  @override
  Future<String?> selfie() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 480,
      maxHeight: 480,
      imageQuality: 60,
    );
    if (file == null) return null;
    return base64Encode(await file.readAsBytes());
  }

  @override
  Future<String?> receipt() async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1200, imageQuality: 70);
    if (file == null) return null;
    return base64Encode(await file.readAsBytes());
  }

  // OpenStreetMap Nominatim: free, max 1 request per second, which suits one
  // lookup per punch for a small shop. Use a paid geocoder at larger scale.
  @override
  Future<String?> address(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lng',
        'zoom': '18',
        'accept-language': 'ms,en',
      });
      final res = await http
          .get(uri, headers: kIsWeb ? const {} : const {'User-Agent': 'AminStudioHR/1.0'})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;
      final name = (jsonDecode(res.body) as Map)['display_name'] as String?;
      if (name == null) return null;
      // Drop the trailing country for a shorter line.
      return name.replaceAll(RegExp(r',\s*Malaysia\s*$'), '');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> deviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final w = await info.webBrowserInfo;
        final browser = w.browserName.name;
        final os = w.platform ?? '';
        return '${browser[0].toUpperCase()}${browser.substring(1)} · $os';
      }
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final a = await info.androidInfo;
          return '${a.manufacturer} ${a.model}';
        case TargetPlatform.iOS:
          final i = await info.iosInfo;
          return i.modelName;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}
