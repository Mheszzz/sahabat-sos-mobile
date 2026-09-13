import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sahabat_sos_mobile/features/auth/presentation/login_page.dart';
import 'package:sahabat_sos_mobile/features/auth/presentation/register_step1_page.dart';
import 'package:sahabat_sos_mobile/features/auth/presentation/register_step2_page.dart';
import 'package:sahabat_sos_mobile/features/main/presentation/main_screen.dart';
import 'package:sahabat_sos_mobile/features/dashboard/presentation/map_page.dart';
import 'package:sahabat_sos_mobile/features/reports/presentation/quick_report_screen.dart';
import 'package:sahabat_sos_mobile/features/sos/presentation/emergency_contacts_page.dart';

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'routes.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      final prefs = GetIt.instance<SharedPreferences>();
      final token = prefs.getString('auth_token');
      final isProfileComplete = prefs.getBool('is_profile_complete') ?? false;
      
      final isLoggingIn = state.matchedLocation == AppRoutes.login;
      final isRegisteringStep1 = state.matchedLocation == AppRoutes.register;
      final isRegisteringStep2 = state.matchedLocation == AppRoutes.registerStep2;
      final isAuthPage = isLoggingIn || isRegisteringStep1 || isRegisteringStep2;

      if (token != null) {
        if (isProfileComplete) {
          // If profile is complete and trying to access auth pages, redirect to dashboard
          if (isAuthPage) {
            return AppRoutes.dashboard;
          }
        } else {
          // If profile is not complete, they MUST go to registerStep2
          if (state.matchedLocation != AppRoutes.registerStep2) {
            return AppRoutes.registerStep2;
          }
        }
      } else {
        // If no token, restrict access to non-auth pages
        if (!isAuthPage && state.matchedLocation != AppRoutes.splash) {
          return AppRoutes.login;
        }
      }
      
      return null;
    },
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
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) {
          final tabIndexStr = state.uri.queryParameters['tab'];
          final int tabIndex = int.tryParse(tabIndexStr ?? '0') ?? 0;
          return MainScreen(initialIndex: tabIndex);
        },
      ),
      GoRoute(
        path: '/map',
        builder: (context, state) => const MapPage(),
      ),
      GoRoute(
        path: AppRoutes.quickReport,
        builder: (context, state) => const QuickReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.emergencyContacts,
        builder: (context, state) => const EmergencyContactsPage(),
      ),
      // TODO: Add more routes here (Home User, Home Relawan, dll)
    ],
  );
}
