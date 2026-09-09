import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';

class LocationService {
  final Dio dio;
  final SharedPreferences prefs;

  LocationService({required this.dio, required this.prefs});

  StreamSubscription<Position>? _positionStreamSubscription;
  final ValueNotifier<Position?> currentPosition = ValueNotifier(null);

  /// Memeriksa status GPS dan Izin (Permissions).
  /// Memaksa user menyalakan GPS dan memberikan izin.
  Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true; 
  }

  /// Memulai tracking lokasi secara live (Position Stream)
  void startTracking() {
    _positionStreamSubscription?.cancel();

    late LocationSettings locationSettings;

    if (Platform.isAndroid) {
      // Untuk Android: Memaksa menggunakan chip GPS perangkat langsung (bukan estimasi Google / WiFi)
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5, // Update setiap bergeser 5 meter
        forceLocationManager: true, // INI KUNCI untuk akurasi maksimal di Android
        intervalDuration: const Duration(seconds: 5), // Update max tiap 5 detik
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      // Untuk iOS: Menggunakan akurasi khusus navigasi yang paling detail
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 5,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      );
    }

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      currentPosition.value = position;
      await _sendLocationToBackend(position);
    });
  }

  /// Menghentikan tracking lokasi
  void stopTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  /// Mengirim koordinat dan alamat ke Backend
  Future<void> _sendLocationToBackend(Position position) async {
    try {
      final token = prefs.getString('auth_token');
      if (token == null) return; // User belum login

      // Opsional: Dapatkan teks alamat (reverse geocoding)
      String alamat = "Lokasi Tidak Diketahui";
      try {
        final geocoding = geo.Geocoding();
        List<geo.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          geo.Placemark place = placemarks.first;
          alamat = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}";
        }
      } catch (e) {
        // Abaikan jika geocoding gagal, tetap kirim koordinat
      }

      // API Call ke Laravel
      await dio.post(
        '${ApiConstants.baseUrl}/user/update-location',
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'lokasi_user': alamat,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      print('✅ Lokasi berhasil diupdate: Lat ${position.latitude}, Lng ${position.longitude}');
    } catch (e) {
      print('❌ Gagal mengupdate lokasi ke server: $e');
    }
  }
}
