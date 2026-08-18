import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/supplement/model/supplement.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';

class TrackerCard extends StatefulWidget {
  final Supplement supplement;
  final VoidCallback onLogTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onQuickLogTap; // Added callback for the pin icon

  const TrackerCard({
    super.key,
    required this.supplement,
    required this.onLogTap,
    required this.onNotificationTap,
    required this.onQuickLogTap, // Added to constructor
  });

  @override
  State<TrackerCard> createState() => _TrackerCardState();
}

class _TrackerCardState extends State<TrackerCard> {
  bool _showIngredients = false; // Tracks toggle state for visibility

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SupplementProvider>(context);

    // Dynamic stock text calculation with safety fallback checks
    String stockText;
    if (widget.supplement.remainingStock == null) {
      stockText = "NO STOCK VALUE ENTERED";
    } else {
      String formattedServings = provider.getRemainingServings(
        widget.supplement,
      );
      stockText =
          "${widget.supplement.remainingStock!.toInt()}${widget.supplement.weightUnit} |"
          " $formattedServings left";
    }

    // Expiry and Days Remaining calculation variables
    String expiryText = "";
    Color expiryColor = AppColors.textSecondary;
    if (widget.supplement.expiryDate != null) {
      final date = widget.supplement.expiryDate!;
      final daysLeft = provider.getDaysUntilExpiry(date);
      expiryColor = provider.getExpiryColor(date);

      final dateString = "${date.day}/${date.month}/${date.year}";
      if (daysLeft < 0) {
        expiryText = "EXPIRED ($dateString)";
      } else if (daysLeft == 0) {
        expiryText = "EXPIRES TODAY ($dateString)";
      } else {
        expiryText = "Expires: $dateString ($daysLeft days left)";
      }
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.fromLTRB(16.r, 20.r, 12.r, 20.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Intake Log Button
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: GestureDetector(
              onTap: widget.onLogTap,
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: AppColors.crimson.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: AppColors.crimson,
                  size: 20.r,
                ),
              ),
            ),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.supplement.name.toUpperCase(),
                  style: AppTextStyles.labelMedium.copyWith(
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                if (widget.supplement.sharedBy != null) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_rounded, color: Colors.blueAccent, size: 10.r),
                        SizedBox(width: 4.w),
                        Text(
                          "SHARED BY ${widget.supplement.sharedBy!.toUpperCase()}",
                          style: AppTextStyles.labelSmall.copyWith(
                            color: Colors.blueAccent,
                            fontSize: 8.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Toggle row button for showing/hiding ingredients with interactive arrow indicator icon
                if (widget.supplement.ingredients.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showIngredients = !_showIngredients;
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.only(top: 4.h, bottom: 4.h),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showIngredients
                                ? "Hide Ingredients"
                                : "Show Ingredients",
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 2.w),
                          Icon(
                            _showIngredients
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary,
                            size: 14.r,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Ingredients breakdown column rendered right beneath the toggle action
                  if (_showIngredients)
                    Padding(
                      padding: EdgeInsets.only(top: 2.h, bottom: 4.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: widget.supplement.ingredients.map((
                          ingredient,
                        ) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 2.h),
                            child: Text(
                              "• ${ingredient.name}: ${ingredient.amount.toInt()}${ingredient.unit}",
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 10.sp,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],

                SizedBox(height: 4.h),
                Text(
                  "1 ${widget.supplement.servingUnit} (${widget.supplement.weightPerServing.toStringAsFixed(1)}${widget.supplement.weightUnit})",
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "Stock: ",
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10.sp,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (stockText.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        stockText,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: widget.supplement.remainingStock == null
                              ? AppColors.textSecondary.withValues(alpha: 0.6)
                              : provider.getStockColor(widget.supplement),
                          fontSize: 10.sp,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),

                // Expiry Date and Days metrics placed right beneath Stock line layout
                if (expiryText.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    expiryText,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: expiryColor,
                      fontSize: 10.sp,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),
          // Pins Icon Button
          _buildQuickActionButton(
            icon: Icons.push_pin_rounded,
            isActive: widget.supplement.isPinnedToHome,
            onTap: widget.onQuickLogTap,
          ),
          SizedBox(width: 8.w),
          // Notification Toggle Button
          _buildQuickActionButton(
            icon: Icons.notifications_active_outlined,
            isActive: widget.supplement.notificationsEnabled,
            onTap: widget.onNotificationTap,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: isActive ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10.r),
          border: Border.all(
            color: isActive ? AppColors.crimson.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.crimson : AppColors.textSecondary,
          size: 18.r,
        ),
      ),
    );
  }
}
