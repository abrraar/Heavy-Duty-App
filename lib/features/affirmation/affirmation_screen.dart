import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/features/main_wrapper.dart';
import 'package:heavy_duty/core/utils/adaptive_utils.dart';
import 'provider/affirmation_provider.dart';
import 'model/affirmation.dart';

class AffirmationScreen extends StatefulWidget {
  const AffirmationScreen({super.key});

  @override
  State<AffirmationScreen> createState() => _AffirmationScreenState();
}

class _AffirmationScreenState extends State<AffirmationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _addController = TextEditingController();
  final TextEditingController _speakerController = TextEditingController();
  
  final ScrollController _systemScrollController = ScrollController();
  final ScrollController _customScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "affirmation";
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    activeSettingsContext.value = "";
    _tabController.dispose();
    _addController.dispose();
    _speakerController.dispose();
    _systemScrollController.dispose();
    _customScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 600;
            return Column(
              children: [
                _buildHeader(isCompact),
                _buildTabs(isCompact),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWheelView(isSystem: true, isCompact: isCompact),
                      _buildWheelView(isSystem: false, isCompact: isCompact),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (_tabController.index == 1) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 600;
                return FloatingActionButton.extended(
                  onPressed: _showAddBottomSheet,
                  backgroundColor: AppColors.crimson,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0)),
                  icon: Icon(Icons.add_rounded, color: Colors.white, size: isCompact ? 24.r : 20.0),
                  label: Text(
                    "AFFIRMATION",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                      fontSize: isCompact ? null : 11.0,
                    ),
                  ),
                );
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 20.w : 24.0, 
        vertical: isCompact ? 10.h : 12.0
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            "AFFIRMATIONS", 
            style: AppTextStyles.h2.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? null : 20.0,
            )
          ),
          IconButton(
            icon: Icon(
              Icons.info_outline_rounded, 
              color: Colors.white.withValues(alpha: 0.5), 
              size: isCompact ? 22.r : 20.0
            ),
            onPressed: _showSystemInstructions,
          ),
        ],
      ),
    );
  }

  void _showSystemInstructions() {
    showDialog(
      context: context,
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          return AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0),
            ),
            title: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 12.r : 12.0),
                  decoration: BoxDecoration(
                    color: AppColors.crimson.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.crimson,
                    size: isCompact ? 28.r : 24.0,
                  ),
                ),
                SizedBox(height: isCompact ? 16.h : 16.0),
                Text(
                  "AFFIRMATION CONTROLS",
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 16.0, // Fixed size
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _instructionRow(Icons.add_circle_outline_rounded, "Tap the '+' button in the CUSTOM tab to add your own quote.", isCompact),
                SizedBox(height: isCompact ? 16.h : 16.0),
                _instructionRow(Icons.touch_app_rounded, "Long press any custom affirmation to edit or delete it.", isCompact),
                SizedBox(height: isCompact ? 16.h : 16.0),
                _instructionRow(Icons.sync_rounded, "Your custom affirmations are synced automatically across all your devices.", isCompact),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(isCompact ? 12.w : 12.0, 0, isCompact ? 12.w : 12.0, isCompact ? 16.h : 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: isCompact ? 12.h : 12.0),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                            border: Border.all(color: AppColors.crimson.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "DISMISS",
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.crimson,
                              fontWeight: FontWeight.w500,
                              fontSize: isCompact ? null : 11.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _instructionRow(IconData icon, String text, bool isCompact) {
    return Row(
      children: [
        Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 18.0),
        SizedBox(width: isCompact ? 12.w : 12.0),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
              fontSize: isCompact ? null : 11.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 20.w : 24.0),
      child: TabBar(
        controller: _tabController,
        indicatorColor: AppColors.crimson,
        labelColor: AppColors.crimson,
        unselectedLabelColor: AppColors.textSecondary,
        dividerColor: Colors.transparent,
        labelStyle: AppTextStyles.labelMedium.copyWith(
          fontSize: isCompact ? null : 12.0,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: "SYSTEM"),
          Tab(text: "CUSTOM"),
        ],
      ),
    );
  }

  Widget _buildWheelView({required bool isSystem, required bool isCompact}) {
    return Consumer<AffirmationProvider>(
      builder: (context, provider, _) {
        // Show all in the library scroller
        final items = isSystem ? provider.allSystemAffirmations : provider.allCustomAffirmations;

        if (items.isEmpty) {
          return Center(
            child: Text(
              isSystem ? "NO SYSTEM DATA" : "NO CUSTOM DATA",
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                fontSize: isCompact ? null : 12.0,
              ),
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final double viewportHeight = constraints.maxHeight;
            final double itemHeight = viewportHeight * 0.55; 

            return ListWheelScrollView.useDelegate(
              itemExtent: itemHeight,
              physics: const FixedExtentScrollPhysics(),
              diameterRatio: 1.5,
              perspective: 0.003,
              squeeze: 1.0,
              overAndUnderCenterOpacity: 0.2,
              useMagnifier: true,
              magnification: 1.15,
              onSelectedItemChanged: (index) {
                debugPrint('Active Affirmation Index: $index');
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: items.length,
                builder: (context, index) {
                  final aff = items[index];
                  return Center(
                    child: _buildItemContent(aff, provider, isCompact),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildItemContent(Affirmation aff, AffirmationProvider provider, bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 40.w : 60.0),
      child: GestureDetector(
        onLongPress: aff.isCustom ? () => _showAffirmationActions(context, provider, aff) : null,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '"${aff.text.toUpperCase()}"',
              textAlign: TextAlign.center,
              style: AppTextStyles.displayMedium.copyWith(
                fontSize: isCompact ? 14.sp : 24.0,
                height: 1.3,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            if (aff.speaker != null && aff.speaker!.isNotEmpty) ...[
              SizedBox(height: isCompact ? 16.h : 16.0),
              Text(
                "— ${aff.speaker!.toUpperCase()}",
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.crimson,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  fontSize: isCompact ? null : 12.0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(bool isCompact) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 16.0),
    alignment: Alignment.center,
    child: Container(
      width: isCompact ? 40.w : 40.0,
      height: isCompact ? 4.h : 4.0,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3.r),
      ),
    ),
  );

  void _showAffirmationActions(BuildContext context, AffirmationProvider provider, Affirmation aff) {
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
          final double sheetWidth = isSideSheet ? constraints.maxWidth : (isSheetCompact ? constraints.maxWidth : 500.0);

          return Align(
            alignment: isSideSheet ? Alignment.center : Alignment.bottomCenter,
            child: SizedBox(
              width: sheetWidth,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: isSideSheet ? double.infinity : null,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: isSideSheet 
                      ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                      : BorderRadius.vertical(top: Radius.circular(isSheetCompact ? 32.r : 24.0)),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSideSheet) SizedBox(height: 24.0),
                        if (!isSideSheet) _buildHandle(isSheetCompact),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            isSheetCompact ? 24.w : 24.0, 
                            0, 
                            isSheetCompact ? 24.w : 24.0, 
                            isSheetCompact ? 32.h : 24.0
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "MANAGE AFFIRMATION", 
                                          style: AppTextStyles.h3.copyWith(fontSize: isSheetCompact ? null : 18.0)
                                        ),
                                        SizedBox(height: isSheetCompact ? 8.h : 6.0),
                                        Text(
                                          "Select an action for your custom quote",
                                          style: AppTextStyles.labelSmall.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: isSheetCompact ? null : 11.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSideSheet)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                      onPressed: () => Navigator.pop(sheetContext),
                                    ),
                                ],
                              ),
                              SizedBox(height: isSheetCompact ? 32.h : 24.0),
                              _buildActionTile(
                                icon: Icons.edit_outlined,
                                title: "Edit Affirmation",
                                subtitle: "Modify your custom quote",
                                color: AppColors.crimson,
                                isCompact: isSheetCompact,
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _showEditBottomSheet(aff);
                                },
                              ),
                              SizedBox(height: isSheetCompact ? 16.h : 12.0),
                              _buildActionTile(
                                icon: Icons.delete_outline_rounded,
                                title: "Delete Affirmation",
                                subtitle: "This action cannot be undone",
                                color: AppColors.error,
                                isCompact: isSheetCompact,
                                onTap: () async {
                                  Navigator.pop(sheetContext);
                                  final confirmed = await EliteConfirmDialog.show(
                                    context,
                                    title: "DELETE AFFIRMATION",
                                    message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THIS CUSTOM AFFIRMATION?",
                                  );
                                  if (confirmed == true) {
                                    provider.deleteAffirmation(aff.id);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    required bool isCompact,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 16.w : 16.0, 
        vertical: isCompact ? 8.h : 6.0
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0)),
      tileColor: AppColors.background.withValues(alpha: 0.5),
      leading: Container(
        padding: EdgeInsets.all(isCompact ? 8.r : 8.0),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: isCompact ? 24.r : 20.0),
      ),
      title: Text(
        title,
        style: AppTextStyles.labelMedium.copyWith(color: color, fontWeight: FontWeight.w500, fontSize: isCompact ? null : 14.0),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: isCompact ? null : 10.0),
      ),
      onTap: onTap,
    );
  }


  void _showEditBottomSheet(Affirmation aff) {
    _addController.text = aff.text;
    _speakerController.text = aff.speaker ?? "";

    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
          final double sheetWidth = isSideSheet ? constraints.maxWidth : (isSheetCompact ? constraints.maxWidth : 500.0);

          return Align(
            alignment: isSideSheet ? Alignment.center : Alignment.bottomCenter,
            child: SizedBox(
              width: sheetWidth,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: isSideSheet ? double.infinity : null,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: isSideSheet 
                      ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                      : BorderRadius.vertical(top: Radius.circular(isSheetCompact ? 32.r : 24.0)),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    mainAxisSize: isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      if (isSideSheet) SizedBox(height: 24.0),
                      if (!isSideSheet) _buildHandle(isSheetCompact),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: isSheetCompact ? 24.w : 24.0, 
                            right: isSheetCompact ? 24.w : 24.0, 
                            top: isSideSheet ? 0 : 0, 
                            bottom: MediaQuery.of(context).viewInsets.bottom + (isSheetCompact ? 40.h : 32.0)
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "EDIT AFFIRMATION", 
                                    style: AppTextStyles.h3.copyWith(fontSize: isSheetCompact ? null : 18.0)
                                  ),
                                  if (isSideSheet)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                      onPressed: () => Navigator.pop(sheetContext),
                                    ),
                                ],
                              ),
                              SizedBox(height: isSheetCompact ? 20.h : 16.0),
                              ListenableBuilder(
                                listenable: _addController,
                                builder: (context, _) {
                                  final text = _addController.text.trim();
                                  final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
                                  return TextField(
                                    controller: _addController,
                                    minLines: 5,
                                    maxLines: 10,
                                    style: TextStyle(color: Colors.white, fontSize: isSheetCompact ? null : 14.0),
                                    inputFormatters: [
                                      TextInputFormatter.withFunction((oldValue, newValue) {
                                        final lineCount = newValue.text.split('\n').length;
                                        if (lineCount > 10) {
                                          return oldValue;
                                        }
                                        return newValue;
                                      }),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: "Enter custom quote...",
                                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: isSheetCompact ? null : 14.0),
                                      counterText: "$wordCount / 60 WORDS",
                                      counterStyle: AppTextStyles.labelSmall.copyWith(
                                        color: wordCount > 60 ? AppColors.error : AppColors.textSecondary,
                                        fontSize: isSheetCompact ? 10.sp : 10.0,
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0)),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0),
                                        borderSide: const BorderSide(color: AppColors.crimson),
                                      ),
                                    ),
                                  );
                                }
                              ),
                              SizedBox(height: isSheetCompact ? 16.h : 12.0),
                              TextField(
                                controller: _speakerController,
                                maxLength: 20,
                                style: TextStyle(color: Colors.white, fontSize: isSheetCompact ? null : 14.0),
                                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                                decoration: InputDecoration(
                                  hintText: "Who is the speaker?",
                                  hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: isSheetCompact ? null : 14.0),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                    borderSide: const BorderSide(color: AppColors.crimson),
                                  ),
                                  counterStyle: TextStyle(color: AppColors.textSecondary, fontSize: isSheetCompact ? null : 10.0),
                                ),
                              ),
                              SizedBox(height: isSheetCompact ? 32.h : 24.0),
                              SizedBox(
                                width: double.infinity,
                                height: isSheetCompact ? 50.h : 44.0,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.crimson,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0)),
                                  ),
                                  onPressed: () {
                                    final text = _addController.text.trim();
                                    if (text.isNotEmpty) {
                                      final wordCount = text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
                                      if (wordCount > 60) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Quote cannot exceed 60 words"),
                                            backgroundColor: AppColors.error,
                                          )
                                        );
                                        return;
                                      }

                                      context.read<AffirmationProvider>().updateAffirmation(
                                        aff.copyWith(
                                          text: text,
                                          speaker: _speakerController.text.trim().isEmpty ? null : _speakerController.text.trim(),
                                        ),
                                      );
                                      _addController.clear();
                                      _speakerController.clear();
                                      Navigator.pop(sheetContext);
                                    }
                                  },
                                  child: Text(
                                    "UPDATE AFFIRMATION", 
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: Colors.white, 
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.2,
                                      fontSize: isSheetCompact ? null : 11.0,
                                    )
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddBottomSheet() {
    _addController.clear();
    _speakerController.clear();
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
          final double sheetWidth = isSideSheet ? constraints.maxWidth : (isSheetCompact ? constraints.maxWidth : 500.0);

          return Align(
            alignment: isSideSheet ? Alignment.center : Alignment.bottomCenter,
            child: SizedBox(
              width: sheetWidth,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  height: isSideSheet ? double.infinity : null,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: isSideSheet 
                      ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                      : BorderRadius.vertical(top: Radius.circular(isSheetCompact ? 32.r : 24.0)),
                    border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    mainAxisSize: isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      if (isSideSheet) SizedBox(height: 24.0),
                      if (!isSideSheet) _buildHandle(isSheetCompact),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: isSheetCompact ? 24.w : 24.0, 
                            right: isSheetCompact ? 24.w : 24.0, 
                            top: isSideSheet ? 0 : 0, 
                            bottom: MediaQuery.of(context).viewInsets.bottom + (isSheetCompact ? 40.h : 32.0)
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "ADD CUSTOM AFFIRMATION", 
                                    style: AppTextStyles.h3.copyWith(fontSize: isSheetCompact ? null : 18.0)
                                  ),
                                  if (isSideSheet)
                                    IconButton(
                                      icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                      onPressed: () => Navigator.pop(sheetContext),
                                    ),
                                ],
                              ),
                              SizedBox(height: isSheetCompact ? 20.h : 16.0),
                              ListenableBuilder(
                                listenable: _addController,
                                builder: (context, _) {
                                  final text = _addController.text.trim();
                                  final wordCount = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
                                  return TextField(
                                    controller: _addController,
                                    minLines: 5,
                                    maxLines: 10,
                                    style: TextStyle(color: Colors.white, fontSize: isSheetCompact ? null : 14.0),
                                    inputFormatters: [
                                      TextInputFormatter.withFunction((oldValue, newValue) {
                                        final lineCount = newValue.text.split('\n').length;
                                        if (lineCount > 10) {
                                          return oldValue;
                                        }
                                        return newValue;
                                      }),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: "Enter custom quote...",
                                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: isSheetCompact ? null : 14.0),
                                      counterText: "$wordCount / 60 WORDS",
                                      counterStyle: AppTextStyles.labelSmall.copyWith(
                                        color: wordCount > 60 ? AppColors.error : AppColors.textSecondary,
                                        fontSize: isSheetCompact ? 10.sp : 10.0,
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0)),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0),
                                        borderSide: const BorderSide(color: AppColors.crimson),
                                      ),
                                    ),
                                  );
                                }
                              ),
                              SizedBox(height: isSheetCompact ? 16.h : 12.0),
                              TextField(
                                controller: _speakerController,
                                maxLength: 20,
                                style: TextStyle(color: Colors.white, fontSize: isSheetCompact ? null : 14.0),
                                inputFormatters: [LengthLimitingTextInputFormatter(20)],
                                decoration: InputDecoration(
                                  hintText: "Who is the speaker?",
                                  hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: isSheetCompact ? null : 14.0),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0)),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.r),
                                    borderSide: const BorderSide(color: AppColors.crimson),
                                  ),
                                  counterStyle: TextStyle(color: AppColors.textSecondary, fontSize: isSheetCompact ? null : 10.0),
                                ),
                              ),
                              SizedBox(height: isSheetCompact ? 32.h : 24.0),
                              SizedBox(
                                width: double.infinity,
                                height: isSheetCompact ? 50.h : 44.0,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.crimson,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 10.0)),
                                  ),
                                  onPressed: () {
                                    final text = _addController.text.trim();
                                    if (text.isNotEmpty) {
                                      final wordCount = text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
                                      if (wordCount > 60) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Quote cannot exceed 60 words"),
                                            backgroundColor: AppColors.error,
                                          )
                                        );
                                        return;
                                      }

                                      context.read<AffirmationProvider>().addAffirmation(
                                        text,
                                        _speakerController.text.trim().isEmpty ? null : _speakerController.text.trim(),
                                      );
                                      _addController.clear();
                                      _speakerController.clear();
                                      Navigator.pop(sheetContext);
                                    }
                                  },
                                  child: Text(
                                    "SAVE AFFIRMATION", 
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: Colors.white, 
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.2,
                                      fontSize: isSheetCompact ? null : 11.0,
                                    )
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
