import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/volunteer_task/data/datasources/volunteer_remote_data_source.dart';
import '../../features/sos/data/datasources/emergency_contact_remote_data_source.dart';
import '../services/location_service.dart';
import '../../features/tuya_device/data/services/tuya_channel_service.dart';
import '../../features/tuya_device/data/services/emergency_trigger_service.dart';
import '../../features/tuya_device/data/services/tuya_background_listener.dart';
import '../../features/smartwatch/data/services/ble_smartwatch_service.dart';
import '../../features/smartwatch/data/services/huawei_wear_service.dart';
import '../../features/smartwatch/data/services/smartwatch_manager.dart';
import '../../features/smartwatch/data/services/smartwatch_background_listener.dart';

final sl = GetIt.instance;

Future<void> initInjection() async {
  // External
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(
    () => Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    ),
  );

  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<ProfileRemoteDataSource>(
    () => ProfileRemoteDataSourceImpl(prefs: sl()),
  );
  sl.registerLazySingleton<VolunteerRemoteDataSource>(
    () => VolunteerRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );
  sl.registerLazySingleton<EmergencyContactRemoteDataSource>(
    () => EmergencyContactRemoteDataSourceImpl(dio: sl(), prefs: sl()),
  );

  // Services
  sl.registerLazySingleton<LocationService>(
    () => LocationService(dio: sl(), prefs: sl()),
  );

  // Tuya Services
  sl.registerLazySingleton<TuyaChannelService>(() => TuyaChannelService());
  sl.registerLazySingleton<EmergencyTriggerService>(
    () =>
        EmergencyTriggerService(dio: sl(), prefs: sl(), locationService: sl()),
  );
  sl.registerLazySingleton<TuyaBackgroundListener>(
    () => TuyaBackgroundListener(
      tuyaService: sl(),
      emergencyService: sl(),
      prefs: sl(),
    ),
  );

  // Smartwatch Services
  sl.registerLazySingleton<BleSmartwatchService>(() => BleSmartwatchService());
  sl.registerLazySingleton<HuaweiWearService>(() => HuaweiWearService());
  sl.registerLazySingleton<SmartwatchManager>(
    () => SmartwatchManager(
      dio: sl(),
      prefs: sl(),
      bleService: sl(),
      huaweiService: sl(),
      emergencyTriggerService: sl(),
    ),
  );
  sl.registerLazySingleton<SmartwatchBackgroundListener>(
    () => SmartwatchBackgroundListener(
      manager: sl(),
      prefs: sl(),
    ),
  );
}
