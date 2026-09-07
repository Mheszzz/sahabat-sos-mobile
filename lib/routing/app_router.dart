import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/features/auth/presentation/login_page.dart';
import 'package:sahabat_sos_mobile/features/auth/presentation/register_step1_page.dart';
import 'package:sahabat_sos_mobile/features/auth/presentation/register_step2_page.dart';

import 'routes.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text('Sahabat SOS Mobile - Splash Screen'),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterStep1Page(),
      ),
      GoRoute(
        path: AppRoutes.registerStep2,
        builder: (context, state) => const RegisterStep2Page(),
      ),
      // TODO: Add more routes here (Home User, Home Relawan, dll)
    ],
  );
}
