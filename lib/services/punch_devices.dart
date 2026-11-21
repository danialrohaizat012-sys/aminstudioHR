import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
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
}
