import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/model/user_email.dart';
import '../../profile/data/profile_local_repository.dart';

import 'package:heavy_duty/features/profile/model/profile_model.dart';

class AuthProvider with ChangeNotifier {
  static final AuthProvider _instance = AuthProvider._internal();
  factory AuthProvider() => _instance;

  AuthProvider._internal() {
    // Listen to auth changes automatically (e.g., sign in, sign out)
    _currentUser = _supabase.auth.currentUser;
    if (_currentUser != null) {
      _initializeProfileRepo(_currentUser!.id);
    }
    _setupAuthListener();
  }

  final SupabaseClient _supabase = Supabase.instance.client;
  User? _currentUser;
  bool _isLoading = false;
  String? _pendingEmail;
  String? _pendingUsername;

  ProfileLocalRepository? _profileRepo;
  List<UserEmail> _userEmails = [];
  UserProfile? _userProfile;
  bool _isPasswordRecoveryMode = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isEmailVerified => _currentUser?.emailConfirmedAt != null;
  bool get isProfileComplete => _currentUser?.userMetadata?['full_name'] != null;
  bool get isPasswordRecoveryMode => _isPasswordRecoveryMode;
  String? get pendingEmail => _pendingEmail;
  String? get pendingUsername => _pendingUsername;

  String get displayName => _userProfile?.fullName ?? _currentUser?.userMetadata?['full_name'] ?? 'User';
  String get username => _userProfile?.username ?? _currentUser?.userMetadata?['username'] ?? 'username';
  double? get height => _userProfile?.height ?? (_currentUser?.userMetadata?['height'] as num?)?.toDouble();
  String? get gender => _userProfile?.gender ?? _currentUser?.userMetadata?['gender']?.toString();
  DateTime? get birthday => _userProfile?.birthday ?? (_currentUser?.userMetadata?['birthday'] != null ? DateTime.tryParse(_currentUser!.userMetadata!['birthday'].toString()) : null);

  List<UserEmail> get userEmails => _userEmails;
  UserProfile? get userProfile => _userProfile;

  void cancelPasswordRecovery() {
    if (_isPasswordRecoveryMode) {
      _isPasswordRecoveryMode = false;
      notifyListeners();
    }
  }

  void _setupAuthListener() {
    _supabase.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user;
      
      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint("AuthProvider: Password recovery mode ACTIVATED");
        _isPasswordRecoveryMode = true;
      } else if (data.event == AuthChangeEvent.signedOut) {
        _isPasswordRecoveryMode = false;
      }

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
    final List<UserEmail> localEmails = await _profileRepo!.getEmails();

    final Map<String, UserEmail> emailMap = {};
    for (var e in localEmails) {
      emailMap[e.email.toLowerCase()] = e;
    }

    // Always ensure the current primary auth email is in the list
    if (_currentUser?.email != null) {
      final String primaryEmail = _currentUser!.email!.toLowerCase();
      if (!emailMap.containsKey(primaryEmail)) {
        final primary = UserEmail(email: _currentUser!.email!, isVerified: true);
        await _profileRepo!.insertEmail(primary);
        emailMap[primaryEmail] = primary;
      }
    }

    _userEmails = emailMap.values.toList();
    notifyListeners();
  }

  Future<void> refreshEmails() async {
    if (_profileRepo == null || _currentUser == null) return;

    // 1. Refresh Auth User (Check verification status)
    await refreshUser();

    // 2. Sync from Supabase user_emails table
    try {
      final cloudData = await _supabase
          .from('user_emails')
          .select()
          .eq('user_id', _currentUser!.id);

      if (cloudData != null) {
        for (var data in cloudData) {
          final emailObj = UserEmail.fromMap(data);

          // AUTO-SYNC: If this email matches the current auth email and we are verified 
          // in the auth session, update our custom table.
          if (emailObj.email.toLowerCase() == _currentUser!.email?.toLowerCase() && isEmailVerified) {
            if (!emailObj.isVerified) {
              final verifiedObj = emailObj.copyWith(isVerified: true);
              await _profileRepo!.insertEmail(verifiedObj);
              await _supabase.from('user_emails').update({'is_verified': true}).eq('id', emailObj.id);
            }
          } else {
            await _profileRepo!.insertEmail(emailObj);
          }
        }
      }
    } catch (e) {
      debugPrint("AuthProvider: Email sync failed: $e");
    }

    // 3. Reload local list
    await _loadUserEmails();
  }

  Future<void> addEmail(String email) async {
    if (_profileRepo == null) return;

    final normalizedEmail = email.trim().toLowerCase();
    if (_userEmails.any((e) => e.email.toLowerCase() == normalizedEmail)) {
      return;
    }

    // 1. Generate a 6-digit OTP
    final String otp = (100000 + (DateTime.now().millisecond * 899999) ~/ 1000).toString();
    debugPrint("DEBUG: Generated OTP for $normalizedEmail: $otp");

    final newEmail = UserEmail(email: email.trim(), isVerified: false);
    await _profileRepo!.insertEmail(newEmail);

    // 2. Save to the cloud table with the OTP code
    try {
      await _supabase.from('user_emails').insert({
        'id': newEmail.id,
        'user_id': _currentUser!.id,
        'email': newEmail.email,
        'is_verified': false,
        'verification_code': otp, // Ensure this column exists in your DB
      });
    } catch (e) {
      debugPrint("Supabase cloud email insert failed: $e");
    }

    // NOTE: To send the actual email with the code, you should use a 
    // Supabase Edge Function or a DB Trigger. For now, we will 
    // log it to the console for testing.
    
    await _loadUserEmails();
  }

  Future<bool> verifySecondaryEmailOTP(String email, String enteredCode) async {
    _setLoading(true);
    try {
      final response = await _supabase
          .from('user_emails')
          .select('id, verification_code')
          .eq('user_id', _currentUser!.id)
          .eq('email', email)
          .maybeSingle();

      if (response != null && response['verification_code'] == enteredCode) {
        // 1. Update Cloud Status
        await _supabase.from('user_emails').update({'is_verified': true}).eq('id', response['id']);
        
        // 2. Update Local Repository immediately to guarantee UI update
        final currentEmails = await _profileRepo!.getEmails();
        final match = currentEmails.firstWhere((e) => e.email.toLowerCase() == email.toLowerCase());
        await _profileRepo!.insertEmail(match.copyWith(isVerified: true));
        
        // 3. Refresh and reload
        await refreshEmails();
        _setLoading(false);
        return true;
      }
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint("OTP Verification failed: $e");
      _setLoading(false);
      return false;
    }
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
        emailRedirectTo: kIsWeb ? null : 'heavyduty://heavyduty/signup',
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
        debugPrint("AuthProvider: Resolving email for username: $identifier");

        final List<dynamic> response = await _supabase.rpc(
            'get_email_by_username',
            params: {'input_username': identifier}
        );

        if (response.isEmpty) {
          throw "USERNAME NOT FOUND";
        }

        email = response.first['resolved_email'];
        debugPrint("AuthProvider: Resolved to email: $email");
      }

      // 2. Perform Native Supabase Auth
      final response = await _supabase.auth.signInWithPassword(email: email, password: password);

      _currentUser = response.user;
      if (_currentUser != null) {
        _initializeProfileRepo(_currentUser!.id);

        // Ensure email is in profiles table after successful login (Auto-healing)
        _syncEmailToProfile();
      }
      notifyListeners();
    } catch (e) {
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
  }

  /// Internal helper to keep profiles.email column updated
  Future<void> _syncEmailToProfile() async {
    if (_currentUser?.email == null) return;
    try {
      await _supabase.from('profiles').update({'email': _currentUser!.email}).eq('id', _currentUser!.id);
    } catch (e) {
      debugPrint("AuthProvider: Email sync to profile failed: $e");
    }
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
        emailRedirectTo: kIsWeb ? null : (isRecovery ? 'heavyduty://change-password' : 'heavyduty://confirm-email'),
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
      await _supabase.auth.resetPasswordForEmail(
        email, 
        redirectTo: kIsWeb ? null : 'heavyduty://heavyduty/recovery',
      );
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
      final response = await _supabase.auth.verifyOTP(
        email: email,
        token: token,
        type: isRecovery ? OtpType.recovery : OtpType.signup,
      );

      // If this is a new signup verification, ensure the username and email 
      // are propagated to the profiles table for future lookups.
      if (!isRecovery && response.user != null && _pendingUsername != null) {
        debugPrint("AuthProvider: Persisting pending username to profiles table: $_pendingUsername");
        await updateUserProfile(username: _pendingUsername);
      }

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
      _isPasswordRecoveryMode = false;
      notifyListeners();
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
      final String? userEmail = _currentUser!.email;

      // 1. Sync to Supabase Profiles Table (Unified identity management)
      final Map<String, dynamic> profileUpdate = {};
      if (name != null) profileUpdate['full_name'] = name;
      if (username != null) profileUpdate['username'] = username;
      if (height != null) profileUpdate['height'] = height;
      if (userEmail != null) profileUpdate['email'] = userEmail; // Ensure lookup works

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
        isSynced: 0,
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
