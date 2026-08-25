// lib/features/tracker/supplement/widgets/library_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/supplement/model/supplement.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';

import 'package:heavy_duty/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class LibraryCard extends StatefulWidget {
  final Supplement item;
  final SupplementProvider provider;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const LibraryCard({
    super.key,
    required this.item,
    required this.provider,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<LibraryCard> createState() => _LibraryCardState();
}

class _LibraryCardState extends State<LibraryCard> {
  bool isExpanded = false; // Tracks if the action menu is open

  void _showHeavyDutyDeletePrompt(BuildContext context) async {
    final confirm = await EliteConfirmDialog.show(
      context,
      title: "DELETE SUPPLEMENT",
      message: "Are you sure you want to permanently delete \"${widget.item.name.toUpperCase()}\"? This action cannot be undone.",
      icon: Icons.delete_outline_rounded,
    );
    
    if (confirm == true) {
      widget.onDelete();
    }
  }

  Widget _dialogBtn(String label, Color bg, Color text, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: bg == Colors.transparent
                  ? AppColors.white.withOpacity(0.1)
                  : Colors.transparent,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: text,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    String daysUntilExpiry = widget.provider
        .getDaysUntilExpiry(widget.item.expiryDate)
        .toString();

    String expiryText = widget.item.expiryDate != null
        ? "${widget.item.expiryDate!.day}/${widget.item.expiryDate!.month}/${widget.item.expiryDate!.year} | $daysUntilExpiry days left"
        : "No expiry set";

    String remainingServings =
        "${widget.provider.getRemainingServings(widget.item)}s left in stock";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 12.w, 20.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: widget.item.isActive
              ? Colors.transparent
              : AppColors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment
                .start, // Aligns toggle and option buttons to the top row layout boundary
            children: [
              Switch(
                value: widget.item.isActive,
                activeThumbColor: AppColors.crimson,
                onChanged: (v) {
                  final calorieProvider = context.read<CalorieProvider>();
                  widget.provider.toggleSupplementStatus(
                    widget.index, 
                    v,
                    onDeactivated: (id, cals, pro, cho, fat) {
                      calorieProvider.removeSupplementFromAllMeals(id, cals, pro, cho, fat);
                    }
                  );
                },
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 4.h,
                  ), // Adjusts vertical alignment to balance perfectly with the top-aligned controls
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.name.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 14.sp,
                          color: widget.item.isActive
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.item.sharedBy != null) ...[
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
                                "SHARED BY ${widget.item.sharedBy!.toUpperCase()}",
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
                      SizedBox(height: 4.h),
                      Text(
                        remainingServings,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: widget.provider.getStockColor(widget.item),
                          fontSize: 12.sp,
                        ),
                      ),

                      if (widget.item.ingredients.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.only(top: 6.h, left: 4.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: widget.item.ingredients.map((ingredient) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 2.h),
                                child: Text(
                                  "• ${ingredient.name}: ${ingredient.amount.toInt()}${ingredient.unit}",
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              _buildQuickActionButton(
                icon: Icons.ios_share_rounded,
                isActive: false,
                onTap: () async {
                  final authProvider = context.read<AuthProvider>();
                  final userName = authProvider.displayName;
                  
                  EliteSnackbar.show(context, "GENERATING SHAREABLE LINK...");

                  final link = await widget.provider.generateSupplementShareLink(widget.item, userName);
                  
                  if (link != null) {
                    await Share.share(
                      "CHECK OUT THIS SUPPLEMENT SHARED BY $userName IN HEAVY DUTY:\n\n$link",
                      subject: "SUPPLEMENT SHARED BY $userName",
                    );
                  }
                },
              ),
              SizedBox(width: 8.w),
              _buildQuickActionButton(
                icon: isExpanded ? Icons.close_rounded : Icons.more_vert_rounded,
                isActive: isExpanded,
                onTap: () => setState(() => isExpanded = !isExpanded),
              ),
            ],
          ),

          // Expandable Action Menu
          if (isExpanded) ...[
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.edit_note_rounded,
                      label: "EDIT",
                      color: AppColors.textSecondary.withOpacity(0.1),
                      onTap: () {
                        setState(() => isExpanded = false);
                        widget.onEdit();
                      },
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: "DELETE",
                      color: AppColors.crimson.withOpacity(0.1),
                      iconColor: AppColors.crimson,
                      onTap: () {
                        setState(() => isExpanded = false);
                        widget.onDelete();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (widget.item.expiryDate != null) ...[
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Divider(
                color: AppColors.white.withOpacity(0.05),
                thickness: 1,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 14.r,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      "Expires: ",
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 11.sp,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      expiryText,
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 11.sp,
                        color: widget.provider.getExpiryColor(
                          widget.item.expiryDate,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.item.caloriesPerUnit != null)
                  Text(
                    "${widget.item.caloriesPerUnit!.toStringAsFixed(0)} kcal/${widget.item.weightUnit}",
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 11.sp,
                      color: AppColors.textSecondary.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ],
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18.r, color: iconColor ?? Colors.white),
            SizedBox(width: 8.w),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: iconColor ?? Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
