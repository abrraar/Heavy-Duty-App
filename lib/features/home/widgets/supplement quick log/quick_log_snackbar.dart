import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CustomLogSnackbar extends StatefulWidget {
  final String message;
  final VoidCallback onUndo;
  final VoidCallback onDismissed;

  const CustomLogSnackbar({
    super.key,
    required this.message,
    required this.onUndo,
    required this.onDismissed,
  });

  @override
  State<CustomLogSnackbar> createState() => _CustomLogSnackbarState();
}

class _CustomLogSnackbarState extends State<CustomLogSnackbar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Starts below the screen (offset 2.0) and slides up to position
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 2.0), 
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _controller.forward();

    // Auto-dismiss logic
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _dismiss();
    });
  }

  void _dismiss() async {
    // Animate down for the "exit" effect
    await _controller.animateTo(0.0, 
      duration: const Duration(milliseconds: 300), 
      curve: Curves.easeIn
    );
    widget.onDismissed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40.h,
      left: 20.w,
      right: 20.w,
      child: SlideTransition(
        position: _offsetAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.message,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    widget.onUndo();
                    _dismiss();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    child: Text(
                      "UNDO",
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.crimson,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}