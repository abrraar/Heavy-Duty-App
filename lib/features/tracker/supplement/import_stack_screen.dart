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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 600;
            return Column(
              children: [
                _buildHeader(isCompact),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 24.w : 24.0, 
                      vertical: isCompact ? 20.h : 20.0
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSenderInfo(isCompact),
                        SizedBox(height: isCompact ? 32.h : 32.0),
                        Text(
                          "STACK COMPONENTS",
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary, 
                            letterSpacing: 2,
                            fontSize: isCompact ? null : 11.0,
                          ),
                        ),
                        SizedBox(height: isCompact ? 16.h : 16.0),
                        ...items.map((item) => _buildItemCard(item, isCompact)),
                        SizedBox(height: isCompact ? 40.h : 40.0),
                        _buildActions(isCompact),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildHeader(bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 24.h : 24.0, 
        horizontal: isCompact ? 24.w : 24.0
      ),
      child: Text(
        "SHARED STACK",
        textAlign: TextAlign.center,
        style: AppTextStyles.h2.copyWith(
          color: AppColors.white, 
          fontWeight: FontWeight.w500, 
          letterSpacing: 2,
          fontSize: isCompact ? null : 20.0,
        ),
      ),
    );
  }

  Widget _buildSenderInfo(bool isCompact) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(Icons.layers_rounded, color: AppColors.crimson, size: isCompact ? 40.r : 36.0),
          SizedBox(height: isCompact ? 12.h : 12.0),
          Text(
            widget.senderName.toUpperCase(),
            style: AppTextStyles.h3.copyWith(fontSize: isCompact ? 18.sp : 16.0),
          ),
          Text(
            "HAS SHARED A SUPPLEMENT STACK WITH YOU",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary.withOpacity(0.5), 
              fontSize: isCompact ? 10.sp : 11.0
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(dynamic item, bool isCompact) {
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 12.h : 10.0),
      padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: AppColors.crimson, size: isCompact ? 16.r : 16.0),
          SizedBox(width: isCompact ? 12.w : 12.0),
          Text(
            item['name'].toString().toUpperCase(),
            style: AppTextStyles.labelMedium.copyWith(
              color: Colors.white, 
              fontWeight: FontWeight.w500,
              fontSize: isCompact ? null : 14.0,
            ),
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
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          return StatefulBuilder(
            builder: (context, setModalState) => AlertDialog(
              backgroundColor: AppColors.surface,
              insetPadding: EdgeInsets.symmetric(
                horizontal: isCompact ? 20.w : 40.0, 
                vertical: isCompact ? 40.h : 40.0
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0)),
              title: Text("SET COMPONENT INVENTORY", style: AppTextStyles.h3.copyWith(
                fontSize: isCompact ? null : 18.0
              )),
              content: SizedBox(
                width: isCompact ? double.maxFinite : 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "ADJUST STOCK FOR EACH SUPPLEMENT IN THIS STACK:",
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: isCompact ? null : 12.0,
                      ),
                    ),
                    SizedBox(height: isCompact ? 20.h : 20.0),
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
                            padding: EdgeInsets.only(bottom: isCompact ? 24.h : 20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['name'].toString().toUpperCase(),
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.white, 
                                          fontWeight: FontWeight.w500,
                                          fontSize: isCompact ? null : 12.0,
                                        ),
                                      ),
                                    ),
                                    // Mini Unit Toggle
                                    Container(
                                      height: isCompact ? 28.h : 26.0,
                                      padding: EdgeInsets.all(isCompact ? 2.r : 2.0),
                                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0)),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildMiniUnitBtn(servingUnit, useServings, () => setModalState(() => useServingsList[index] = true), isCompact),
                                          _buildMiniUnitBtn(weightUnit, !useServings, () => setModalState(() => useServingsList[index] = false), isCompact),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isCompact ? 12.h : 10.0),
                                Row(
                                  children: [
                                    Expanded(child: _buildStockField("TOTAL (${useServings ? servingUnit : weightUnit})", totalControllers[index], isCompact)),
                                    SizedBox(width: isCompact ? 12.w : 12.0),
                                    Expanded(child: _buildStockField("REMAINING (${useServings ? servingUnit : weightUnit})", remainingControllers[index], isCompact)),
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
                  child: Text("CANCEL", style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: isCompact ? null : 12.0,
                  )),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.crimson,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 8.r : 8.0)),
                  ),
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
                  child: Text("SAVE ALL", style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white, 
                    fontWeight: FontWeight.w500,
                    fontSize: isCompact ? null : 12.0,
                  )),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildMiniUnitBtn(String label, bool active, VoidCallback onTap, bool isCompact) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.w : 8.0),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: active ? AppColors.crimson : Colors.transparent, borderRadius: BorderRadius.circular(isCompact ? 6.r : 4.0)),
        child: Text(label.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(
          color: active ? Colors.white : AppColors.textSecondary, 
          fontSize: isCompact ? 8.sp : 9.0, 
          fontWeight: FontWeight.w500
        )),
      ),
    );
  }

  Widget _buildStockField(String label, TextEditingController controller, bool isCompact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall.copyWith(
          fontSize: isCompact ? 8.sp : 9.0, 
          color: AppColors.textSecondary.withOpacity(0.5)
        )),
        SizedBox(height: isCompact ? 4.h : 4.0),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
            color: Colors.white,
            fontSize: isCompact ? null : 14.0,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isCompact ? 12.w : 12.0, 
              vertical: isCompact ? 8.h : 8.0
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(bool isCompact) {
    return Column(
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.crimson,
            minimumSize: Size(double.infinity, isCompact ? 56.h : 50.0),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0)),
          ),
          onPressed: _showInventoryPrompt,
          child: Text("SAVE TO LIBRARY", style: AppTextStyles.labelMedium.copyWith(
            color: Colors.white, 
            fontWeight: FontWeight.w500,
            fontSize: isCompact ? null : 14.0,
          )),
        ),
        SizedBox(height: isCompact ? 12.h : 12.0),
        TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: Text("CANCEL", style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: isCompact ? null : 12.0,
          )),
        ),
      ],
    );
  }

  Widget _buildExpiredState() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          return Center(
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 40.r : 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isCompact ? double.infinity : 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_off_rounded, color: AppColors.textSecondary.withOpacity(0.2), size: isCompact ? 80.r : 70.0),
                    SizedBox(height: isCompact ? 24.h : 20.0),
                    Text(
                      "LINK EXPIRED", 
                      style: AppTextStyles.h2.copyWith(
                        letterSpacing: 4,
                        fontSize: isCompact ? null : 22.0,
                      )
                    ),
                    SizedBox(height: isCompact ? 16.h : 16.0),
                    Text(
                      "THIS SHARED STACK IS NO LONGER AVAILABLE.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary, 
                        height: 1.5,
                        fontSize: isCompact ? null : 12.0,
                      ),
                    ),
                    SizedBox(height: isCompact ? 40.h : 40.0),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.surface, 
                        minimumSize: Size(isCompact ? 200.w : 180.0, isCompact ? 50.h : 46.0)
                      ),
                      onPressed: () => context.go(AppRoutes.home),
                      child: Text("RETURN TO HOME", style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: isCompact ? null : 12.0,
                      )),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}
