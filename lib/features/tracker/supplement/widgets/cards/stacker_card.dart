// lib/features/tracker/supplement/widgets/stacker_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/supplement/model/supplement.dart';
import 'package:heavy_duty/features/tracker/supplement/model/supplement_stack.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:heavy_duty/features/tracker/supplement/widgets/sheets/stack_form_sheet.dart';
import 'package:heavy_duty/features/tracker/supplement/widgets/sheets/stack_notification_sheet.dart'; // Import the new sheet
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import 'package:heavy_duty/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../core/widgets/elite_confirm_dialog.dart';

class StackerCard extends StatefulWidget {
  final SupplementStack stack;

  const StackerCard({super.key, required this.stack});

  @override
  State<StackerCard> createState() => _StackerCardState();
}

class _StackerCardState extends State<StackerCard> {
  bool _isManagementExpanded = false;
  final Map<String, bool> _isRecordMode = {};
  final Map<String, bool> _useServings = {};
  final Map<String, TextEditingController> _controllers = {};

  // State for the log date and time
  DateTime _selectedDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncStateFromStack();
  }

  @override
  void didUpdateWidget(covariant StackerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the stack items have changed, we need to ensure we have controllers for them
    if (oldWidget.stack.items.length != widget.stack.items.length ||
        !oldWidget.stack.items.every((item) => widget.stack.items.any((newItem) => newItem.id == item.id))) {
      _syncStateFromStack();
    }
  }

  void _syncStateFromStack() {
    for (var item in widget.stack.items) {
      // Use existing state if we already have it (to prevent resetting user input on rebuild)
      if (!_controllers.containsKey(item.id)) {
        _isRecordMode[item.id] = widget.stack.pinnedRecordModes[item.id] ?? true;
        _useServings[item.id] = widget.stack.pinnedUseServings[item.id] ?? true;
        double initialAmount = widget.stack.pinnedAmounts[item.id] ?? 1.0;
        _controllers[item.id] =
            TextEditingController(text: initialAmount.toString());
        _controllers[item.id]!.addListener(() => setState(() {}));
      }
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) c.dispose();
    super.dispose();
  }

  bool get _allValuesValid {
    for (var controller in _controllers.values) {
      final val = double.tryParse(controller.text) ?? 0;
      if (val <= 0) return false;
    }
    return true;
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.crimson,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplementProvider>();

    final List<Map<String, dynamic>> itemsWithStatus = widget.stack.items.map((
      item,
    ) {
      final libraryItem = provider.library.firstWhere(
        (libItem) => libItem.id == item.id,
        orElse: () => item.copyWith(isActive: false),
      );
      // Ensure we check both the library existence AND the isActive flag
      final bool effectivelyActive = libraryItem.isActive;
      return {'item': libraryItem, 'isActive': effectivelyActive};
    }).toList();

    final int activeCount = itemsWithStatus.where((e) => e['isActive'] == true).length;
    final bool hasInvalidItems = itemsWithStatus.any((e) => e['isActive'] == false);
    
    // Check for stock issues on current settings
    bool hasStockIssue = false;
    for (var data in itemsWithStatus) {
      if (data['isActive'] == false) continue;
      final Supplement item = data['item'];
      if (_isRecordMode[item.id] == true) {
        final double amount = double.tryParse(_controllers[item.id]?.text ?? "0") ?? 0.0;
        final bool servings = _useServings[item.id] ?? true;
        double needed = servings ? (amount * item.weightPerServing) : amount;
        if ((item.remainingStock ?? 0) < (needed - 0.0001)) {
          hasStockIssue = true;
          break;
        }
      }
    }
    
    // A stack is disabled if any item is missing/inactive OR if it has fewer than 2 valid items
    // OR if there is a stock issue for an intake item
    final bool isStackDisabled = hasInvalidItems || activeCount < 2 || hasStockIssue;

    return Opacity(
      opacity: isStackDisabled ? 0.6 : 1.0,
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: isStackDisabled
                ? AppColors.crimson.withOpacity(0.3)
                : AppColors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(provider, isStackDisabled),
            if (_isManagementExpanded) _buildManagementDrawer(context),
            if (isStackDisabled)
              _buildLockedCompositionView(itemsWithStatus, activeCount)
            else
              _buildActiveFunctionalView(itemsWithStatus),
            if (!isStackDisabled) SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(SupplementProvider provider, bool isDeactivated) {
    final bool isPinnedToHome = widget.stack.isPinnedToHome;
    final bool valid = _allValuesValid;

    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 16.w, 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.stack.name.toUpperCase(),
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 18.sp,
                    color: isDeactivated
                        ? AppColors.textSecondary
                        : AppColors.white,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.stack.sharedBy != null) ...[
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
                          "SHARED BY ${widget.stack.sharedBy!.toUpperCase()}",
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
              ],
            ),
          ),
          SizedBox(width: 12.w),

          if (!isDeactivated) ...[
            _buildQuickActionButton(
              icon: isPinnedToHome ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              isActive: isPinnedToHome,
              opacity: valid ? 1.0 : 0.3,
              onTap: valid
                  ? () {
                      if (isPinnedToHome) {
                        bool matches = true;
                        for (var item in widget.stack.items) {
                          if ((_isRecordMode[item.id] ?? true) != (widget.stack.pinnedRecordModes[item.id] ?? true) ||
                              (_useServings[item.id] ?? true) != (widget.stack.pinnedUseServings[item.id] ?? true) ||
                              (double.tryParse(_controllers[item.id]?.text ?? "0") ?? 0.0) != (widget.stack.pinnedAmounts[item.id] ?? 0.0)) {
                            matches = false;
                            break;
                          }
                        }

                        if (matches) {
                          _showUnpinConfirmation(provider);
                        } else {
                          _showUpdatePinConfirmation(provider);
                        }
                      } else {
                        _showPinConfirmation(provider);
                      }
                    }
                  : () {},
            ),
            SizedBox(width: 8.w),
            _buildQuickActionButton(
              icon: widget.stack.notificationsEnabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              isActive: widget.stack.notificationsEnabled,
              opacity: valid ? 1.0 : 0.3,
              onTap: valid
                  ? () => _openNotificationSheet(context)
                  : () {},
            ),
            SizedBox(width: 8.w),
            _buildQuickActionButton(
              icon: Icons.ios_share_rounded,
              isActive: false,
              onTap: () async {
                final authProvider = context.read<AuthProvider>();
                final userName = authProvider.displayName;
                
                EliteSnackbar.show(context, "GENERATING SHAREABLE LINK...");

                final link = await provider.generateStackShareLink(widget.stack, userName);
                
                if (link != null) {
                  await Share.share(
                    "CHECK OUT THIS SUPPLEMENT STACK SHARED BY $userName IN HEAVY DUTY:\n\n$link",
                    subject: "SUPPLEMENT STACK SHARED BY $userName",
                  );
                }
              },
            ),
            SizedBox(width: 8.w),
          ],

          _buildQuickActionButton(
            icon: _isManagementExpanded
                ? Icons.close_rounded
                : Icons.more_vert_rounded,
            isActive: _isManagementExpanded,
            onTap: () =>
                setState(() => _isManagementExpanded = !_isManagementExpanded),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    double opacity = 1.0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
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
      ),
    );
  }

  /*
  Widget _headerIcon(...) { ... }
  */

  Widget _buildLockedCompositionView(
    List<Map<String, dynamic>> itemsWithStatus,
    int activeCount,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "STACK COMPONENTS",
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10.sp,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                activeCount < 2 ? "INVALID STACK" : "REACTIVATION REQUIRED",
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.crimson,
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...itemsWithStatus.map((data) {
            final Supplement item = data['item'];
            final bool isActive = data['isActive'];
            return Container(
              margin: EdgeInsets.only(bottom: 6.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: isActive
                      ? Colors.transparent
                      : AppColors.crimson.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.check_circle_outline_rounded
                        : Icons.error_outline_rounded,
                    color: isActive ? Colors.white24 : AppColors.crimson,
                    size: 16.r,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      item.name.toUpperCase(),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: isActive
                            ? AppColors.white.withOpacity(0.6)
                            : AppColors.white,
                        fontWeight: isActive
                            ? FontWeight.normal
                            : FontWeight.w900,
                        fontSize: 11.sp,
                      ),
                    ),
                  ),
                  if (!isActive)
                    Text(
                      item.name == "Deleted Item" ? "DELETED" : "INACTIVE",
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.crimson,
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
            );
          }),
          if (activeCount < 2)
            Padding(
              padding: EdgeInsets.only(top: 12.h),
              child: Text(
                "A stack must have at least 2 active supplements. Please modify this stack to continue.",
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 9.sp,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveFunctionalView(List<Map<String, dynamic>> itemsWithStatus) {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: itemsWithStatus.length,
          itemBuilder: (context, index) =>
              _buildSupplementRow(itemsWithStatus[index]['item']),
        ),
        _buildDateTimeSelector(),
        SizedBox(height: 8.h),
        _buildExecuteButton(),
      ],
    );
  }

  Widget _buildDateTimeSelector() {
    String formatted =
        "${_selectedDateTime.day}/${_selectedDateTime.month} @ ${_selectedDateTime.hour.toString().padLeft(2, '0')}:${_selectedDateTime.minute.toString().padLeft(2, '0')}";
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GestureDetector(
        onTap: _pickDateTime,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.4),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                color: AppColors.crimson,
                size: 16.r,
              ),
              SizedBox(width: 12.w),
              Text(
                "LOG DATE & TIME",
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 10.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                formatted,
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 11.sp,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.edit_calendar_rounded,
                color: AppColors.white.withOpacity(0.2),
                size: 14.r,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManagementDrawer(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
      child: Row(
        children: [
          Expanded(
            child: _drawerBtn(
              Icons.edit_document,
              "MODIFY",
              AppColors.textSecondary,
              () => _openEdit(context),
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: _drawerBtn(
              Icons.delete_sweep_rounded,
              "DELETE",
              AppColors.crimson,
              () => _confirmDelete(context),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnpinConfirmation(SupplementProvider provider) async {
    final confirm = await EliteConfirmDialog.show(
      context,
      title: "REMOVE FROM HOME",
      message: "Are you sure you want to remove '${widget.stack.name.toUpperCase()}' from your home screen shortcuts?",
      confirmText: "REMOVE",
      icon: Icons.push_pin_rounded,
    );

    if (confirm == true) {
      provider.toggleStackHomePin(
        stackId: widget.stack.id,
        recordModes: {},
        useServings: {},
        amounts: {},
      );
    }
  }

  void _showUpdatePinConfirmation(SupplementProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.r),
        ),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.update_rounded,
                color: Colors.orange,
                size: 28.r,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "UPDATE PRESET",
              style: AppTextStyles.h3.copyWith(
                fontSize: 18.sp,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Your current configuration differs from the pinned home screen shortcut. Would you like to update the preset or remove it?",
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    provider.toggleStackHomePin(
                      stackId: widget.stack.id,
                      recordModes: Map.from(_isRecordMode),
                      useServings: Map.from(_useServings),
                      amounts: _controllers.map(
                        (id, c) => MapEntry(id, double.tryParse(c.text) ?? 0.0),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: 48.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.crimson,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "UPDATE PRESET",
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: _dialogBtn(
                        "CANCEL",
                        Colors.transparent,
                        AppColors.textSecondary,
                        () => Navigator.pop(context),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: _dialogBtn(
                        "REMOVE PIN",
                        Colors.transparent,
                        AppColors.crimson,
                        () {
                          provider.toggleStackHomePin(
                            stackId: widget.stack.id,
                            recordModes: {},
                            useServings: {},
                            amounts: {},
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPinConfirmation(SupplementProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.r),
        ),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.crimson.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.push_pin_rounded,
                color: AppColors.crimson,
                size: 28.r,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "PIN TO HOME",
              style: AppTextStyles.h3.copyWith(
                fontSize: 18.sp,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Confirming current configuration as a home screen preset.",
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
                fontSize: 11.sp,
              ),
            ),
            SizedBox(height: 20.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: AppColors.white.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.stack.items.map((item) {
                  final isRecord = _isRecordMode[item.id] ?? true;
                  final servings = _useServings[item.id] ?? true;
                  final amount = _controllers[item.id]?.text ?? "0";
                  final unit = servings ? item.servingUnit : item.weightUnit;
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 6.h),
                    child: Row(
                      children: [
                        Icon(
                          isRecord
                              ? Icons.remove_circle_outline
                              : Icons.add_circle_outline,
                          size: 14.r,
                          color: isRecord ? AppColors.crimson : Colors.green,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            "${isRecord ? 'RECORD' : 'RESTOCK'} $amount $unit OF ${item.name}"
                                .toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 10.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
            child: Row(
              children: [
                Expanded(
                  child: _dialogBtn(
                    "CANCEL",
                    Colors.transparent,
                    AppColors.textSecondary,
                    () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _dialogBtn(
                    "CONFIRM",
                    AppColors.crimson,
                    Colors.white,
                    () {
                      provider.toggleStackHomePin(
                        stackId: widget.stack.id,
                        recordModes: Map.from(_isRecordMode),
                        useServings: Map.from(_useServings),
                        amounts: _controllers.map(
                          (id, c) =>
                              MapEntry(id, double.tryParse(c.text) ?? 0.0),
                        ),
                      );
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: Standardized to match identical styling scheme of Pin Confirmation Dialog
  void _showExecuteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.r),
        ),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.crimson.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.checklist_rtl_rounded,
                color: AppColors.crimson,
                size: 28.r,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "CONFIRM EXECUTION",
              style: AppTextStyles.h3.copyWith(
                fontSize: 18.sp,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Record all items in '${widget.stack.name.toUpperCase()}' for the selected date/time?",
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
            child: Row(
              children: [
                Expanded(
                  child: _dialogBtn(
                    "CANCEL",
                    Colors.transparent,
                    AppColors.textSecondary,
                    () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _dialogBtn(
                    "EXECUTE",
                    AppColors.crimson,
                    Colors.white,
                    () async {
                      final provider = context.read<SupplementProvider>();
                      await provider.executeStackLog(
                        stack: widget.stack,
                        recordModes: _isRecordMode,
                        useServings: _useServings,
                        amounts: _controllers.map(
                          (id, c) =>
                              MapEntry(id, double.tryParse(c.text) ?? 0.0),
                        ),
                        selectedDateTime: _selectedDateTime,
                      );
                      if (mounted) {
                        Navigator.pop(context);
                        EliteSnackbar.show(
                          context, 
                          "${widget.stack.name} LOGGED",
                          onUndo: () => provider.deleteLastEntry(),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplementRow(Supplement item) {
    bool isRecord = _isRecordMode[item.id] ?? true;
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _unitToggle(item),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              _modeToggleChip(
                "RECORD",
                isRecord,
                () => setState(() => _isRecordMode[item.id] = true),
              ),
              SizedBox(width: 8.w),
              _modeToggleChip(
                "RESTOCK",
                !isRecord,
                () => setState(() => _isRecordMode[item.id] = false),
              ),
              const Spacer(),
              _valueInput(item.id),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExecuteButton() {
    final valid = _allValuesValid;
    final bool hasZeroValue = _controllers.values.any((c) {
      final val = double.tryParse(c.text) ?? 0;
      return val <= 0;
    });

    // Check for stock issue again for the button label
    bool hasStockIssue = false;
    for (var controllerEntry in _controllers.entries) {
      final String id = controllerEntry.key;
      if (_isRecordMode[id] == true) {
        final double amount = double.tryParse(controllerEntry.value.text) ?? 0;
        final provider = context.read<SupplementProvider>();
        final item = provider.library.firstWhereOrNull((s) => s.id == id);
        if (item != null) {
          final bool servings = _useServings[id] ?? true;
          double needed = servings ? (amount * item.weightPerServing) : amount;
          if ((item.remainingStock ?? 0) < (needed - 0.0001)) {
            hasStockIssue = true;
            break;
          }
        }
      }
    }

    final bool canExecute = valid && !hasZeroValue && !hasStockIssue;
    String label = "EXECUTE STACK";
    if (!valid || hasZeroValue) {
      label = "DATA REQUIRED";
    } else if (hasStockIssue) {
      label = "INSUFFICIENT STOCK";
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GestureDetector(
        onTap: canExecute ? _showExecuteConfirmation : null,
        child: Container(
          height: 52.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: canExecute
                ? AppColors.crimson
                : AppColors.background.withOpacity(0.5),
            borderRadius: BorderRadius.circular(14.r),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.buttonPrimary.copyWith(
              fontSize: 13.sp,
              color: canExecute ? Colors.white : Colors.white24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _unitToggle(Supplement item) {
    bool servings = _useServings[item.id] ?? true;
    return Container(
      height: 30.h,
      padding: EdgeInsets.all(2.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _unitBtn(
            item.servingUnit,
            servings,
            () => setState(() => _useServings[item.id] = true),
          ),
          _unitBtn(
            item.weightUnit,
            !servings,
            () => setState(() => _useServings[item.id] = false),
          ),
        ],
      ),
    );
  }

  Widget _unitBtn(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.crimson : Colors.transparent,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 9.sp,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      );

  Widget _modeToggleChip(String label, bool isActive, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.crimson.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: isActive
                  ? AppColors.crimson
                  : AppColors.white.withOpacity(0.1),
            ),
          ),
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 9.sp,
              color: isActive ? AppColors.crimson : AppColors.textSecondary,
            ),
          ),
        ),
      );

  Widget _valueInput(String id) => Container(
    width: 65.w,
    height: 34.h,
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8.r),
      border: Border.all(color: AppColors.white.withOpacity(0.05)),
    ),
    child: TextField(
      controller: _controllers[id],
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: AppTextStyles.labelSmall.copyWith(
        fontSize: 14.sp,
        fontWeight: FontWeight.bold,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.only(top: 8),
      ),
    ),
  );

  Widget _drawerBtn(IconData i, String l, Color c, VoidCallback o) =>
      GestureDetector(
        onTap: o,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(
            color: c.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: c.withOpacity(0.15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(i, color: c, size: 16.r),
              SizedBox(width: 8.w),
              Text(
                l,
                style: AppTextStyles.labelSmall.copyWith(
                  color: c,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );

  void _openNotificationSheet(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StackNotificationSheet(
      stack: widget.stack,
      initialReminders: widget.stack.reminders,
      initialEnabled: widget.stack.notificationsEnabled,
    ),
  );

  void _openEdit(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StackFormSheet(existingStack: widget.stack),
  );

  // UPDATED: Standardized to match identical styling scheme of Pin Confirmation Dialog
  void _confirmDelete(BuildContext context) async {
    final confirm = await EliteConfirmDialog.show(
      context,
      title: "DELETE STACK",
      message: "Are you sure you want to delete the stack '${widget.stack.name.toUpperCase()}'?",
    );

    if (confirm == true) {
      final calorieProvider = context.read<CalorieProvider>();
      context.read<SupplementProvider>().deleteStack(
        widget.stack.id,
        onDeleted: (id, cals, pro, cho, fat) {
          calorieProvider.removeStackFromAllMeals(id, cals, pro, cho, fat);
        }
      );
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
}
