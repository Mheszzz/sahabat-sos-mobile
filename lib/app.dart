import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:sahabat_sos_mobile/core/services/accessibility_service.dart';
import 'package:sahabat_sos_mobile/routing/app_router.dart';

class SahabatSosApp extends StatelessWidget {
  const SahabatSosApp({super.key});

  static const Color primaryTeal = Color(0xFF00695C);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AccessibilityService.instance,
      builder: (context, _) {
        final isHighContrast =
            AccessibilityService.instance.isHighContrastEnabled;
        final isLargeText =
            AccessibilityService.instance.isLargeTextEnabled;

        return MaterialApp.router(
          title: 'Sahabat SOS',
          debugShowCheckedModeBanner: false,
          themeMode: isHighContrast ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryTeal,
              primary: primaryTeal,
              surface: const Color(0xFFF8FAFC),
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            splashFactory: NoSplash.splashFactory,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00897B),
              primary: const Color(0xFF00897B),
              surface: Colors.black,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.black,
            splashFactory: NoSplash.splashFactory,
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: <TargetPlatform, PageTransitionsBuilder>{
                TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(isLargeText ? 1.25 : 1.0),
                highContrast: isHighContrast,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          routerConfig: AppRouter.router,
        );
      },
    );
  }
}
