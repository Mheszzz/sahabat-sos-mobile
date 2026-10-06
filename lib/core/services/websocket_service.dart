import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart';
import 'dart:convert';
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
        encrypted:
            false, // Set ke true jika menggunakan wss (SSL/HTTPS) di production
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

      debugPrint(
        "✅ Laravel Reverb (WebSocket) Berhasil Terhubung ke $host:$reverbPort",
      );
    } catch (e) {
      debugPrint("❌ WebSocket Init Error: $e");
    }
  }

  /// Relawan mendengarkan pergerakan lokasi user secara realtime
  static void listenToEmergencyLocation(
    int sosId,
    Function(dynamic) onDataReceived,
  ) {
    if (echo == null) {
      debugPrint("⚠️ listenToEmergencyLocation: echo belum init");
      return;
    }

    debugPrint("👂 Listening channel: emergency.tracking.$sosId");
    echo!.channel('emergency.tracking.$sosId').listen('.LocationUpdated', (e) {
      debugPrint("📍 LocationUpdated diterima untuk SOS #$sosId");
      onDataReceived(e);
    });
  }

  /// Korban mendengarkan pergerakan lokasi relawan secara realtime
  static void listenToRelawanLocation(
    int sosId,
    Function(dynamic) onDataReceived,
  ) {
    if (_pusher == null) {
      debugPrint("❌ listenToRelawanLocation: pusher belum init");
      return;
    }

    final channelName = 'private-sos.$sosId';
    debugPrint("👂 Listening private channel: $channelName");

    final channel = _pusher!.subscribe(channelName);
    channel.bind('RelawanLocationUpdate', (event) {
      debugPrint("📍 RelawanLocationUpdate diterima di $channelName");

      try {
        dynamic payload;
        if (event != null) {
          if (event is Map) {
            final dataStr = event['data'];
            if (dataStr is String) {
              payload = jsonDecode(dataStr);
            } else {
              payload = dataStr ?? event;
            }
          } else {
            payload = event;
          }
        }
        onDataReceived(payload);
      } catch (e) {
        debugPrint(
          "❌ Gagal parsing RelawanLocationUpdate event: $e\nData Asli: $event",
        );
      }
    });
  }

  /// Berhenti mendengarkan lokasi relawan
  static void stopListeningRelawanLocation(int sosId) {
    _pusher?.unsubscribe('private-sos.$sosId');
  }

  /// Berhenti mendengarkan ketika darurat selesai
  static void stopListeningEmergencyLocation(int sosId) {
    echo?.leave('emergency.tracking.$sosId');
  }

  /// Relawan mendengarkan penugasan SOS baru secara realtime
  static void listenToNewSosForVolunteer(
    int volunteerId,
    Function(dynamic) onNewSosReceived,
  ) {
    if (_pusher == null) {
      debugPrint("⚠️ listenToNewSosForVolunteer: pusher belum init");
      return;
    }

    void processEvent(dynamic event, String channel) {
      try {
        if (event == null) return;

        dynamic payload;
        if (event is Map) {
          // Biasanya Pusher mengirim data di dalam key 'data' (berupa JSON string)
          final dataStr = event['data'];
          if (dataStr is String) {
            payload = jsonDecode(dataStr);
          } else {
            payload = dataStr ?? event;
          }
        } else {
          payload = event;
        }

        // Jika event dari Laravel Reverb dibungkus class
        if (payload is Map && payload.containsKey('sos')) {
          payload = payload['sos'];
        }

        onNewSosReceived(payload);
      } catch (e) {
        debugPrint(
          "❌ Gagal parsing event dari $channel: $e\nData Asli: $event",
        );
      }
    }

    // ─── Channel spesifik relawan ───
    final privateChannelName = 'private-relawan.$volunteerId';
    debugPrint("👂 Listening private channel: $privateChannelName");

    final privateChannel = _pusher!.subscribe(privateChannelName);

    privateChannel.bind('SOSCreated', (event) {
      debugPrint("🚨 SOSCreated diterima di $privateChannelName");
      processEvent(event, privateChannelName);
    });

    // ─── Channel umum semua relawan ───
    final publicChannelName = 'private-relawan-channel';
    debugPrint("👂 Listening private channel: $publicChannelName");

    final publicChannel = _pusher!.subscribe(publicChannelName);

    publicChannel.bind('SOSCreated', (event) {
      debugPrint("🚨 SOSCreated diterima di $publicChannelName");
      processEvent(event, publicChannelName);
    });

    publicChannel.bind('SOSUpdateStatus', (event) {
      debugPrint(
        "🔄 SOSUpdateStatus diterima di $publicChannelName - Refreshing Map!",
      );
      // Langsung panggil event bus agar peta ter-refresh detik itu juga (hilangkan marker yang batal)
      GlobalEventBus.refreshMap.value = !GlobalEventBus.refreshMap.value;
    });
  }

  /// Berhenti mendengarkan penugasan SOS baru
  static void stopListeningNewSosForVolunteer(int volunteerId) {
    _pusher?.unsubscribe('private-relawan.$volunteerId');
    _pusher?.unsubscribe('private-relawan-channel');
  }
}
