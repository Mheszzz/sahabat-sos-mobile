import 'package:laravel_echo/laravel_echo.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:sahabat_sos_mobile/core/constants/api_constants.dart';

class WebsocketService {
  static Echo? echo;

  static Future<void> init(String token) async {
    if (echo != null) return;

    // Ambil IP dari baseUrl (contoh: dari 'http://192.168.1.6:8000/api' menjadi '192.168.1.6')
    final uri = Uri.parse(ApiConstants.baseUrl);
    final host = uri.host;

    PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();
    
    try {
      await pusher.init(
        // TODO: Minta PUSHER_APP_KEY / REVERB_APP_KEY dari tim backend (ada di file .env backend mereka)
        apiKey: 'app-key', 
        cluster: 'mt1',
        useTLS: false, // Karena masih local HTTP
        host: host,
        wsPort: 8080,
        authEndpoint: '${uri.scheme}://${uri.host}:${uri.port}/api/broadcasting/auth', // Atau sesuaikan dengan endpoint auth broadcasting backend
        authParams: {
          'headers': {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          }
        },
        onConnectionStateChange: (currentState, previousState) {
          print("WebSocket Connection: $currentState");
        },
        onError: (message, code, error) {
          print("WebSocket Error: $message");
        },
      );
      
      await pusher.connect();

      echo = Echo(
        broadcaster: EchoBroadcasterType.Pusher,
        client: pusher,
      );
      
      print("Laravel Reverb (WebSocket) Berhasil Terhubung!");
    } catch (e) {
      print("WebSocket Init Error: $e");
    }
  }

  // Fungsi untuk relawan mendengarkan pergerakan lokasi user
  static void listenToEmergencyLocation(int sosId, Function(dynamic) onDataReceived) {
    if (echo == null) {
      print("Websocket belum di-init!");
      return;
    }
    
    // Ganti 'emergency.tracking' sesuai dengan nama channel yang dibuat tim backend
    echo!.channel('emergency.tracking.$sosId')
      .listen('LocationUpdated', (e) { // Ganti 'LocationUpdated' dengan nama Event dari backend
        onDataReceived(e);
      });
  }

  // Berhenti mendengarkan ketika darurat selesai
  static void stopListeningEmergencyLocation(int sosId) {
    echo?.leave('emergency.tracking.$sosId');
  }
}
