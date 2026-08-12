import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';

class ImportStackScreen extends StatefulWidget {
  final String shareId;
  final String senderName;

  const ImportStackScreen({super.key, required this.shareId, required this.senderName});

  @override
  State<ImportStackScreen> createState() => _ImportStackScreenState();
}

class _ImportStackScreenState extends State<ImportStackScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _stackData;
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
          _stackData = data;
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

    if (_isExpired || _stackData == null) {
      return _buildExpiredState();
    }

    final List items = _stackData!['items'] as List;

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
                      "STACK COMPONENTS",
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 2),
                    ),
                    SizedBox(height: 16.h),
                    ...items.map((item) => _buildItemCard(item)),
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
          "SHARED STACK",
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
          Icon(Icons.layers_rounded, color: AppColors.crimson, size: 40.r),
          SizedBox(height: 12.h),
          Text(
            widget.senderName.toUpperCase(),
            style: AppTextStyles.h3.copyWith(fontSize: 18.sp),
          ),
          Text(
            "HAS SHARED A SUPPLEMENT STACK WITH YOU",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.5), fontSize: 10.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(dynamic item) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: AppColors.crimson, size: 16.r),
          SizedBox(width: 12.w),
          Text(
            item['name'].toString().toUpperCase(),
            style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showInventoryPrompt() {
    final List items = _stackData!['items'] as List;
    final List<TextEditingController> totalControllers = [];
    final List<TextEditingController> remainingControllers = [];
    final List<bool> useServingsList = [];

    for (var item in items) {
      final double defaultTotal = (item['total_stock'] as num?)?.toDouble() ?? 0.0;
      final double defaultRemaining = (item['remaining_stock'] as num?)?.toDouble() ?? 0.0;
      totalControllers.add(TextEditingController(text: defaultTotal.toString()));
      remainingControllers.add(TextEditingController(text: defaultRemaining.toString()));
      useServingsList.add(true);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: AppColors.surface,
          insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 40.h),
          title: Text("SET COMPONENT INVENTORY", style: AppTextStyles.h3),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "ADJUST STOCK FOR EACH SUPPLEMENT IN THIS STACK:",
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                ),
                SizedBox(height: 20.h),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final bool useServings = useServingsList[index];
                      final String servingUnit = item['serving_unit'] ?? "Serving";
                      final String weightUnit = item['weight_unit'] ?? "g";

                      return Padding(
                        padding: EdgeInsets.only(bottom: 24.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['name'].toString().toUpperCase(),
                                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                // Mini Unit Toggle
                                Container(
                                  height: 28.h,
                                  padding: EdgeInsets.all(2.r),
                                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8.r)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _buildMiniUnitBtn(servingUnit, useServings, () => setModalState(() => useServingsList[index] = true)),
                                      _buildMiniUnitBtn(weightUnit, !useServings, () => setModalState(() => useServingsList[index] = false)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                Expanded(child: _buildStockField("TOTAL (${useServings ? servingUnit : weightUnit})", totalControllers[index])),
                                SizedBox(width: 12.w),
                                Expanded(child: _buildStockField("REMAINING (${useServings ? servingUnit : weightUnit})", remainingControllers[index])),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("CANCEL", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
              onPressed: () async {
                final updatedItems = [];
                for (int i = 0; i < items.length; i++) {
                  final double valTotal = double.tryParse(totalControllers[i].text) ?? 0.0;
                  final double valRemaining = double.tryParse(remainingControllers[i].text) ?? 0.0;
                  final double weightPerServing = (items[i]['weight_per_serving'] as num?)?.toDouble() ?? 1.0;
                  
                  final updatedItem = Map<String, dynamic>.from(items[i]);
                  updatedItem['total_stock'] = useServingsList[i] ? (valTotal * weightPerServing) : valTotal;
                  updatedItem['remaining_stock'] = useServingsList[i] ? (valRemaining * weightPerServing) : valRemaining;
                  updatedItems.add(updatedItem);
                }

                final updatedData = Map<String, dynamic>.from(_stackData!);
                updatedData['items'] = updatedItems;

                await context.read<SupplementProvider>().importSharedStack(updatedData);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("STACK SAVED TO LIBRARY")),
                  );
                  context.go('/tracker/supplement?tab=1');
                }
              },
              child: Text("SAVE ALL", style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniUnitBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: active ? AppColors.crimson : Colors.transparent, borderRadius: BorderRadius.circular(6.r)),
        child: Text(label.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: active ? Colors.white : AppColors.textSecondary, fontSize: 8.sp, fontWeight: FontWeight.bold)),
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
          child: Text("SAVE TO LIBRARY", style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
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
                "THIS SHARED STACK IS NO LONGER AVAILABLE.",
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
