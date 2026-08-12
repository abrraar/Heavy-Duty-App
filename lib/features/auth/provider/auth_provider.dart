import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _currentUser;
  bool _isLoading = false;
  String? _pendingEmail;
  String? _pendingUsername;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailConfirmedAt != null;
  bool get isProfileComplete => _currentUser?.userMetadata?['full_name'] != null;
  String? get pendingEmail => _pendingEmail;
  String? get pendingUsername => _pendingUsername;

  String get displayName => _currentUser?.userMetadata?['full_name'] ?? 'User';
  String get username => _currentUser?.userMetadata?['username'] ?? 'username';
  double? get height => (_currentUser?.userMetadata?['height'] as num?)?.toDouble();

  AuthProvider() {
    // Listen to auth changes automatically (e.g., sign in, sign out)
    _currentUser = _supabase.auth.currentUser;
    _supabase.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      notifyListeners();
    });
  }

  // ==========================================
  // SIGN UP METHOD
  // ==========================================
  Future<void> signUp(String email, String password, {String? username}) async {
    _setLoading(true);
    _pendingEmail = email;
    _pendingUsername = username;
    try {
      await _supabase.auth.signUp(
        email: email,
        password: password,
        data: username != null ? {'username': username} : null,
      );
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // ==========================================
  // SIGN IN METHOD
  // ==========================================
  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      final response = await _supabase.auth.signInWithPassword(email: email, password: password);
      // Update user immediately for instant UI reaction
      _currentUser = response.user;
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  Future<void> refreshUser() async {
    try {
      final response = await _supabase.auth.refreshSession();
      _currentUser = response.user;
      notifyListeners();
    } catch (e) {
      debugPrint("Error refreshing user: $e");
    }
  }

  // ==========================================
  // SIGN OUT METHOD
  // ==========================================
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _supabase.auth.signOut();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resendOTP(String email, {bool isRecovery = false}) async {
    _setLoading(true);
    try {
      await _supabase.auth.resend(
        type: isRecovery ? OtpType.recovery : OtpType.signup,
        email: email,
      );
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // ==========================================
  // PASSWORD RECOVERY: SEND RESET OTP/LINK
  // ==========================================
  Future<void> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // ==========================================
  // PASSWORD RECOVERY / SIGNUP: VERIFY OTP TOKENS
  // ==========================================
  Future<void> verifyOTPCode(String email, String token, {bool isRecovery = false}) async {
    _setLoading(true);
    try {
      await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: isRecovery ? OtpType.recovery : OtpType.signup,
      );
      
      _pendingEmail = null;
      _pendingUsername = null;
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  // ==========================================
  // PASSWORD RECOVERY: UPDATE TO NEW PASSWORD
  // ==========================================
  Future<void> updateUserPassword(String newPassword) async {
    _setLoading(true);
    try {
      await _supabase.auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  Future<void> updateUserProfile({String? name, String? username, double? height}) async {
    _setLoading(true);
    try {
      final Map<String, dynamic> data = Map.from(_currentUser?.userMetadata ?? {});
      if (name != null) data['full_name'] = name;
      if (username != null) data['username'] = username;
      if (height != null) data['height'] = height;

      await _supabase.auth.updateUser(UserAttributes(data: data));
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
