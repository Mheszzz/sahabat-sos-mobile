import 'package:flutter/material.dart';
import 'package:sahabat_sos_mobile/routing/app_router.dart';

class SahabatSosApp extends StatelessWidget {
  const SahabatSosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Sahabat SOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      routerConfig: AppRouter.router,
    );
  }
}
