import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  final Dio dio;
  final SharedPreferences prefs;

  LocationService({required this.dio, required this.prefs});

  StreamSubscription<Position>? _positionStreamSubscription;
  final ValueNotifier<Position?> currentPosition = ValueNotifier(null);
  Position? _lastGeocodedPosition;

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
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // Update setiap bergeser 15 meter
        forceLocationManager: false, // Gunakan Fused Location Provider (lebih hemat baterai)
        intervalDuration: const Duration(seconds: 10), // Update max tiap 10 detik
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      // Untuk iOS: Menggunakan akurasi khusus navigasi yang paling detail
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 15,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      );
    }

    // Dapatkan posisi saat ini secara langsung terlebih dahulu
    Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).then((Position position) async {
      currentPosition.value = position;
      await _sendLocationToBackend(position);
    }).catchError((e) {
      debugPrint("Gagal mendapatkan posisi awal: $e");
    });

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

  String _lastGeocodedAddress = "Lokasi Tidak Diketahui";

  /// Mengirim koordinat dan alamat ke Backend (dengan throttle geocoding)
  Future<void> _sendLocationToBackend(Position position) async {
    try {
      final token = prefs.getString('auth_token');
      if (token == null) return; // User belum login

      // Throttle geocoding: hanya geocode jika bergerak > 50 meter dari posisi terakhir
      try {
        bool shouldGeocode = _lastGeocodedPosition == null ||
            Geolocator.distanceBetween(
              _lastGeocodedPosition!.latitude,
              _lastGeocodedPosition!.longitude,
              position.latitude,
              position.longitude,
            ) > 50;

        if (shouldGeocode) {
          final geocoding = geo.Geocoding();
          List<geo.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            geo.Placemark place = placemarks.first;
            _lastGeocodedAddress = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.administrativeArea}";
          }
          _lastGeocodedPosition = position;
        }
      } catch (e) {
        // Abaikan jika geocoding gagal, tetap kirim koordinat
      }

      // API Call ke Laravel
      await dio.post(
        ApiConstants.updateLocation,
        data: {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'lokasi_user': _lastGeocodedAddress,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );
      debugPrint('✅ Lokasi berhasil diupdate: Lat ${position.latitude}, Lng ${position.longitude}');
    } catch (e) {
      debugPrint('❌ Gagal mengupdate lokasi ke server: $e');
    }
  }
}
