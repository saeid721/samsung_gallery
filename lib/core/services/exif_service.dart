import 'dart:io';
import 'package:native_exif/native_exif.dart';
import 'package:image/image.dart' as img;

class ExifData {
  final double? latitude;
  final double? longitude;
  final double? altitude;
  final String? make;
  final String? model;
  final String? lensModel;
  final String? aperture;
  final String? shutterSpeed;
  final int? iso;
  final double? focalLength;
  final int? width;
  final int? height;
  final String? colorSpace;
  final String? orientation;
  final DateTime? dateTaken;
  final DateTime? dateDigitized;

  const ExifData({
    this.latitude,
    this.longitude,
    this.altitude,
    this.make,
    this.model,
    this.lensModel,
    this.aperture,
    this.shutterSpeed,
    this.iso,
    this.focalLength,
    this.width,
    this.height,
    this.colorSpace,
    this.orientation,
    this.dateTaken,
    this.dateDigitized,
  });

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasCameraInfo => make != null || model != null;

  String? get cameraDisplay =>
      [make, model].where((s) => s != null).join(' ');

  String? get exposureDisplay {
    final parts = <String>[
      if (aperture != null) aperture!,
      if (iso != null) 'ISO $iso',
      if (shutterSpeed != null) shutterSpeed!,
    ];
    return parts.isEmpty ? null : parts.join('  ');
  }
}

class ExifService {
  /// Read EXIF from file
  Future<ExifData> readExif(String filePath) async {
    try {
      final exif = await Exif.fromPath(filePath);
      final latLng = await exif.getLatLong();
      final attrs = await exif.getAttributes();
      await exif.close();
// ── Safe helper to cast EXIF attribute to String? ─────────
      String? _asString(Object? val) {
        if (val == null) return null;
        if (val is String) return val;
        return val.toString();
      }
      return ExifData(
        latitude: latLng?.latitude,
        longitude: latLng?.longitude,
        altitude: _parseDouble(_asString(attrs?['GPSAltitude'])),
        make: _asString(attrs?['Make']),
        model: _asString(attrs?['Model']),
        lensModel: _asString(attrs?['LensModel']),
        aperture: _formatAperture(_asString(attrs?['FNumber'])),
        shutterSpeed: _formatShutter(_asString(attrs?['ExposureTime'])),
        iso: _parseInt(_asString(attrs?['ISOSpeedRatings'])),
        focalLength: _parseDouble(_asString(attrs?['FocalLength'])),
        width: _parseInt(_asString(attrs?['ImageWidth'] ?? attrs?['PixelXDimension'])),
        height: _parseInt(_asString(attrs?['ImageLength'] ?? attrs?['PixelYDimension'])),
        colorSpace: _asString(attrs?['ColorSpace']),
        dateTaken: _parseExifDate(_asString(attrs?['DateTimeOriginal'])),
        dateDigitized: _parseExifDate(_asString(attrs?['DateTimeDigitized'])),
        orientation: _asString(attrs?['Orientation']),
      );
    } catch (_) {
      return const ExifData();
    }
  }

  /// Write GPS coordinates
  Future<bool> writeGps(String filePath, double lat, double lng,
      {double? altitude}) async {
    try {
      final exif = await Exif.fromPath(filePath);
      await exif.writeAttributes({
        'GPSLatitude': lat.abs().toString(),
        'GPSLatitudeRef': lat >= 0 ? 'N' : 'S',
        'GPSLongitude': lng.abs().toString(),
        'GPSLongitudeRef': lng >= 0 ? 'E' : 'W',
        if (altitude != null) 'GPSAltitude': altitude.toString(),
      });
      await exif.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Strip all EXIF by re-encoding
  Future<bool> stripExif(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return false;
      final strippedBytes = img.encodeJpg(image); // strips EXIF
      await File(filePath).writeAsBytes(strippedBytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ───────────────────────────────

  double? _parseDouble(String? val) {
    if (val == null) return null;
    if (val.contains('/')) {
      final parts = val.split('/');
      if (parts.length == 2) {
        final n = double.tryParse(parts[0]);
        final d = double.tryParse(parts[1]);
        if (n != null && d != null && d != 0) return n / d;
      }
    }
    return double.tryParse(val);
  }

  int? _parseInt(String? val) {
    if (val == null) return null;
    return int.tryParse(val);
  }

  String? _formatAperture(String? fnumber) {
    final d = _parseDouble(fnumber);
    if (d == null) return null;
    return 'f/${d.toStringAsFixed(1)}';
  }

  String? _formatShutter(String? exposureTime) {
    final d = _parseDouble(exposureTime);
    if (d == null) return null;
    if (d >= 1) return '${d.toStringAsFixed(1)}s';
    final denom = (1 / d).round();
    return '1/${denom}s';
  }

  DateTime? _parseExifDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final parts = raw.split(' ');
      if (parts.length < 2) return null;
      final dateParts = parts[0].split(':');
      final timeParts = parts[1].split(':');
      return DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
        int.parse(timeParts[2]),
      );
    } catch (_) {
      return null;
    }
  }
}