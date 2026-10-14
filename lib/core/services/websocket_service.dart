import 'package:sahabat_sos_mobile/core/utils/global_event_bus.dart';
import 'package:sahabat_sos_mobile/core/services/notification_service.dart';
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
        key: '17f3f162540b4a538b928863a3b5d1aa8795f05a7d2adeaa0b2f24bc070324cc',
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

  /// Korban mendengarkan perubahan status SOS secara realtime
  static void listenToSosStatusUpdate(
    int sosId,
    Function(dynamic) onStatusReceived,
  ) {
    if (_pusher == null) {
      debugPrint("❌ listenToSosStatusUpdate: pusher belum init");
      return;
    }

    final channelName = 'private-sos.$sosId';
    debugPrint("👂 Listening private channel status: $channelName");

    final channel = _pusher!.subscribe(channelName);
    channel.bind('SOSUpdateStatus', (event) {
      debugPrint("🔄 SOSUpdateStatus diterima di $channelName");

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
        if (payload is Map && payload.containsKey('sos')) {
          payload = payload['sos'];
        }
        onStatusReceived(payload);
      } catch (e) {
        debugPrint(
          "❌ Gagal parsing SOSUpdateStatus event: $e\nData Asli: $event",
        );
      }
    });
  }

  /// Berhenti mendengarkan status SOS
  static void stopListeningSosStatusUpdate(int sosId) {
    _pusher?.unsubscribe('private-sos.$sosId');
  }

  /// Berhenti mendengarkan lokasi relawan
  static void stopListeningRelawanLocation(int sosId) {
    _pusher?.unsubscribe('private-sos.$sosId');
  }

  /// Berhenti mendengarkan ketika darurat selesai
  static void stopListeningEmergencyLocation(int sosId) {
    echo?.leave('emergency.tracking.$sosId');
  }

  static final Set<int> _recentlyNotifiedSosIds = {};

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
          final sosData = payload['sos'] is Map
              ? Map<String, dynamic>.from(payload['sos'])
              : <String, dynamic>{};
          payload.forEach((key, value) {
            if (key != 'sos') {
              sosData[key] = value;
            }
          });
          payload = sosData;
        }

        if (payload is Map) {
          final payloadMap = Map<String, dynamic>.from(payload);
          final dynamic rawId = payloadMap['id'];
          final int sosId =
              (rawId is int) ? rawId : int.tryParse(rawId?.toString() ?? '0') ?? 0;

          if (sosId > 0) {
            if (_recentlyNotifiedSosIds.contains(sosId)) {
              debugPrint("ℹ️ SOS #$sosId sudah dinotifikasikan baru-baru ini dari channel lain.");
              return;
            }
            _recentlyNotifiedSosIds.add(sosId);
            Future.delayed(const Duration(seconds: 15), () {
              _recentlyNotifiedSosIds.remove(sosId);
            });
          }

          // 1. Tampilkan Heads-up Notification lokal di HP relawan
          NotificationService().showEmergencyNotification(payloadMap);

          // 2. Kirim sinyal ke GlobalEventBus agar dialog NewAssignment muncul di mana saja
          GlobalEventBus.showSosAssignmentPopup.value = payloadMap;
        }

        onNewSosReceived(payload);
      } catch (e) {
        debugPrint(
          "❌ Gagal parsing event dari $channel: $e\nData Asli: $event",
        );
      }
    }

    void setupChannelBindings(Channel channel, String channelName) {
      void onSosCreated(dynamic event) {
        debugPrint("🚨 SOSCreated diterima di $channelName");
        processEvent(event, channelName);
        GlobalEventBus.refreshMap.value = !GlobalEventBus.refreshMap.value;
      }

      channel.bind('SOSCreated', onSosCreated);
      channel.bind('.SOSCreated', onSosCreated);
      channel.bind('App\\Events\\SOSCreated', onSosCreated);

      void onSosUpdated(dynamic event) {
        debugPrint("🔄 SOSUpdateStatus diterima di $channelName - Refreshing Map!");
        GlobalEventBus.refreshMap.value = !GlobalEventBus.refreshMap.value;
      }

      channel.bind('SOSUpdateStatus', onSosUpdated);
      channel.bind('.SOSUpdateStatus', onSosUpdated);
      channel.bind('App\\Events\\SOSUpdateStatus', onSosUpdated);

      // Wildcard listener untuk keamanan ekstra
      channel.bind('*', (eventData) {
        if (eventData is Map) {
          final eventName = eventData['event']?.toString() ?? '';
          final data = eventData['data'];
          if (eventName.contains('SOSCreated')) {
            debugPrint("🚨 Wildcard match [$eventName] di $channelName");
            processEvent(data, channelName);
            GlobalEventBus.refreshMap.value = !GlobalEventBus.refreshMap.value;
          } else if (eventName.contains('SOSUpdateStatus')) {
            debugPrint("🔄 Wildcard match [$eventName] di $channelName - Refreshing Map!");
            GlobalEventBus.refreshMap.value = !GlobalEventBus.refreshMap.value;
          }
        }
      });
    }

    // ─── 1. Channel spesifik relawan (jika ID tersedia) ───
    if (volunteerId > 0) {
      final privateChannelName = 'private-relawan.$volunteerId';
      debugPrint("👂 Listening private channel: $privateChannelName");
      final privateChannel = _pusher!.subscribe(privateChannelName);
      setupChannelBindings(privateChannel, privateChannelName);
    }

    // ─── 2. Channel umum semua relawan ───
    final publicChannelName = 'private-relawan-channel';
    debugPrint("👂 Listening private broadcast channel: $publicChannelName");
    final publicChannel = _pusher!.subscribe(publicChannelName);
    setupChannelBindings(publicChannel, publicChannelName);
  }

  /// Berhenti mendengarkan penugasan SOS baru
  static void stopListeningNewSosForVolunteer(int volunteerId) {
    if (volunteerId > 0) {
      _pusher?.unsubscribe('private-relawan.$volunteerId');
    }
    _pusher?.unsubscribe('private-relawan-channel');
  }
}
