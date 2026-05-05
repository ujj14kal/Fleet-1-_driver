import 'package:supabase_flutter/supabase_flutter.dart';
import 'session_service.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  static Future<AuthResponse> signUpOrLogin(String email, String password) async {
    try {
      // First try to sign in
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      // If success, check profile
      final profile = await _client.from('profiles').select().eq('id', res.user!.id).maybeSingle();
      if (profile != null) {
        await SessionService.saveRole(profile['role']);
      }
      return res;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        // Try to sign up if login fails (for demonstration/simplicity)
        final res = await _client.auth.signUp(email: email, password: password);
        if (res.user != null) {
          // Create profile record
          await _client.from('profiles').upsert({
            'id': res.user!.id,
            'role': 'driver',
            'is_active': true,
          });
          await SessionService.saveRole('driver');
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
