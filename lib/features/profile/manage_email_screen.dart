import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class ManageEmailScreen extends StatefulWidget {
  const ManageEmailScreen({super.key});

  @override
  State<ManageEmailScreen> createState() => _ManageEmailScreenState();
}

class _ManageEmailScreenState extends State<ManageEmailScreen> {
  final _emailController = TextEditingController();

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
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
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
            Text("ADD EMAIL ADDRESS", style: AppTextStyles.h3),
            SizedBox(height: 8.h),
            Text("A CONFIRMATION LINK WILL BE SENT", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
            SizedBox(height: 24.h),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "EMAIL ADDRESS",
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: AppColors.surfaceLight.withOpacity(0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
              ),
            ),
            SizedBox(height: 24.h),
            _PrimaryButton(
              label: "SEND CONFIRMATION EMAIL",
              onTap: () async {
                final email = _emailController.text.trim();
                if (email.isNotEmpty) {
                  await context.read<AuthProvider>().addEmail(email);
                  if (!mounted) return;
                  Navigator.pop(context);
                  _emailController.clear();
                  EliteSnackbar.show(context, "CONFIRMATION EMAIL SENT");
                }
              },
            ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String id, String email) async {
    final confirmed = await EliteConfirmDialog.show(
      context,
      title: "REMOVE EMAIL",
      message: "ARE YOU SURE YOU WANT TO REMOVE $email?",
      confirmText: "REMOVE",
    );

    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().removeEmail(id);
      EliteSnackbar.show(context, "EMAIL REMOVED");
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final emails = authProv.userEmails;
    final canDelete = emails.length > 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("MANAGE EMAILS", style: AppTextStyles.h3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(24.r),
              itemCount: emails.length,
              itemBuilder: (context, index) {
                final email = emails[index];
                final bool isPrimary = email.email == authProv.currentUser?.email;

                return Container(
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
                                Text(email.email, style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
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
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: (canDelete && !isPrimary) ? AppColors.crimson : Colors.white10,
                        ),
                        onPressed: (canDelete && !isPrimary) ? () => _confirmDelete(email.id, email.email) : null,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24.r),
            child: _PrimaryButton(
              label: "ADD EMAIL ADDRESS",
              onTap: _showAddEmailSheet,
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56.h,
        decoration: BoxDecoration(
          color: AppColors.crimson,
          borderRadius: BorderRadius.circular(12.r),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
