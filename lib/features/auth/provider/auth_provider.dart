import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/model/user_email.dart';
import '../../profile/data/profile_local_repository.dart';

import 'package:heavy_duty/features/profile/model/profile_model.dart';

class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  User? _currentUser;
  bool _isLoading = false;
  String? _pendingEmail;
  String? _pendingUsername;
  
  ProfileLocalRepository? _profileRepo;
  List<UserEmail> _userEmails = [];
  UserProfile? _userProfile;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailConfirmedAt != null;
  bool get isProfileComplete => _currentUser?.userMetadata?['full_name'] != null;
  String? get pendingEmail => _pendingEmail;
  String? get pendingUsername => _pendingUsername;

  String get displayName => _userProfile?.fullName ?? _currentUser?.userMetadata?['full_name'] ?? 'User';
  String get username => _userProfile?.username ?? _currentUser?.userMetadata?['username'] ?? 'username';
  double? get height => _userProfile?.height ?? (_currentUser?.userMetadata?['height'] as num?)?.toDouble();
  
  List<UserEmail> get userEmails => _userEmails;
  UserProfile? get userProfile => _userProfile;

  AuthProvider() {
    // Listen to auth changes automatically (e.g., sign in, sign out)
    _currentUser = _supabase.auth.currentUser;
    if (_currentUser != null) {
      _initializeProfileRepo(_currentUser!.id);
    }
    _supabase.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      if (_currentUser != null) {
        _initializeProfileRepo(_currentUser!.id);
      } else {
        _profileRepo = null;
        _userEmails = [];
      }
      notifyListeners();
    });
  }

  void _initializeProfileRepo(String userId) async {
    _profileRepo = ProfileLocalRepository(userId: userId);
    _loadUserEmails();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    if (_profileRepo == null) return;
    
    // 1. Load Local
    _userProfile = await _profileRepo!.getProfile();
    
    // 2. Load from Supabase Profiles Table
    try {
      final cloudData = await _supabase.from('profiles').select().eq('id', _currentUser!.id).maybeSingle();
      if (cloudData != null) {
        _userProfile = UserProfile.fromMap(cloudData);
        await _profileRepo!.saveProfile(_userProfile!);
      }
    } catch (e) {
      debugPrint("Cloud profile load failed: $e");
    }
    notifyListeners();
  }

  Future<void> _loadUserEmails() async {
    if (_profileRepo == null) return;
    _userEmails = await _profileRepo!.getEmails();
    
    // Add primary email if list is empty
    if (_userEmails.isEmpty && _currentUser?.email != null) {
      final primary = UserEmail(email: _currentUser!.email!, isVerified: true);
      await _profileRepo!.insertEmail(primary);
      _userEmails = [primary];
    }
    notifyListeners();
  }

  Future<void> addEmail(String email) async {
    if (_profileRepo == null) return;
    final newEmail = UserEmail(email: email, isVerified: false);
    await _profileRepo!.insertEmail(newEmail);
    
    // MOCK: Save to Supabase (assuming a 'user_emails' table exists or using metadata)
    try {
      await _supabase.from('user_emails').insert({
        'id': newEmail.id,
        'user_id': _currentUser!.id,
        'email': email,
        'is_verified': false,
      });
    } catch (e) {
      debugPrint("Supabase email save failed: $e");
    }
    
    await _loadUserEmails();
  }

  Future<void> removeEmail(String id) async {
    if (_profileRepo == null || _userEmails.length <= 1) return;
    await _profileRepo!.deleteEmail(id);
    
    try {
      await _supabase.from('user_emails').delete().eq('id', id);
    } catch (e) {
      debugPrint("Supabase email delete failed: $e");
    }
    
    await _loadUserEmails();
  }

  Future<void> verifyEmail(String id) async {
    if (_profileRepo == null) return;
    final email = _userEmails.firstWhere((e) => e.id == id);
    final updated = email.copyWith(isVerified: true);
    await _profileRepo!.updateEmail(updated);
    
    try {
      await _supabase.from('user_emails').update({'is_verified': true}).eq('id', id);
    } catch (e) {
      debugPrint("Supabase email verify failed: $e");
    }
    
    await _loadUserEmails();
  }

  // ==========================================
  // USERNAME MANAGEMENT
  // ==========================================
  Future<bool> checkUsernameAvailability(String username) async {
    if (username.isEmpty) return false;
    
    _setLoading(true);
    try {
      // Logic: Search for any user with this username in metadata or a profiles table
      // This is a common pattern with Supabase auth
      final response = await _supabase
          .from('profiles') // Assuming a public 'profiles' table exists
          .select('username')
          .eq('username', username)
          .maybeSingle();
      
      _setLoading(false);
      return response == null; // Available if no record found
    } catch (e) {
      debugPrint("Username check failed: $e. Falling back to optimistic True.");
      _setLoading(false);
      return true; // Fallback
    }
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
  Future<void> signIn(String identifier, String password) async {
    _setLoading(true);
    try {
      String email = identifier;

      // 1. Resolve Username to Email if necessary
      if (!identifier.contains('@')) {
        final profile = await _supabase
            .from('profiles')
            .select('email')
            .eq('username', identifier)
            .maybeSingle();
        
        if (profile == null) throw "USERNAME NOT FOUND";
        email = profile['email'];
      }

      // 2. Perform Native Supabase Auth
      final response = await _supabase.auth.signInWithPassword(email: email, password: password);
      
      _currentUser = response.user;
      if (_currentUser != null) {
        _initializeProfileRepo(_currentUser!.id);
      }
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
  // PASSWORD RECOVERY / CHANGE
  // ==========================================
  Future<bool> verifyCurrentPassword(String password) async {
    final email = _currentUser?.email;
    if (email == null) return false;
    
    _setLoading(true);
    try {
      // Attempt to sign in again with current email and the provided password to verify it
      await _supabase.auth.signInWithPassword(email: email, password: password);
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      return false;
    }
  }

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

  Future<void> updateUserProfile({String? name, String? username, double? height, Map<String, dynamic>? extraMetadata}) async {
    _setLoading(true);
    try {
      final String userId = _currentUser!.id;
      
      // 1. Sync to Supabase Profiles Table (Unified identity management)
      final Map<String, dynamic> profileUpdate = {};
      if (name != null) profileUpdate['full_name'] = name;
      if (username != null) profileUpdate['username'] = username;
      if (height != null) profileUpdate['height'] = height;
      if (extraMetadata != null) {
        if (extraMetadata['birthday'] != null) profileUpdate['birthday'] = extraMetadata['birthday'];
        if (extraMetadata['gender'] != null) profileUpdate['gender'] = extraMetadata['gender'];
        if (extraMetadata['weight'] != null) profileUpdate['weight'] = extraMetadata['weight'];
      }
      
      await _supabase.from('profiles').upsert({'id': userId, ...profileUpdate});

      // 2. Sync to Local SQLite
      final currentLocal = await _profileRepo?.getProfile();
      final updatedLocal = UserProfile(
        id: userId,
        fullName: name ?? currentLocal?.fullName,
        username: username ?? currentLocal?.username,
        height: height ?? currentLocal?.height,
        weight: extraMetadata?['weight'] ?? currentLocal?.weight,
        gender: extraMetadata?['gender'] ?? currentLocal?.gender,
        birthday: extraMetadata?['birthday'] != null ? DateTime.tryParse(extraMetadata!['birthday']) : currentLocal?.birthday,
        email: _currentUser?.email,
      );
      await _profileRepo?.saveProfile(updatedLocal);
      _userProfile = updatedLocal;

      // 3. Fallback sync to Auth Metadata (Legacy support)
      await _supabase.auth.updateUser(UserAttributes(data: profileUpdate));
      
      notifyListeners();
    } catch (e) {
      debugPrint("Profile update failed: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
