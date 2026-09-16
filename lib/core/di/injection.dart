import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../services/location_service.dart';
import '../../features/tuya_device/data/services/tuya_channel_service.dart';
import '../../features/tuya_device/data/services/emergency_trigger_service.dart';
import '../../features/tuya_device/data/services/tuya_background_listener.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 60),
  )));

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(prefs: sl()),
  );

  // Services
  sl.registerLazySingleton<LocationService>(
    () => LocationService(dio: sl(), prefs: sl()),
  );

  // Tuya Services
  sl.registerLazySingleton<TuyaChannelService>(
    () => TuyaChannelService(),
  );
  sl.registerLazySingleton<EmergencyTriggerService>(
    () => EmergencyTriggerService(
      dio: sl(),
      prefs: sl(),
      locationService: sl(),
    ),
  );
  sl.registerLazySingleton<TuyaBackgroundListener>(
    () => TuyaBackgroundListener(
      tuyaService: sl(),
      emergencyService: sl(),
      prefs: sl(),
    ),
  );
}
