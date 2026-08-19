import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/model/user_email.dart';
import '../../profile/data/profile_local_repository.dart';

import 'package:heavy_duty/features/profile/model/profile_model.dart';

class AuthProvider with ChangeNotifier {
  static final AuthProvider _instance = AuthProvider._internal();
  factory AuthProvider() => _instance;

  AuthProvider._internal() {
    _initRecoveryState();
    // Listen to auth changes automatically (e.g., sign in, sign out)
    _currentUser = _supabase.auth.currentUser;
    if (_currentUser != null) {
      _initializeProfileRepo(_currentUser!.id);
    }
    _setupAuthListener();
  }

  Future<void> _initRecoveryState() async {
    final prefs = await SharedPreferences.getInstance();
    final bool wasInRecovery = prefs.getBool('is_in_recovery_lockdown') ?? false;
    
    if (wasInRecovery) {
      debugPrint("AuthProvider: Unfinished Recovery Session detected on app start. Wiping for security.");
      // Security Invalidation: If the user killed the app during reset, log them out 
      // and clear the flag to ensure they start fresh at the Login screen.
      await signOut();
    }
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
    _supabase.auth.onAuthStateChange.listen((data) async {
      _currentUser = data.session?.user;
      
      if (data.event == AuthChangeEvent.passwordRecovery) {
        debugPrint("AuthProvider: Password recovery mode ACTIVATED");
        _isPasswordRecoveryMode = true;
        
        // PERSISTENCE FIX: Save recovery status to local storage so it survives app restarts
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_in_recovery_lockdown', true);
      } else if (data.event == AuthChangeEvent.signedOut) {
        _isPasswordRecoveryMode = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('is_in_recovery_lockdown');
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

    // Ensure primary email is always first in the list
    final List<UserEmail> sortedList = emailMap.values.toList();
    sortedList.sort((a, b) {
      final bool aIsPrimary = a.email.toLowerCase() == _currentUser?.email?.toLowerCase();
      final bool bIsPrimary = b.email.toLowerCase() == _currentUser?.email?.toLowerCase();
      if (aIsPrimary) return -1;
      if (bIsPrimary) return 1;
      return 0;
    });

    _userEmails = sortedList;
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
        // ELITE SYNC: To ensure deleted items are removed, we perform a clean sync.
        // We will collect the cloud IDs and remove any local records not present in the cloud.
        final List<UserEmail> cloudEmails = cloudData.map((d) => UserEmail.fromMap(d)).toList();
        final cloudIds = cloudEmails.map((e) => e.id).toSet();
        
        final localEmails = await _profileRepo!.getEmails();
        
        // Remove locals that aren't in cloud (except perhaps the primary if handled differently)
        for (var local in localEmails) {
          if (!cloudIds.contains(local.id)) {
            // If it's not the primary auth email, delete it locally as it's gone from cloud
            if (local.email.toLowerCase() != _currentUser!.email?.toLowerCase()) {
              await _profileRepo!.deleteEmail(local.id);
            }
          }
        }

        // Upsert cloud records into local
        for (var emailObj in cloudEmails) {
          // AUTO-SYNC: If this email matches the current auth email and we are verified 
          // in the auth session, update our custom table.
          if (emailObj.email.toLowerCase() == _currentUser!.email?.toLowerCase() && isEmailVerified) {
            if (!emailObj.isVerified) {
              final verifiedObj = emailObj.copyWith(isVerified: true);
              await _profileRepo!.insertEmail(verifiedObj);
              await _supabase.from('user_emails').update({'is_verified': true}).eq('id', emailObj.id);
            } else {
              await _profileRepo!.insertEmail(emailObj);
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
    
    // ENFORCE LIMIT: Max 3 emails
    if (_userEmails.length >= 3) {
      throw "MAXIMUM EMAIL LIMIT REACHED (3)";
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (_userEmails.any((e) => e.email.toLowerCase() == normalizedEmail)) {
      return;
    }

    // 1. Generate a 6-digit OTP
    final String otp = (100000 + (DateTime.now().millisecond * 899999) ~/ 1000).toString();
    debugPrint("DEBUG: Generated OTP for $normalizedEmail: $otp");

    final newEmail = UserEmail(email: email.trim(), isVerified: false);
    await _profileRepo!.insertEmail(newEmail);

    // 2. Save to the cloud table for persistence
    try {
      await _supabase.from('user_emails').insert({
        'id': newEmail.id,
        'user_id': _currentUser!.id,
        'email': newEmail.email,
        'is_verified': false,
        'verification_code': otp,
      });
    } catch (e) {
      debugPrint("Supabase local record save failed: $e");
    }

    // 3. DIRECT INVOCATION: Trigger the email sender immediately
    // This allows us to catch errors and confirm the send-request was successful
    try {
      debugPrint("AuthProvider: Invoking Edge Function 'secondary-email-otp'...");
      final response = await _supabase.functions.invoke(
        'secondary-email-otp', 
        body: {'email': email.trim(), 'otp': otp}
      );
      debugPrint("AuthProvider: Edge Function Response Status: ${response.status}");
    } catch (e) {
      debugPrint("AuthProvider: DIRECT Edge Function trigger failed: $e");
    }
    
    await _loadUserEmails();
  }

  Future<void> resendSecondaryOTP(String email) async {
    _setLoading(true);
    try {
      // 1. Generate new OTP
      final String otp = (100000 + (DateTime.now().millisecond * 899999) ~/ 1000).toString();
      
      // 2. Update code in database
      await _supabase.from('user_emails').update({'verification_code': otp}).eq('email', email.trim());
      
      // 3. Trigger Email
      await _supabase.functions.invoke('secondary-email-otp', body: {'email': email.trim(), 'otp': otp});
      
      debugPrint("AuthProvider: OTP Resent to $email: $otp");
    } catch (e) {
      debugPrint("AuthProvider: Resend failed: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifySecondaryEmailOTP(String email, String enteredCode) async {
    _setLoading(true);
    debugPrint("AuthProvider: Attempting to verify OTP for $email");
    try {
      final response = await _supabase
          .from('user_emails')
          .select('id, verification_code')
          .eq('user_id', _currentUser!.id)
          .eq('email', email.trim())
          .maybeSingle();

      if (response != null && response['verification_code'] == enteredCode) {
        debugPrint("AuthProvider: OTP Match found. Updating Supabase...");
        
        // 1. Update Cloud Status (Use select() to verify it actually happened)
        final updateResult = await _supabase
            .from('user_emails')
            .update({'is_verified': true})
            .eq('id', response['id'])
            .select();
        
        debugPrint("AuthProvider: Supabase Update Result: $updateResult");

        if (updateResult.isNotEmpty) {
          // 2. Update Local Repository immediately
          final currentEmails = await _profileRepo!.getEmails();
          final match = currentEmails.firstWhere((e) => e.email.toLowerCase() == email.trim().toLowerCase());
          await _profileRepo!.insertEmail(match.copyWith(isVerified: true));
          
          debugPrint("AuthProvider: Local Update Successful. Refreshing...");
          
          // 3. Refresh and reload to ensure UI is in sync
          await refreshEmails();
          _setLoading(false);
          return true;
        } else {
          debugPrint("AuthProvider: Supabase Update failed (no rows affected)");
        }
      } else {
        debugPrint("AuthProvider: OTP Mismatch or record not found. Expected: ${response?['verification_code']}, Entered: $enteredCode");
      }
      _setLoading(false);
      return false;
    } catch (e) {
      debugPrint("AuthProvider: OTP Verification ERROR: $e");
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

  Future<void> promoteToPrimaryEmail(String newEmail) async {
    _setLoading(true);
    try {
      // This triggers Supabase's secure email change flow.
      // Confirmation links will be sent to both old and new addresses.
      await _supabase.auth.updateUser(
        UserAttributes(email: newEmail.trim()),
        emailRedirectTo: kIsWeb ? null : 'heavyduty://heavyduty/email_change',
      );
    } catch (e) {
      debugPrint("Promotion failed: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
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

  Future<void> sendPasswordResetEmail(String email, {String? source}) async {
    _setLoading(true);
    debugPrint("AuthProvider: Checking if email $email is registered before reset...");
    try {
      // 1. Verify the email exists in our records (Primary Email check)
      final response = await _supabase
          .from('profiles')
          .select('email')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();

      if (response == null) {
        debugPrint("AuthProvider: RESET REJECTED. Email $email not found in profiles.");
        throw "THIS EMAIL IS NOT REGISTERED AS A PRIMARY ACCOUNT";
      }

      debugPrint("AuthProvider: Email verified. Sending reset link with source: $source...");

      // 2. Proceed with Supabase Reset
      // We append the source parameter to the redirectTo URL
      final String redirectUrl = source != null 
          ? 'heavyduty://heavyduty/recovery?source=$source'
          : 'heavyduty://heavyduty/recovery';

      await _supabase.auth.resetPasswordForEmail(
        email.trim(), 
        redirectTo: kIsWeb ? null : redirectUrl,
      );
    } catch (e) {
      debugPrint("AuthProvider: Password reset request failed: $e");
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
