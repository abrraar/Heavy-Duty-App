// lib/features/tracker/supplement/widgets/supplement_form_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import '../../model/supplement.dart';

class SupplementFormSheet extends StatefulWidget {
  final Supplement? existingItem;
  final int? index;
  final Function(Supplement item, int? index) onSave;

  const SupplementFormSheet({
    super.key,
    this.existingItem,
    this.index,
    required this.onSave,
  });

  @override
  State<SupplementFormSheet> createState() => _SupplementFormSheetState();
}

class _SupplementFormSheetState extends State<SupplementFormSheet> {
  late TextEditingController nameController;
  late TextEditingController sUnitController;
  late TextEditingController wSizeController;
  late TextEditingController wUnitController;
  late TextEditingController descController;
  late TextEditingController stockController;

  // New Controllers
  late TextEditingController expiryController;
  late TextEditingController caloriesController;
  late TextEditingController proteinController;
  late TextEditingController carbsController;
  late TextEditingController fatsController;

  bool useServingsForStock = true;
  DateTime? selectedExpiryDate;

  // Dynamic rows tracking state for broken-down sub-ingredients
  List<SupplementIngredientRow> ingredientRows = [];

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.existingItem?.name ?? "",
    );
    sUnitController = TextEditingController(
      text: widget.existingItem?.servingUnit ?? "Scoop",
    );
    wSizeController = TextEditingController(
      text: widget.existingItem?.weightPerServing.toString() ?? "",
    );
    wUnitController = TextEditingController(
      text: widget.existingItem?.weightUnit ?? "g",
    );
    descController = TextEditingController(
      text: widget.existingItem?.description ?? "",
    );
    stockController = TextEditingController(
      text: widget.existingItem?.totalStock?.toString() ?? "",
    );

    // Initialize New Fields
    selectedExpiryDate = widget.existingItem?.expiryDate;
    expiryController = TextEditingController(
      text: selectedExpiryDate != null
          ? "${selectedExpiryDate!.day}/${selectedExpiryDate!.month}/${selectedExpiryDate!.year}"
          : "",
    );
    caloriesController = TextEditingController(
      text: widget.existingItem?.caloriesPerUnit?.toString() ?? "",
    );
    proteinController = TextEditingController(
      text: widget.existingItem?.proteinPerUnit?.toString() ?? "",
    );
    carbsController = TextEditingController(
      text: widget.existingItem?.carbsPerUnit?.toString() ?? "",
    );
    fatsController = TextEditingController(
      text: widget.existingItem?.fatsPerUnit?.toString() ?? "",
    );

    // Load any existing ingredients if editing an item
    if (widget.existingItem != null &&
        widget.existingItem!.ingredients.isNotEmpty) {
      for (var ing in widget.existingItem!.ingredients) {
        ingredientRows.add(
          SupplementIngredientRow(
            nameCtrl: TextEditingController(text: ing.name),
            amountCtrl: TextEditingController(text: ing.amount.toString()),
            unitCtrl: TextEditingController(text: ing.unit),
          ),
        );
      }
    } else {
      // Always start with one empty ingredient entry by default
      ingredientRows.add(
        SupplementIngredientRow(
          nameCtrl: TextEditingController(),
          amountCtrl: TextEditingController(),
          unitCtrl: TextEditingController(),
        ),
      );
    }

    nameController.addListener(_onFieldChanged);
    sUnitController.addListener(_onFieldChanged);
    wSizeController.addListener(_onFieldChanged);
    wUnitController.addListener(_onFieldChanged);

    // Add listeners to existing tracking controllers to dynamically validate changes
    for (var row in ingredientRows) {
      row.nameCtrl.addListener(_onFieldChanged);
      row.amountCtrl.addListener(_onFieldChanged);
      row.unitCtrl.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    setState(() {});
  }

  bool _isFormValid() {
    final bool basicValid =
        nameController.text.trim().isNotEmpty &&
        sUnitController.text.trim().isNotEmpty &&
        wUnitController.text.trim().isNotEmpty &&
        wSizeController.text.trim().isNotEmpty &&
        (double.tryParse(wSizeController.text) ?? 0) > 0;

    if (!basicValid) return false;

    bool hasAtLeastOneValidIngredient = false;
    for (var row in ingredientRows) {
      final name = row.nameCtrl.text.trim();
      final amountStr = row.amountCtrl.text.trim();
      final unit = row.unitCtrl.text.trim();
      final amount = double.tryParse(amountStr) ?? 0.0;

      if (name.isNotEmpty && unit.isNotEmpty && amount > 0) {
        hasAtLeastOneValidIngredient = true;
        break;
      }
    }

    return hasAtLeastOneValidIngredient;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedExpiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.crimson,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != selectedExpiryDate) {
      setState(() {
        selectedExpiryDate = picked;
        expiryController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    sUnitController.dispose();
    wSizeController.dispose();
    wUnitController.dispose();
    descController.dispose();
    stockController.dispose();
    expiryController.dispose();
    caloriesController.dispose();
    proteinController.dispose();
    carbsController.dispose();
    fatsController.dispose();
    for (var row in ingredientRows) {
      row.nameCtrl.dispose();
      row.amountCtrl.dispose();
      row.unitCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: AppColors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(top: 16.h, bottom: 16.h),
              alignment: Alignment.center,
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3.r),
                ),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 40.h),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.only(
                              top: 10.r,
                              bottom: 10.r,
                              left: 10.r,
                              right: 10.r,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.crimson.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.existingItem == null
                                  ? Icons.add_rounded
                                  : Icons.edit_rounded,
                              color: AppColors.crimson,
                              size: 24.r,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.existingItem == null
                                      ? "ADD SUPPLEMENT"
                                      : "EDIT SUPPLEMENT",
                                  style: AppTextStyles.h3,
                                ),
                                Text(
                                  "LIBRARY CONFIGURATION",
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      _buildFieldGroup(
                        "SUPPLEMENT NAME *",
                        nameController,
                        "e.g. Whey Protein",
                      ),
                      SizedBox(height: 16.h),

                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldGroup(
                              "SERVING UNIT *",
                              sUnitController,
                              "Scoop",
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildFieldGroup(
                              "WEIGHT UNIT *",
                              wUnitController,
                              "g",
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      _buildFieldGroup(
                        "WEIGHT PER SERVING *",
                        wSizeController,
                        "0.0",
                        isNumeric: true,
                      ),
                      SizedBox(height: 28.h),

                      // ─── VERTICAL INGREDIENTS BREAKDOWN COLUMN LAYOUT ───
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "INGREDIENTS BREAKDOWN * (MINIMUM 1)",
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: ingredientRows.length,
                            itemBuilder: (context, index) {
                              final row = ingredientRows[index];
                              return Padding(
                                padding: EdgeInsets.only(bottom: 20.h),
                                child: Container(
                                  padding: EdgeInsets.only(
                                    top: 18.h,
                                    bottom: 18.h,
                                    left: 18.w,
                                    right: 18.w,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background.withOpacity(
                                      0.35,
                                    ),
                                    borderRadius: BorderRadius.circular(20.r),
                                    border: Border.all(
                                      color: AppColors.white.withOpacity(0.06),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Top Header Action Row inside Card Component to cleanly separate delete button
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "ENTRY #${index + 1}",
                                            style: AppTextStyles.labelSmall
                                                .copyWith(
                                                  color: AppColors.textSecondary
                                                      .withOpacity(0.6),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11.sp,
                                                  letterSpacing: 0.8,
                                                ),
                                          ),
                                          if (ingredientRows.length > 1)
                                            GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  row.nameCtrl.dispose();
                                                  row.amountCtrl.dispose();
                                                  row.unitCtrl.dispose();
                                                  ingredientRows.removeAt(
                                                    index,
                                                  );
                                                });
                                              },
                                              child: Container(
                                                padding: EdgeInsets.only(
                                                  top: 6.h,
                                                  bottom: 6.h,
                                                  left: 10.w,
                                                  right: 10.w,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.crimson
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        8.r,
                                                      ),
                                                  border: Border.all(
                                                    color: AppColors.crimson
                                                        .withOpacity(0.15),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      color: AppColors.crimson,
                                                      size: 14.r,
                                                    ),
                                                    SizedBox(width: 4.w),
                                                    Text(
                                                      "REMOVE",
                                                      style: AppTextStyles
                                                          .labelSmall
                                                          .copyWith(
                                                            color: AppColors
                                                                .crimson,
                                                            fontSize: 10.sp,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(
                                          top: 12.h,
                                          bottom: 16.h,
                                        ),
                                        child: Divider(
                                          color: AppColors.white.withOpacity(
                                            0.04,
                                          ),
                                          thickness: 1,
                                        ),
                                      ),

                                      // Field 1: Ingredient Name Column Row Layout
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 35,
                                            child: Text(
                                              "Ingredient Name",
                                              style: AppTextStyles.labelSmall
                                                  .copyWith(
                                                    color: AppColors.white
                                                        .withOpacity(0.7),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            flex: 65,
                                            child: _buildModernInput(
                                              row.nameCtrl,
                                              "e.g. Creatine Monohydrate",
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 14.h),

                                      // Field 2: Amount Column Row Layout
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 35,
                                            child: Text(
                                              "Amount",
                                              style: AppTextStyles.labelSmall
                                                  .copyWith(
                                                    color: AppColors.white
                                                        .withOpacity(0.7),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            flex: 65,
                                            child: _buildModernInput(
                                              row.amountCtrl,
                                              "e.g. 5000",
                                              isNumeric: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 14.h),

                                      // Field 3: Unit Column Row Layout
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 35,
                                            child: Text(
                                              "Unit (e.g. mg)",
                                              style: AppTextStyles.labelSmall
                                                  .copyWith(
                                                    color: AppColors.white
                                                        .withOpacity(0.7),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            flex: 65,
                                            child: _buildModernInput(
                                              row.unitCtrl,
                                              "e.g. mg or g",
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          // High-Visibility Structural "ADD INGREDIENT ENTRY" Button Design Element
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                final newRow = SupplementIngredientRow(
                                  nameCtrl: TextEditingController(),
                                  amountCtrl: TextEditingController(),
                                  unitCtrl: TextEditingController(),
                                );
                                newRow.nameCtrl.addListener(_onFieldChanged);
                                newRow.amountCtrl.addListener(_onFieldChanged);
                                newRow.unitCtrl.addListener(_onFieldChanged);
                                ingredientRows.add(newRow);
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              height: 54.h,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.crimson.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: AppColors.crimson.withOpacity(0.3),
                                  width: 1.5,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_circle_outline_rounded,
                                    color: AppColors.crimson,
                                    size: 18.r,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    "ADD NEXT INGREDIENT",
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.crimson,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // EXPIRY & CALORIES
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "EXPIRY DATE",
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                GestureDetector(
                                  onTap: () => _selectDate(context),
                                  child: AbsorbPointer(
                                    child: _buildModernInput(
                                      expiryController,
                                      "DD/MM/YYYY",
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildFieldGroup(
                              "CALORIES PER ${wUnitController.text.isEmpty ? 'UNIT' : wUnitController.text.toUpperCase()}",
                              caloriesController,
                              "0.0",
                              isNumeric: true,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),

                      // MACROS PER UNIT
                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldGroup(
                              "PRO (g)",
                              proteinController,
                              "0.0",
                              isNumeric: true,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _buildFieldGroup(
                              "CHO (g)",
                              carbsController,
                              "0.0",
                              isNumeric: true,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: _buildFieldGroup(
                              "FAT (g)",
                              fatsController,
                              "0.0",
                              isNumeric: true,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      if (widget.existingItem == null) ...[
                        Padding(
                          padding: EdgeInsets.only(top: 24.h, bottom: 24.h),
                          child: Divider(
                            color: AppColors.white.withOpacity(0.08),
                            thickness: 1,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "TOTAL STOCK (OPTIONAL)",
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                _buildSegmentedSelector(
                                  [
                                    sUnitController.text.isEmpty
                                        ? "Serv"
                                        : sUnitController.text,
                                    wUnitController.text.isEmpty
                                        ? "Unit"
                                        : wUnitController.text,
                                  ],
                                  useServingsForStock ? 0 : 1,
                                  (i) => setState(
                                    () => useServingsForStock = i == 0,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            _buildModernInput(
                              stockController,
                              "Enter total amount",
                              isNumeric: true,
                            ),
                          ],
                        ),
                      ],

                      SizedBox(height: 16.h),

                      _buildFieldGroup(
                        "DESCRIPTION (OPTIONAL)",
                        descController,
                        "Notes about this supplement",
                        maxLines: 4,
                      ),

                      SizedBox(height: 32.h),

                      _buildActionButton(
                        widget.existingItem == null
                            ? "ADD TO LIBRARY"
                            : "SAVE CHANGES",
                        _isFormValid()
                            ? AppColors.crimson
                            : AppColors.surfaceLight,
                        _isFormValid()
                            ? () {
                                double weight =
                                    double.tryParse(wSizeController.text) ??
                                    1.0;

                                double? finalStock;
                                double? finalRemaining;

                                if (widget.existingItem == null) {
                                  double? stockRaw = double.tryParse(
                                    stockController.text,
                                  );
                                  finalStock = stockRaw != null
                                      ? (useServingsForStock
                                            ? stockRaw * weight
                                            : stockRaw)
                                      : null;
                                  finalRemaining = finalStock;
                                } else {
                                  finalStock = widget.existingItem!.totalStock;
                                  finalRemaining =
                                      widget.existingItem!.remainingStock;
                                }

                                List<SupplementIngredient> compiledIngredients =
                                    [];
                                for (var row in ingredientRows) {
                                  final name = row.nameCtrl.text.trim();
                                  final amountStr = row.amountCtrl.text.trim();
                                  final unit = row.unitCtrl.text.trim();
                                  final amount =
                                      double.tryParse(amountStr) ?? 0.0;

                                  if (name.isNotEmpty &&
                                      unit.isNotEmpty &&
                                      amount > 0) {
                                    compiledIngredients.add(
                                      SupplementIngredient(
                                        name: name,
                                        amount: amount,
                                        unit: unit,
                                      ),
                                    );
                                  }
                                }

                                final newItem = Supplement(
                                  id:
                                      widget.existingItem?.id ??
                                      DateTime.now().toString(),
                                  name: nameController.text.trim(),
                                  servingUnit: sUnitController.text.trim(),
                                  weightPerServing: weight,
                                  weightUnit: wUnitController.text.trim(),
                                  description: descController.text.trim(),
                                  totalStock: finalStock,
                                  remainingStock: finalRemaining,
                                  expiryDate: selectedExpiryDate,
                                  caloriesPerUnit: double.tryParse(
                                    caloriesController.text,
                                  ),
                                  proteinPerUnit: double.tryParse(
                                    proteinController.text,
                                  ),
                                  carbsPerUnit: double.tryParse(
                                    carbsController.text,
                                  ),
                                  fatsPerUnit: double.tryParse(
                                    fatsController.text,
                                  ),
                                  isActive:
                                      widget.existingItem?.isActive ?? true,
                                  isPinnedToHome:
                                      widget.existingItem?.isPinnedToHome ??
                                      false,
                                  pinnedIntakeAmount:
                                      widget.existingItem?.pinnedIntakeAmount ??
                                      0,
                                  pinnedRestockAmount:
                                      widget
                                          .existingItem
                                          ?.pinnedRestockAmount ??
                                      0,
                                  pinnedUseServingsIntake:
                                      widget
                                          .existingItem
                                          ?.pinnedUseServingsIntake ??
                                      true,
                                  pinnedUseServingsRestock:
                                      widget
                                          .existingItem
                                          ?.pinnedUseServingsRestock ??
                                      true,
                                  notificationsEnabled:
                                      widget
                                          .existingItem
                                          ?.notificationsEnabled ??
                                      false,
                                  reminders:
                                      widget.existingItem?.reminders ?? [],
                                  ingredients: compiledIngredients,
                                );

                                widget.onSave(newItem, widget.index);
                                Navigator.pop(context);
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldGroup(
    String label,
    TextEditingController controller,
    String hint, {
    bool isNumeric = false,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8.h),
        _buildModernInput(
          controller,
          hint,
          isNumeric: isNumeric,
          maxLines: maxLines,
        ),
      ],
    );
  }

  Widget _buildModernInput(
    TextEditingController controller,
    String hint, {
    bool isNumeric = false,
    int maxLines = 1,
  }) {
    return Container(
      constraints: BoxConstraints(minHeight: maxLines > 1 ? 120.h : 54.h),
      padding: EdgeInsets.only(left: 16.w, right: 16.w),
      alignment: maxLines > 1 ? Alignment.topLeft : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumeric
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: isNumeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)'))]
            : [],
        style: AppTextStyles.labelSmall.copyWith(fontSize: 15.sp),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.25),
            fontSize: 15.sp,
          ),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.only(top: 16.h, bottom: 16.h),
        ),
      ),
    );
  }

  Widget _buildSegmentedSelector(
    List<String> labels,
    int activeIndex,
    Function(int) onTap,
  ) {
    return Container(
      height: 38.h,
      padding: EdgeInsets.only(top: 4.r, bottom: 4.r, left: 4.r, right: 4.r),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(labels.length, (index) {
          final bool isActive = activeIndex == index;
          return GestureDetector(
            onTap: () => onTap(index),
            child: Container(
              padding: EdgeInsets.only(left: 16.w, right: 16.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? AppColors.crimson : Colors.transparent,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                labels[index].toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    Color color,
    VoidCallback? onPressed,
  ) {
    bool isEnabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: AppTextStyles.buttonPrimary.copyWith(
            color: isEnabled
                ? Colors.white
                : AppColors.textSecondary.withOpacity(0.4),
            fontSize: 16.sp,
          ),
        ),
      ),
    );
  }
}

// ─── LOCAL STATE ROW MODEL OBJECT ───
class SupplementIngredientRow {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  final TextEditingController unitCtrl;

  SupplementIngredientRow({
    required this.nameCtrl,
    required this.amountCtrl,
    required this.unitCtrl,
  });
}
