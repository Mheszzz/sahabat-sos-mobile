import 'package:flutter/foundation.dart';
import 'package:laravel_echo/laravel_echo.dart';
import 'package:pusher_client_socket/pusher_client_socket.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';

/// Wrapper agar [PusherClient] dari pusher_client_socket kompatibel dengan
/// `PusherConnector` yang ada di dalam package `laravel_echo`.
class EchoPusherClientWrapper {
  final PusherClient _client;

  EchoPusherClientWrapper(this._client);

  void connect() => _client.connect();
  void disconnect() => _client.disconnect();
  String? getSocketId() => _client.socketId;
  Channel subscribe(String channelName) => _client.subscribe(channelName);
  void unsubscribe(String channelName) => _client.unsubscribe(channelName);
}

class WebsocketService {
  static Echo? echo;
  static PusherClient? _pusher;

  static Future<void> init(String token) async {
    if (echo != null) return;

    final uri = Uri.parse(ApiConstants.baseUrl);
    // Host dan port diambil dari baseUrl (misal: 192.168.1.22)
    final host = uri.host;
    // Laravel Reverb default berjalan di port 8080
    // Sesuaikan jika kamu menggunakan port lain di .env backend (REVERB_PORT)
    const int reverbPort = 8080;

    try {
      final options = PusherOptions(
        // =====================================================================
        // PENTING: Sesuaikan key dengan REVERB_APP_KEY di file .env backend
        // Cek di file .env Laravel kamu, cari: REVERB_APP_KEY=...
        // =====================================================================
        key: 'app-key',
        cluster: 'mt1',
        
        // =====================================================================
        // KUNCI UTAMA: Arahkan koneksi ke server Reverb lokal
        // =====================================================================
        host: host,
        wsPort: reverbPort,
        wssPort: reverbPort,
        encrypted: false, // Set ke true jika menggunakan wss (SSL/HTTPS) di production
        autoConnect: false,
        
        // Auth endpoint untuk private channel
        authOptions: PusherAuthOptions(
          '${uri.scheme}://$host:${uri.port}/api/broadcasting/auth',
          headers: () async => {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ),
      );

      _pusher = PusherClient(options: options);
      
      _pusher!.onConnectionStateChange((state) {
        debugPrint("🔌 WebSocket State: $state");
      });
      _pusher!.onConnectionError((error) {
        debugPrint("❌ WebSocket Error: $error");
      });
      
      _pusher!.connect();

      echo = Echo(
        broadcaster: EchoBroadcasterType.Pusher,
        client: EchoPusherClientWrapper(_pusher!),
      );
      
      debugPrint("✅ Laravel Reverb (WebSocket) Berhasil Terhubung ke $host:$reverbPort");
    } catch (e) {
      debugPrint("❌ WebSocket Init Error: $e");
    }
  }

  /// Relawan mendengarkan pergerakan lokasi user secara realtime
  static void listenToEmergencyLocation(int sosId, Function(dynamic) onDataReceived) {
    if (echo == null) {
      debugPrint("⚠️ listenToEmergencyLocation: echo belum init");
      return;
    }
    
    debugPrint("👂 Listening channel: emergency.tracking.$sosId");
    echo!.channel('emergency.tracking.$sosId')
      .listen('.LocationUpdated', (e) {
        debugPrint("📍 LocationUpdated diterima untuk SOS #$sosId");
        onDataReceived(e);
      });
  }

  /// Berhenti mendengarkan ketika darurat selesai
  static void stopListeningEmergencyLocation(int sosId) {
    echo?.leave('emergency.tracking.$sosId');
  }

  /// Relawan mendengarkan penugasan SOS baru secara realtime
  static void listenToNewSosForVolunteer(int volunteerId, Function(dynamic) onNewSosReceived) {
    if (echo == null) {
      debugPrint("⚠️ listenToNewSosForVolunteer: echo belum init");
      return;
    }
    
    // ─── Channel spesifik relawan ───
    debugPrint("👂 Listening private channel: relawan.$volunteerId");
    echo!.private('relawan.$volunteerId')
      .listen('.SOSCreated', (e) {
        debugPrint("🚨 SOSCreated (.prefixed) diterima di relawan.$volunteerId");
        onNewSosReceived(e);
      });
      
    echo!.private('relawan.$volunteerId')
      .listen('SOSCreated', (e) {
        debugPrint("🚨 SOSCreated (no-prefix) diterima di relawan.$volunteerId");
        onNewSosReceived(e);
      });

    // ─── Channel umum semua relawan ───
    debugPrint("👂 Listening private channel: relawan-channel");
    echo!.private('relawan-channel')
      .listen('.SOSCreated', (e) {
        debugPrint("🚨 SOSCreated (.prefixed) diterima di relawan-channel");
        onNewSosReceived(e);
      });
      
    echo!.private('relawan-channel')
      .listen('SOSCreated', (e) {
        debugPrint("🚨 SOSCreated (no-prefix) diterima di relawan-channel");
        onNewSosReceived(e);
      });
  }

  /// Berhenti mendengarkan penugasan SOS baru
  static void stopListeningNewSosForVolunteer(int volunteerId) {
    echo?.leave('relawan.$volunteerId');
    echo?.leave('relawan-channel');
  }
}
