import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/screens/d_login_screen.dart';
import '../../features/auth/screens/d_onboarding_screen.dart';
import '../../features/dashboard/screens/d_dashboard_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggingIn = state.uri.path == '/login';
    final isOnboarding = state.uri.path == '/onboarding';

    if (session == null && !isLoggingIn && !isOnboarding) {
      return '/login';
    }

    if (session != null && isLoggingIn) {
      // Assuming user has a profile, check if they finished onboarding.
      // For now we redirect to dashboard.
      // Logic for onboarding redirect can be added here if needed.
      return '/dashboard';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const DLoginScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const DOnboardingScreen(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DDashboardScreen(),
    ),
  ],
);
