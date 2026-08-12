import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';

class ImportSupplementScreen extends StatefulWidget {
  final String shareId;
  final String senderName;

  const ImportSupplementScreen({super.key, required this.shareId, required this.senderName});

  @override
  State<ImportSupplementScreen> createState() => _ImportSupplementScreenState();
}

class _ImportSupplementScreenState extends State<ImportSupplementScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _suppData;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final provider = context.read<SupplementProvider>();
    final data = await provider.fetchSharedEntity(widget.shareId);
    
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (data != null && data.containsKey('expired')) {
          _isExpired = true;
        } else {
          _suppData = data;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.crimson)),
      );
    }

    if (_isExpired || _suppData == null) {
      return _buildExpiredState();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSenderInfo(),
                    SizedBox(height: 32.h),
                    Text(
                      "SUPPLEMENT DETAILS",
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 2),
                    ),
                    SizedBox(height: 16.h),
                    _buildSuppSummary(),
                    SizedBox(height: 40.h),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 8.w),
      child: Center(
        child: Text(
          "SHARED SUPPLEMENT",
          style: AppTextStyles.h2.copyWith(color: AppColors.white, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
      ),
    );
  }

  Widget _buildSenderInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.medication_rounded, color: AppColors.crimson, size: 40.r),
          SizedBox(height: 12.h),
          Text(
            widget.senderName.toUpperCase(),
            style: AppTextStyles.h3.copyWith(fontSize: 18.sp),
          ),
          Text(
            "HAS SHARED A SUPPLEMENT WITH YOU",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildSuppSummary() {
    final name = _suppData!['name'] as String;
    final description = _suppData!['description'] as String?;
    final servingUnit = _suppData!['serving_unit'] ?? "Serving";
    final weightPerServing = (_suppData!['weight_per_serving'] as num?)?.toDouble() ?? 1.0;
    final weightUnit = _suppData!['weight_unit'] ?? "g";

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name.toUpperCase(), style: AppTextStyles.h3.copyWith(color: Colors.white, fontSize: 20.sp)),
          if (description != null && description.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Text(description, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 12.sp)),
          ],
          SizedBox(height: 20.h),
          Text(
            "1 $servingUnit = $weightPerServing $weightUnit",
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showInventoryPrompt() {
    final double defaultTotal = (_suppData!['total_stock'] as num?)?.toDouble() ?? 0.0;
    final double defaultRemaining = (_suppData!['remaining_stock'] as num?)?.toDouble() ?? 0.0;
    final String servingUnit = _suppData!['serving_unit'] ?? "Serving";
    final String weightUnit = _suppData!['weight_unit'] ?? "g";

    final TextEditingController totalController = TextEditingController(text: defaultTotal.toString());
    final TextEditingController remainingController = TextEditingController(text: defaultRemaining.toString());
    bool useServings = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text("SET INITIAL INVENTORY", style: AppTextStyles.h3),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "ADJUST STOCK VALUES BEFORE ADDING TO LIBRARY.",
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
              ),
              SizedBox(height: 20.h),
              
              // Unit Toggle
              Container(
                height: 34.h,
                padding: EdgeInsets.all(2.r),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10.r)),
                child: Row(
                  children: [
                    Expanded(child: _buildUnitBtn(servingUnit.toUpperCase(), useServings, () => setModalState(() => useServings = true))),
                    Expanded(child: _buildUnitBtn(weightUnit.toUpperCase(), !useServings, () => setModalState(() => useServings = false))),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              _buildStockField("TOTAL STOCK (${useServings ? servingUnit : weightUnit})", totalController),
              SizedBox(height: 12.h),
              _buildStockField("REMAINING STOCK (${useServings ? servingUnit : weightUnit})", remainingController),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("CANCEL", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
              onPressed: () async {
                final double total = double.tryParse(totalController.text) ?? defaultTotal;
                final double remaining = double.tryParse(remainingController.text) ?? defaultRemaining;

                final updatedData = Map<String, dynamic>.from(_suppData!);
                // Convert back to base weight if user was entering in servings
                final double weightPerServing = (updatedData['weight_per_serving'] as num?)?.toDouble() ?? 1.0;
                
                updatedData['total_stock'] = useServings ? (total * weightPerServing) : total;
                updatedData['remaining_stock'] = useServings ? (remaining * weightPerServing) : remaining;

                await context.read<SupplementProvider>().importSharedSupplement(updatedData);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("SUPPLEMENT ADDED TO LIBRARY")),
                  );
                  context.go('/tracker/supplement?tab=2');
                }
              },
              child: Text("SAVE", style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: active ? AppColors.crimson : Colors.transparent, borderRadius: BorderRadius.circular(8.r)),
        child: Text(label, style: AppTextStyles.labelSmall.copyWith(color: active ? Colors.white : AppColors.textSecondary, fontSize: 9.sp, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStockField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall.copyWith(fontSize: 8.sp, color: AppColors.textSecondary.withOpacity(0.5))),
        SizedBox(height: 4.h),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.crimson,
            minimumSize: Size(double.infinity, 56.h),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          ),
          onPressed: _showInventoryPrompt,
          child: Text("ADD TO LIBRARY", style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
        SizedBox(height: 12.h),
        TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: Text("CANCEL", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  Widget _buildExpiredState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(40.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_off_rounded, color: AppColors.textSecondary.withOpacity(0.2), size: 80.r),
              SizedBox(height: 24.h),
              Text("LINK EXPIRED", style: AppTextStyles.h2.copyWith(letterSpacing: 4)),
              SizedBox(height: 16.h),
              Text(
                "THIS SHARED SUPPLEMENT IS NO LONGER AVAILABLE.",
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
              SizedBox(height: 40.h),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.surface, minimumSize: Size(200.w, 50.h)),
                onPressed: () => context.go(AppRoutes.home),
                child: Text("RETURN TO HOME", style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
