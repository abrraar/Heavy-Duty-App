// lib/features/tracker/supplement/widgets/sheets/stack_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/supplement/model/supplement.dart';
import 'package:heavy_duty/features/tracker/supplement/model/supplement_stack.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class StackFormSheet extends StatefulWidget {
  final SupplementStack? existingStack;

  const StackFormSheet({super.key, this.existingStack});

  @override
  State<StackFormSheet> createState() => _StackFormSheetState();
}

class _StackFormSheetState extends State<StackFormSheet> {
  final TextEditingController _stackNameController = TextEditingController();
  final Set<String> _selectedIds = {};

  // Maps to hold the specific settings for each supplement in the stack
  final Map<String, bool> _recordActive = {};
  final Map<String, bool> _recordUseServings = {};
  final Map<String, bool> _restockUseServings = {};
  final Map<String, double> _recordValues = {};

  @override
  void initState() {
    super.initState();
    if (widget.existingStack != null) {
      final stack = widget.existingStack!;
      _stackNameController.text = stack.name;

      for (var item in stack.items) {
        _selectedIds.add(item.id);

        // Initialize explicit settings mapping properties from existing stack if available
        _recordActive[item.id] = stack.pinnedRecordModes[item.id] ?? true;
        _recordUseServings[item.id] = stack.pinnedUseServings[item.id] ?? true;
        _restockUseServings[item.id] = true;
        _recordValues[item.id] = stack.pinnedAmounts[item.id] ?? 1.0;
      }
    }
  }

  @override
  void dispose() {
    _stackNameController.dispose();
    super.dispose();
  }

  bool get _hasValidName => _stackNameController.text.trim().isNotEmpty;
  bool get _hasValidItemCount => _selectedIds.length >= 2;

  /// Compares current form input states with baseline model fields to find mutations
  bool _hasUnsavedModifications() {
    if (widget.existingStack == null) return false;
    final stack = widget.existingStack!;

    // Check if title has changed
    if (_stackNameController.text.trim() != stack.name) {
      return true;
    }

    // Check if selection mapping composition counts or IDs changed
    final currentStackIds = stack.items.map((i) => i.id).toSet();
    if (currentStackIds.length != _selectedIds.length ||
        !currentStackIds.containsAll(_selectedIds)) {
      return true;
    }

    return false;
  }

  String _getButtonText(bool stackAlreadyExists) {
    if (stackAlreadyExists) {
      return "STACK CONFIGURATION EXISTS";
    }
    if (!_hasValidItemCount) {
      return "SELECT 2+ SUPPLEMENTS";
    }
    if (!_hasValidName) {
      return "ENTER STACK NAME";
    }
    if (widget.existingStack != null) {
      return _hasUnsavedModifications()
          ? "MODIFY STACK"
          : "DISMISS / NO CHANGES";
    }
    return "INITIALIZE STACK";
  }

  void _handleSave(List<Supplement> combinedPool) {
    // Validation check
    if (widget.existingStack != null && !_hasUnsavedModifications()) {
      Navigator.pop(context);
      return;
    }

    final provider = context.read<SupplementProvider>();

    // Dynamic configuration safety check to catch duplicate states on tap
    bool stackAlreadyExists = false;
    for (var stack in provider.supplementStacks) {
      if (widget.existingStack != null &&
          stack.id == widget.existingStack!.id) {
        continue;
      }
      final stackItemIds = stack.items.map((i) => i.id).toSet();
      if (stackItemIds.length == _selectedIds.length &&
          stackItemIds.containsAll(_selectedIds)) {
        stackAlreadyExists = true;
        break;
      }
    }

    if (!_hasValidName || !_hasValidItemCount || stackAlreadyExists) return;

    // Extract selected items
    final selectedSupplements = combinedPool
        .where((item) => _selectedIds.contains(item.id))
        .toList();

    // Sanitize values to ensure no 0 amounts are saved
    final Map<String, double> sanitizedAmounts = {};
    for (var id in _selectedIds) {
      double val = _recordValues[id] ?? 1.0;
      sanitizedAmounts[id] = val <= 0 ? 1.0 : val;
    }

    // Create the stack with the settings captured in your local state maps
    final stack = SupplementStack(
      id: widget.existingStack?.id ?? const Uuid().v4(),
      name: _stackNameController.text.trim(),
      items: selectedSupplements,
      isPinned: widget.existingStack?.isPinned ?? false,
      isPinnedToHome: widget.existingStack?.isPinnedToHome ?? false,
      notificationsEnabled: widget.existingStack?.notificationsEnabled ?? false,
      pinnedRecordModes: _recordActive,
      pinnedUseServings: _recordUseServings,
      pinnedAmounts: sanitizedAmounts,
    );

    // Send to Provider (calls Repository -> SQLite/Cloud via addOrUpdateStack)
    provider.addOrUpdateStack(stack);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupplementProvider>();

    // Create a tracking set of item IDs that are confirmed active in the library
    final Set<String> activeLibraryIds = provider.activeSupplements
        .map((e) => e.id)
        .toSet();

    // Map to pool the final combined elements uniquely
    final Map<String, Supplement> poolMap = {};

    // 1. Layer active items from provider reference list
    for (var item in provider.activeSupplements) {
      poolMap[item.id] = item;
    }

    // 2. Layer stack items: safely preserve items that exist inside the stack
    if (widget.existingStack != null) {
      for (var item in widget.existingStack!.items) {
        poolMap.putIfAbsent(item.id, () => item);
      }
    }

    final unifiedPool = poolMap.values.toList();

    // Verification check tracking if a duplicate layout array composition already exists
    bool stackAlreadyExists = false;
    for (var stack in provider.supplementStacks) {
      if (widget.existingStack != null &&
          stack.id == widget.existingStack!.id) {
        continue;
      }
      final stackItemIds = stack.items.map((i) => i.id).toSet();
      if (stackItemIds.length == _selectedIds.length &&
          stackItemIds.containsAll(_selectedIds)) {
        stackAlreadyExists = true;
        break;
      }
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: AppColors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            Padding(
              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.r),
                        decoration: BoxDecoration(
                          color: AppColors.crimson.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.layers_rounded,
                          color: AppColors.crimson,
                          size: 24.r,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        widget.existingStack == null
                            ? "NEW STACK"
                            : "EDIT STACK",
                        style: AppTextStyles.h3,
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  _buildTextField("STACK NAME", _stackNameController),
                  SizedBox(height: 20.h),
                  Text(
                    "SELECT SUPPLEMENTS",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10.sp,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 12.h),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                itemCount: unifiedPool.length,
                itemBuilder: (context, index) {
                  final item = unifiedPool[index];
                  final isSelected = _selectedIds.contains(item.id);

                  final bool isDeactivated =
                      !item.isActive || !activeLibraryIds.contains(item.id);

                  return _buildSelectionTile(item, isSelected, isDeactivated);
                },
              ),
            ),
            _buildSaveButton(unifiedPool, stackAlreadyExists),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionTile(
    Supplement item,
    bool isSelected,
    bool isDeactivated,
  ) {
    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedIds.remove(item.id);
        } else {
          _selectedIds.add(item.id);
          _recordActive[item.id] = true;
          _recordUseServings[item.id] = true;
          _restockUseServings[item.id] = true;
          _recordValues[item.id] = 1.0;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isDeactivated
              ? AppColors.crimson.withOpacity(0.04)
              : AppColors.background.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? AppColors.crimson.withOpacity(0.5)
                : (isDeactivated
                      ? AppColors.crimson.withOpacity(0.2)
                      : AppColors.white.withOpacity(0.05)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? AppColors.crimson
                  : (isDeactivated
                        ? AppColors.crimson.withOpacity(0.4)
                        : AppColors.textSecondary),
              size: 24.r,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDeactivated
                        ? "[DEACTIVATED] ${item.name.toUpperCase()}"
                        : item.name.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                      decoration: isDeactivated && !isSelected
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: isSelected
                          ? Colors.white
                          : (isDeactivated
                                ? AppColors.crimson.withOpacity(0.7)
                                : AppColors.textSecondary),
                    ),
                  ),
                  if (isDeactivated) ...[
                    SizedBox(height: 4.h),
                    Text(
                      "CURRENTLY DEACTIVATED IN LIBRARY",
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 9.sp,
                        color: AppColors.crimson,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton(
    List<Supplement> combinedPool,
    bool stackAlreadyExists,
  ) {
    final bool staticEdit =
        widget.existingStack != null && !_hasUnsavedModifications();
    final bool validAction =
        (_hasValidName && _hasValidItemCount && !stackAlreadyExists) ||
        staticEdit;

    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
      child: GestureDetector(
        onTap: validAction ? () => _handleSave(combinedPool) : null,
        child: Container(
          height: 60.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: validAction
                ? AppColors.crimson
                : AppColors.background.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: validAction
                ? [
                    BoxShadow(
                      color: AppColors.crimson.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            _getButtonText(stackAlreadyExists),
            style: AppTextStyles.buttonPrimary.copyWith(
              color: validAction ? Colors.white : Colors.white24,
              fontSize: 16.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: TextField(
        controller: controller,
        cursorColor: AppColors.crimson,
        onChanged: (_) => setState(() {}),
        textCapitalization: TextCapitalization.none,
        style: AppTextStyles.labelSmall.copyWith(fontSize: 15.sp),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
          floatingLabelStyle: AppTextStyles.labelSmall.copyWith(
            color: AppColors.crimson,
            fontSize: 12.sp,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildHandle() => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: 16.h),
    alignment: Alignment.center,
    child: Container(
      width: 40.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(3.r),
      ),
    ),
  );
}
