import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_service.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  static Future<AuthResponse> signUpOrLogin(
    String email,
    String password,
  ) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      // First try to sign in
      final res = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      // If success, check profile
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', res.user!.id)
          .maybeSingle();
      if (profile != null) {
        await SessionService.saveRole(profile['role']);
      }
      return res;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        AuthResponse res;
        try {
          // Try to sign up only after login fails. Supabase rejects duplicate
          // confirmed emails, which keeps the combined Login / Sign Up flow.
          res = await _client.auth.signUp(
            email: cleanEmail,
            password: password,
          );
        } on AuthException catch (signUpError) {
          final message = signUpError.message.toLowerCase();
          if (message.contains('already') || message.contains('registered')) {
            throw Exception(
              'An account with this email already exists. Please sign in with the correct password.',
            );
          }
          rethrow;
        }

        final identities = res.user?.identities ?? [];
        if (res.user != null && identities.isEmpty) {
          throw Exception(
            'An account with this email already exists. Please sign in with the correct password.',
          );
        }

        if (res.user != null) {
          // Create or update profile record. Include `id = auth.uid()` so
          // RLS policies that require new.id = auth.uid() will pass.
          try {
            await _client.from('profiles').upsert(
              {
                'id': res.user!.id,
                'role': 'driver',
                'is_active': true,
              }, // returning minimal to avoid extra data
            );
            await SessionService.saveRole('driver');
          } catch (e) {
            // Surface a clearer message so the UI can explain RLS failures.
            throw Exception(
              'Failed to create profile: ${e.toString()} (possible RLS policy). Run the provided SQL migration to add compatible policies.',
            );
          }
        }
        return res;
      }
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await _client.auth.signOut();
    await SessionService.clear();
  }
}
