import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/app.dart';
import 'package:sahabat_sos_mobile/core/di/injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Dependency Injection (GetIt)
  await initInjection();
  
  runApp(const SahabatSosApp());
}
