import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_routes.dart';

class ManageEmailScreen extends StatefulWidget {
  const ManageEmailScreen({super.key});

  @override
  State<ManageEmailScreen> createState() => _ManageEmailScreenState();
}

class _ManageEmailScreenState extends State<ManageEmailScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isSending = false;
  bool _isVerifying = false;
  String? _pendingEmail;

  @override
  void initState() {
    super.initState();
    // Auto-refresh when entering the screen to catch any verification updates from deep links
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProv = context.read<AuthProvider>();
      
      // Check if we arrived via a verification deep link (passed as query param in router)
      final state = GoRouterState.of(context);
      final bool wasVerified = state.uri.queryParameters['verified'] == 'true';
      final String? verifiedEmail = state.uri.queryParameters['email'];

      if (wasVerified) {
        await authProv.refreshEmails();
        if (mounted) {
          final message = state.uri.queryParameters['message'];
          if (message != null && message.isNotEmpty) {
            EliteSnackbar.show(context, message.toUpperCase());
          } else if (verifiedEmail != null) {
            EliteSnackbar.show(context, 'EMAIL "$verifiedEmail" VERIFIED');
          } else {
            final String currentEmail = authProv.currentUser?.email ?? "";
            EliteSnackbar.show(context, 'EMAIL "$currentEmail" VERIFIED');
          }
        }
      } else {
        // Just a standard entry, sync quietly
        authProv.refreshEmails();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showAddEmailSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 20.h,
            left: 24.r,
            right: 24.r,
            top: 24.r,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 20.h),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Text(_pendingEmail == null ? "ADD EMAIL ADDRESS" : "VERIFY CODE", style: AppTextStyles.h3),
              SizedBox(height: 8.h),
              Text(
                _pendingEmail == null 
                  ? "A 6-DIGIT VERIFICATION CODE WILL BE SENT" 
                  : "ENTER THE CODE SENT TO ${_pendingEmail!.toUpperCase()}", 
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)
              ),
              SizedBox(height: 24.h),
              
              if (_pendingEmail == null) 
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !_isSending,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "EMAIL ADDRESS",
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: AppColors.surfaceLight.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                  ),
                )
              else
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !_isVerifying,
                  style: AppTextStyles.h2.copyWith(color: Colors.white, letterSpacing: 10),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    counterText: "",
                    hintText: "000000",
                    hintStyle: const TextStyle(color: Colors.white12),
                    filled: true,
                    fillColor: AppColors.surfaceLight.withOpacity(0.3),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                  ),
                ),
                
              SizedBox(height: 24.h),
              _PrimaryButton(
                label: _pendingEmail == null ? "SEND VERIFICATION CODE" : "VERIFY & ADD EMAIL",
                isLoading: _isSending || _isVerifying,
                onTap: () async {
                  if (_pendingEmail == null) {
                    final email = _emailController.text.trim();
                    if (email.isNotEmpty) {
                      setSheetState(() => _isSending = true);
                      try {
                        await context.read<AuthProvider>().addEmail(email);
                        setSheetState(() {
                          _pendingEmail = email;
                          _isSending = false;
                        });
                      } catch (e) {
                        if (mounted) EliteSnackbar.show(context, "FAILED: ${e.toString().toUpperCase()}", isError: true);
                        setSheetState(() => _isSending = false);
                      }
                    }
                  } else {
                    final code = _otpController.text.trim();
                    if (code.length == 6) {
                      setSheetState(() => _isVerifying = true);
                      final success = await context.read<AuthProvider>().verifySecondaryEmailOTP(_pendingEmail!, code);
                      if (success && mounted) {
                        Navigator.pop(context);
                        _resetState();
                        EliteSnackbar.show(context, "EMAIL VERIFIED SUCCESSFULLY");
                      } else if (mounted) {
                        EliteSnackbar.show(context, "INVALID CODE", isError: true);
                        setSheetState(() => _isVerifying = false);
                      }
                    }
                  }
                },
              ),
              if (_pendingEmail != null) ...[
                Center(
                  child: TextButton(
                    onPressed: (_isSending || _isVerifying) ? null : () async {
                      setSheetState(() => _isSending = true);
                      try {
                        await context.read<AuthProvider>().resendSecondaryOTP(_pendingEmail!);
                        EliteSnackbar.show(context, "FRESH CODE SENT");
                      } catch (e) {
                        EliteSnackbar.show(context, "RESEND FAILED", isError: true);
                      } finally {
                        setSheetState(() => _isSending = false);
                      }
                    },
                    child: Text(
                      _isSending ? "SENDING..." : "RESEND VERIFICATION CODE", 
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, decoration: TextDecoration.underline)
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: () => setSheetState(() => _pendingEmail = null),
                    child: Text("RE-TYPE EMAIL", style: AppTextStyles.labelSmall.copyWith(color: Colors.white24, decoration: TextDecoration.underline)),
                  ),
                ),
              ],
              SizedBox(height: 12.h),
            ],
          ),
        ),
      ),
    ).then((_) => _resetState());
  }

  void _resetState() {
    if (mounted) {
      setState(() {
        _emailController.clear();
        _otpController.clear();
        _pendingEmail = null;
        _isSending = false;
        _isVerifying = false;
      });
    }
  }

  Future<bool> _confirmDelete(String id, String email) async {
    final confirmed = await EliteConfirmDialog.show(
      context,
      title: "REMOVE EMAIL",
      message: "ARE YOU SURE YOU WANT TO REMOVE $email?",
      confirmText: "REMOVE",
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().removeEmail(id);
      EliteSnackbar.show(context, "EMAIL REMOVED");
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final emails = authProv.userEmails;
    final canDelete = emails.length > 1;
    final bool limitReached = emails.length >= 5;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
        child: Column(
          children: [
            const EliteSettingsAppBar(title: "MANAGE EMAILS"),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => authProv.refreshEmails(),
                color: AppColors.crimson,
                backgroundColor: AppColors.surface,
                child: ListView.builder(
                  padding: EdgeInsets.all(24.r),
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  itemCount: emails.length,
                  itemBuilder: (context, index) {
                    final email = emails[index];
                    final bool isPrimary = email.email == authProv.currentUser?.email;

                    return Dismissible(
                      key: Key(email.id),
                      // Slide Right (Start to End) to Verify | Slide Left (End to Start) to Delete
                      direction: isPrimary ? DismissDirection.none : DismissDirection.horizontal,
                      confirmDismiss: (dir) async {
                        if (dir == DismissDirection.startToEnd) {
                          // SLIDE TO VERIFY
                          if (!email.isVerified) {
                            setState(() => _pendingEmail = email.email);
                            _showAddEmailSheet();
                          }
                          return false; // Don't actually dismiss the card
                        } else {
                          // SLIDE TO DELETE
                          return await _confirmDelete(email.id, email.email);
                        }
                      },
                      background: Container(
                        margin: EdgeInsets.only(bottom: 16.h),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: EdgeInsets.only(left: 24.w),
                        child: Icon(Icons.verified_user_outlined, color: Colors.greenAccent, size: 28.r),
                      ),
                      secondaryBackground: Container(
                        margin: EdgeInsets.only(bottom: 16.h),
                        decoration: BoxDecoration(
                          color: AppColors.crimson.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                        alignment: Alignment.centerRight,
                        padding: EdgeInsets.only(right: 24.w),
                        child: Icon(Icons.delete_outline_rounded, color: AppColors.crimson, size: 28.r),
                      ),
                      child: Container(
                        margin: EdgeInsets.only(bottom: 16.h),
                        padding: EdgeInsets.all(16.r),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: isPrimary ? AppColors.crimson.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(email.email, style: AppTextStyles.labelMedium.copyWith(color: Colors.white), overflow: TextOverflow.ellipsis)),
                                      if (isPrimary) ...[
                                        SizedBox(width: 8.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: AppColors.crimson.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4.r),
                                            border: Border.all(color: AppColors.crimson.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            "PRIMARY",
                                            style: AppTextStyles.labelSmall.copyWith(
                                              color: AppColors.crimson,
                                              fontSize: 8.sp,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        SizedBox(width: 8.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(4.r),
                                          ),
                                          child: Text(
                                            "SECONDARY",
                                            style: AppTextStyles.labelSmall.copyWith(
                                              color: Colors.white38,
                                              fontSize: 8.sp,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  SizedBox(height: 6.h),
                                  Row(
                                    children: [
                                      Icon(
                                        email.isVerified ? Icons.verified_rounded : Icons.pending_actions_rounded,
                                        size: 14.r,
                                        color: email.isVerified ? Colors.greenAccent : Colors.orangeAccent,
                                      ),
                                      SizedBox(width: 6.w),
                                      Text(
                                        email.isVerified ? "VERIFIED" : "NOT VERIFIED",
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: email.isVerified ? Colors.greenAccent : Colors.orangeAccent,
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (!email.isVerified) ...[
                                        const Spacer(),
                                        Text(
                                          "SLIDE RIGHT TO VERIFY",
                                          style: AppTextStyles.labelSmall.copyWith(color: Colors.white24, fontSize: 8.sp, fontWeight: FontWeight.w900),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(24.r),
              child: _PrimaryButton(
                label: limitReached ? "MAXIMUM EMAILS REACHED" : "ADD EMAIL ADDRESS",
                onTap: limitReached ? () {} : _showAddEmailSheet,
                enabled: !limitReached,
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    ));
  }
}
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;
  const _PrimaryButton({required this.label, required this.onTap, this.isLoading = false, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (isLoading || !enabled) ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          width: double.infinity,
          height: 56.h,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(12.r),
          ),
          alignment: Alignment.center,
          child: isLoading 
            ? SizedBox(height: 24.r, width: 24.r, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
