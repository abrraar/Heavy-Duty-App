import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/constants/dimensions.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/exercise_log.dart';
import 'package:heavy_duty/features/exercise/provider/exercise_provider.dart';
import 'package:heavy_duty/features/exercise/model/exercise_template.dart';
import 'package:heavy_duty/features/exercise/widgets/exercise_analytical_graph.dart';
import 'package:heavy_duty/features/exercise/widgets/expandable_about_text.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:heavy_duty/core/utils/adaptive_utils.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final String exerciseId;
  final String exerciseName;
  final int intensity;
  final String imagePath;
  final String about;
  final double? initialAspectRatio;
  final bool isEmbedded;

  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.intensity,
    required this.imagePath,
    this.about = "",
    this.initialAspectRatio,
    this.isEmbedded = false,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final List<String> _allMuscles = [
    'Chest', 'Back', 'Legs', 'Calf', 'Abdominals', 'Shoulder', 'Biceps', 'Triceps'
  ];

  double? _imageAspectRatio;

  @override
  void initState() {
    super.initState();
    _imageAspectRatio = widget.initialAspectRatio;
  }

  void _resolveImageRatio(String url) {
    if (url.isEmpty || !url.startsWith('http')) return;
    
    final image = Image.network(url);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _imageAspectRatio = info.image.width / info.image.height;
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer2<CycleProvider, ExerciseProvider>(
        builder: (context, cycleProv, exProvider, _) {
          final template = exProvider.templates.firstWhere(
            (t) => t.id == widget.exerciseId,
            orElse: () {
              final cleanName = widget.exerciseName.trim().toUpperCase();
              return exProvider.templates.firstWhere(
                (t) => t.name.trim().toUpperCase() == cleanName,
                orElse: () => ExerciseTemplate(
                  id: widget.exerciseId,
                  name: widget.exerciseName,
                  intensity: widget.intensity,
                  aboutTheMovement: widget.about,
                ),
              );
            },
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              final double paneWidth = constraints.maxWidth;
              final double deviceWidth = MediaQuery.of(context).size.width;
              final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
              
              final bool isTabletOrFoldable = deviceWidth >= 600;
              final bool isCompact = paneWidth < 600 && !isLandscape && !isTabletOrFoldable;

              // AUTO-POP ON ROTATION TO LANDSCAPE (ONLY IF NOT EMBEDDED)
              final bool isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
              if (isCurrent && isLandscape && isTabletOrFoldable && !widget.isEmbedded) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                });
              }

              final double hPad = isTabletOrFoldable
                  ? (paneWidth - kMaxContentWidth).clamp(24.0, double.infinity) / 2
                  : 20.w;

              // ADAPTIVE PHOTO HEIGHT LOGIC
              // On tablets/foldables, we allow more height to avoid cropping, especially in portrait.
              final double maxTabletHeight = isLandscape ? 450.0 : 600.0;
              final double standardHeight = isTabletOrFoldable ? 350.0 : 250.h;

              double dynamicHeight = standardHeight;
              
              // Use the best available aspect ratio
              final double? effectiveRatio = _imageAspectRatio ?? template.aspectRatio;

              if (effectiveRatio != null && effectiveRatio > 0) {
                double targetHeight = paneWidth / effectiveRatio;
                if (isTabletOrFoldable) {
                  // Generous clamping for tablets
                  dynamicHeight = targetHeight.clamp(250.0, maxTabletHeight);
                } else {
                  // Standard phone clamping
                  dynamicHeight = targetHeight.clamp(200.h, 450.h);
                }
              }

              // Trigger dimension resolution if we don't have a value yet
              if (effectiveRatio == null && (template.imageUrl ?? "").startsWith('http')) {
                _resolveImageRatio(template.imageUrl!);
              }

              final cleanNameForLogs = template.name.trim().toUpperCase();
              final relevantLogs = cycleProv.logs.where((log) {
                try {
                  final exerciseDef = cycleProv.exercises.firstWhere((e) => e.id == log.exerciseId);
                  return exerciseDef.name.toUpperCase() == cleanNameForLogs;
                } catch (e) {
                  return false;
                }
              }).toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

              return RefreshIndicator(
                onRefresh: () async {
                  setState(() => _imageAspectRatio = null);
                  await exProvider.forceRefresh();
                },
                color: AppColors.crimson,
                backgroundColor: AppColors.surface,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  slivers: [
                    _buildSliverAppBar(context, template, exProvider, dynamicHeight, hPad, isTabletOrFoldable),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: hPad, 
                          vertical: isTabletOrFoldable ? 16.0 : 20.h
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildIntensityAndAbout(template, isTabletOrFoldable),
                            SizedBox(height: isTabletOrFoldable ? 24.0 : 30.h),
                            _buildProgressGraphSection(relevantLogs, isTabletOrFoldable),
                            SizedBox(height: isTabletOrFoldable ? 24.0 : 30.h),
                            _buildHistoryLogs(relevantLogs, isTabletOrFoldable),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ExerciseTemplate template, ExerciseProvider exProvider, double height, double hPad, bool isTablet) {
    return SliverAppBar(
      expandedHeight: height,
      backgroundColor: AppColors.background,
      elevation: 0,
      pinned: true,
      leading: widget.isEmbedded 
          ? null 
          : IconButton(
              icon: Container(
                padding: EdgeInsets.all(isTablet ? 8.0 : 8.r),
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: isTablet ? 16.0 : 18.r),
              ),
              onPressed: () => Navigator.pop(context),
            ),
      actions: [
        if (!template.isDefault) ...[
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(isTablet ? 8.0 : 8.r),
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: Icon(Icons.ios_share_rounded, color: Colors.white, size: isTablet ? 16.0 : 18.r),
              ),
              onPressed: () async {
                final authProvider = context.read<AuthProvider>();
                final userName = authProvider.displayName;
                EliteSnackbar.show(context, "GENERATING SHAREABLE LINK...");
                final link = await exProvider.generateShareableLink(template, userName);
                if (link != null) {
                  await Share.share(
                    "CHECK OUT THIS EXERCISE SHARED BY $userName IN HEAVY DUTY:\n\n$link",
                    subject: "EXERCISE SHARED BY $userName",
                  );
                }
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: isTablet ? 16.0 : 12.w),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(isTablet ? 8.0 : 8.r),
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: Icon(Icons.edit_rounded, color: Colors.white, size: isTablet ? 16.0 : 18.r),
              ),
              onPressed: () => _showGlobalEditSheet(template, exProvider, isTablet),
            ),
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 40.0, right: 40.0, bottom: isTablet ? 12.0 : 16.h),
        expandedTitleScale: 1.0,
        title: Text(
          template.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTextStyles.h3.copyWith(
            fontSize: isTablet ? 18.0 : 18.sp,
            color: Colors.white, 
            letterSpacing: 1.2
          ),
        ),
        centerTitle: true,
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: template.imageUrl ?? '',
              fit: BoxFit.cover,
              placeholder: (context, url) => Shimmer.fromColors(
                baseColor: AppColors.surfaceLight.withOpacity(0.1),
                highlightColor: AppColors.surfaceLight.withOpacity(0.2),
                child: Container(color: Colors.white),
              ),
              errorWidget: (context, url, error) {
                final bool isDefault = template.isDefault;
                return Container(
                  color: AppColors.background,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40.0),
                      child: Text(
                        isDefault 
                            ? 'IMAGE NOT FOUND PULL DOWN TO REFRESH'
                            : 'IMAGE CAPTURE & UPLOAD FEATURE WILL BE AVAILABLE IN FUTURE UPDATES',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.4),
                          fontSize: isTablet ? 10.0 : 10.sp,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.8),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntensityAndAbout(ExerciseTemplate template, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('METABOLIC DEMAND', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: isTablet ? 10.0 : null)),
            _buildFireRating(template.intensity, isTablet),
          ],
        ),
        SizedBox(height: isTablet ? 12.0 : 20.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isTablet ? 16.0 : 16.r),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ABOUT THE MOVEMENT', style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson, fontSize: isTablet ? 11.0 : null)),
              SizedBox(height: 8.0),
              Opacity(
                opacity: (template.aboutTheMovement ?? "").isNotEmpty ? 1.0 : 0.4,
                child: ExpandableAboutText(
                  text: (template.aboutTheMovement ?? "").isNotEmpty 
                      ? template.aboutTheMovement!
                      : "NO COACHING NOTES HAVE BEEN ADDED FOR THIS EXERCISE. YOU CAN ADD THEM BY EDITING THE EXERCISE DETAILS.",
                ),
              ),
              if (!template.isDefault) ...[
                SizedBox(height: isTablet ? 12.0 : 16.h),
                Divider(color: AppColors.white.withValues(alpha: 0.05)),
                SizedBox(height: isTablet ? 10.0 : 12.h),
                Text('TARGET MUSCLES', style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson, fontSize: isTablet ? 11.0 : null)),
                SizedBox(height: 8.0),
                Text(
                  template.targetMuscles?.toUpperCase() ?? "NOT SPECIFIED",
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: isTablet ? 10.0 : 11.sp),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showGlobalEditSheet(ExerciseTemplate template, ExerciseProvider exProvider, bool isTablet) {
    final nameController = TextEditingController(text: template.name);
    final aboutController = TextEditingController(text: template.aboutTheMovement);
    final Set<String> selectedMuscles = template.targetMuscles?.split(', ').toSet() ?? {};

    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isSheetCompact = constraints.maxWidth < 600 && !isSideSheet;
          final double sheetWidth = isSideSheet ? constraints.maxWidth : 600.0;

          return Align(
            alignment: isSideSheet ? Alignment.center : Alignment.bottomCenter,
            child: SizedBox(
              width: sheetWidth,
              child: StatefulBuilder(
                builder: (context, setModalState) {
                  ExerciseType calculatedType = selectedMuscles.length > 1 ? ExerciseType.compound : ExerciseType.isolation;
                  int calculatedIntensity = 1;
                  if (selectedMuscles.isEmpty) {
                    calculatedIntensity = 1;
                  } else if (selectedMuscles.length == 1) calculatedIntensity = 2;
                  else if (selectedMuscles.length == 2) calculatedIntensity = 3;
                  else if (selectedMuscles.length <= 4) calculatedIntensity = 4;
                  else calculatedIntensity = 5;

                  bool isReady = selectedMuscles.isNotEmpty && nameController.text.trim().isNotEmpty;
                  String buttonText = nameController.text.isEmpty ? "ENTER EXERCISE NAME" : (selectedMuscles.isEmpty ? "SELECT TARGET MUSCLES" : "SAVE CHANGES");

                  return Container(
                    height: isSideSheet ? double.infinity : null,
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: isSideSheet 
                        ? const BorderRadius.horizontal(left: Radius.circular(24.0))
                        : BorderRadius.vertical(top: Radius.circular(isSheetCompact ? 32.r : 24.0)),
                    ),
                    child: Column(
                      mainAxisSize: isSideSheet ? MainAxisSize.max : MainAxisSize.min,
                      children: [
                        if (isSideSheet) SizedBox(height: 24.0),
                        if (!isSideSheet)
                          Padding(
                            padding: EdgeInsets.only(
                              top: isSheetCompact ? 12.h : 12.0, 
                              bottom: isSheetCompact ? 8.h : 8.0
                            ),
                            child: Center(
                              child: Container(
                                width: isSheetCompact ? 40.w : 40.0,
                                height: isSheetCompact ? 4.h : 4.0,
                                decoration: BoxDecoration(
                                  color: AppColors.textSecondary.withOpacity(0.2), 
                                  borderRadius: BorderRadius.circular(2.r)
                                ),
                              ),
                            ),
                          ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              isSheetCompact ? 24.r : 24.0, 
                              0, 
                              isSheetCompact ? 24.r : 24.0, 
                              isSheetCompact ? 24.r : 24.0
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "EDIT EXERCISE", 
                                      style: AppTextStyles.h3.copyWith(fontSize: isSheetCompact ? null : 18.0)
                                    ),
                                    if (isSideSheet)
                                      IconButton(
                                        icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
                                        onPressed: () => Navigator.pop(sheetContext),
                                      ),
                                  ],
                                ),
                                SizedBox(height: isSheetCompact ? 24.h : 20.0),
                                _buildEditTextField(
                                  "EXERCISE NAME", 
                                  nameController, 
                                  "e.g. Hammer Curls",
                                  isCompact: isSheetCompact,
                                ),
                                SizedBox(height: isSheetCompact ? 24.h : 20.0),
                                _buildEditTextField(
                                  "ABOUT THE MOVEMENT (OPTIONAL)", 
                                  aboutController, 
                                  "Describe the proper form...", 
                                  maxLines: 3,
                                  isCompact: isSheetCompact,
                                ),
                                SizedBox(height: isSheetCompact ? 24.h : 20.0),
                                Text(
                                  "TARGET MUSCLES", 
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary, 
                                    fontSize: isSheetCompact ? 10.sp : 10.0,
                                    fontWeight: FontWeight.w500,
                                  )
                                ),
                                SizedBox(height: isSheetCompact ? 12.h : 10.0),
                                Wrap(
                                  spacing: isSheetCompact ? 8.w : 8.0,
                                  runSpacing: isSheetCompact ? 8.h : 8.0,
                                  children: _allMuscles.map((m) {
                                    bool isSelected = selectedMuscles.contains(m);
                                    return GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          if (isSelected) {
                                            selectedMuscles.remove(m);
                                          } else {
                                            selectedMuscles.add(m);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isSheetCompact ? 12.w : 10.0, 
                                          vertical: isSheetCompact ? 6.h : 6.0
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(isSheetCompact ? 8.r : 8.0),
                                          border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.05)),
                                        ),
                                        child: Text(
                                          m.toUpperCase(), 
                                          style: AppTextStyles.labelSmall.copyWith(
                                            color: isSelected ? Colors.white : AppColors.textSecondary, 
                                            fontSize: isSheetCompact ? 9.sp : 9.0,
                                            fontWeight: FontWeight.w500,
                                          )
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                SizedBox(height: isSheetCompact ? 24.h : 20.0),
                                Container(
                                  padding: EdgeInsets.all(isSheetCompact ? 16.r : 16.0),
                                  decoration: BoxDecoration(
                                    color: AppColors.background.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 12.0),
                                    border: Border.all(color: AppColors.white.withOpacity(0.03)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "TYPE", 
                                            style: AppTextStyles.labelSmall.copyWith(
                                              color: AppColors.textSecondary, 
                                              fontSize: isSheetCompact ? 10.sp : 10.0,
                                              fontWeight: FontWeight.w500,
                                            )
                                          ),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isSheetCompact ? 8.w : 8.0, 
                                              vertical: isSheetCompact ? 2.h : 2.0
                                            ),
                                            decoration: BoxDecoration(
                                              color: calculatedType == ExerciseType.compound ? AppColors.crimson.withOpacity(0.1) : AppColors.white.withOpacity(0.05),
                                              borderRadius: BorderRadius.circular(isSheetCompact ? 4.r : 4.0),
                                            ),
                                            child: Text(
                                              calculatedType.name.toUpperCase(),
                                              style: AppTextStyles.labelSmall.copyWith(
                                                color: calculatedType == ExerciseType.compound ? AppColors.crimson : AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                                fontSize: isSheetCompact ? null : 10.0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: isSheetCompact ? 12.h : 10.0),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "DEMAND", 
                                            style: AppTextStyles.labelSmall.copyWith(
                                              color: AppColors.textSecondary, 
                                              fontSize: isSheetCompact ? 10.sp : 10.0,
                                              fontWeight: FontWeight.w500,
                                            )
                                          ),
                                          _buildFireRatingModalSheet(calculatedIntensity, isSheetCompact),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isSheetCompact ? 32.h : 24.0),
                                GestureDetector(
                                  onTap: isReady ? () async {
                                    final oldName = template.name;
                                    final newName = nameController.text.trim().toUpperCase();
                                    final newMuscles = selectedMuscles.join(', ');
                                    final updated = template.copyWith(
                                      name: newName,
                                      targetMuscles: newMuscles,
                                      type: calculatedType,
                                      intensity: calculatedIntensity,
                                      aboutTheMovement: aboutController.text.trim(),
                                    );
                                    Navigator.pop(sheetContext);
                                    if (oldName.trim().toUpperCase() != newName) {
                                      context.read<CycleProvider>().renameExerciseGlobally(oldName, newName);
                                    }
                                    await exProvider.addTemplate(updated);
                                  } : null,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: isSheetCompact ? 54.h : 48.0,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: isReady ? AppColors.crimson : AppColors.surfaceLight.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(isSheetCompact ? 12.r : 12.0),
                                      boxShadow: isReady ? [
                                        BoxShadow(color: AppColors.crimson.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
                                      ] : [],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      buttonText,
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: isReady ? Colors.white : AppColors.textSecondary.withOpacity(0.5),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1.2,
                                        fontSize: isSheetCompact ? null : 13.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFireRatingModalSheet(int score, bool isCompact) {
    return Row(
      children: List.generate(5, (index) => Icon(
        Icons.local_fire_department_rounded,
        size: isCompact ? 16.r : 16.0,
        color: index < score ? AppColors.crimson : AppColors.white.withOpacity(0.05),
      )),
    );
  }

  Widget _buildEditTextField(String label, TextEditingController controller, String hint, {int maxLines = 1, required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary, 
            fontSize: isCompact ? 10.sp : 10.0,
            fontWeight: FontWeight.w500,
          )
        ),
        SizedBox(height: isCompact ? 8.h : 6.0),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(color: Colors.white, fontSize: isCompact ? null : 14.0),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.2), fontSize: isCompact ? 12.sp : 14.0),
            filled: true,
            fillColor: AppColors.background.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0, vertical: isCompact ? 14.h : 12.0),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressGraphSection(List<ExerciseLog> logs, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PROGRESS ANALYTICS', style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w500, fontSize: isTablet ? 10.0 : null)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: AppColors.crimson.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Text(
                "DATA TRENDS",
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontSize: isTablet ? 7.0 : 8.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        SizedBox(height: isTablet ? 10.0 : 15.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isTablet ? 12.0 : 24.h),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24.0),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: logs.isEmpty 
            ? SizedBox(
                height: isTablet ? 120.0 : 200.h,
                child: Center(child: Text("NO PERFORMANCE DATA RECORDED YET", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: isTablet ? 9.0 : null))),
              )
            : ExerciseAnalyticalGraph(
                logs: logs.reversed.toList(),
                onPointSelected: (idx) {},
              ),
        ),
      ],
    );
  }

  Widget _buildHistoryLogs(List<ExerciseLog> logs, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECENT SESSIONS', style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.5, fontSize: isTablet ? 10.0 : null)),
        SizedBox(height: isTablet ? 10.0 : 15.h),
        if (logs.isEmpty)
           Padding(
             padding: EdgeInsets.symmetric(vertical: isTablet ? 12.0 : 20.h),
             child: Center(child: Text("NO RECENT SESSIONS FOUND", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.3), fontSize: isTablet ? 9.0 : null))),
           )
        else
          ...logs.take(5).map((log) {
            String diffText = "";
            final index = logs.indexOf(log);
            if (index < logs.length - 1) {
              final prev = logs[index + 1];
              final wDiff = log.weightKg - prev.weightKg;
              final rDiff = log.positiveReps - prev.positiveReps;
              if (wDiff > 0) {
                diffText = "+${wDiff.toStringAsFixed(1)}KG LOAD INCREASE";
              } else if (rDiff > 0) diffText = "+$rDiff REPS INCREASE";
              else if (wDiff == 0 && rDiff == 0) diffText = "MAINTAINED PERFORMANCE";
              else diffText = "PERFORMANCE DECREASE";
            } else {
              diffText = "BASELINE SESSION";
            }
            return _buildLogEntry(log, diffText, isTablet);
          }),
      ],
    );
  }

  Widget _buildLogEntry(ExerciseLog log, String note, bool isTablet) {
    return Container(
      margin: EdgeInsets.only(bottom: isTablet ? 8.0 : 12.h),
      padding: EdgeInsets.all(isTablet ? 12.0 : 16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('MMM dd').format(log.timestamp).toUpperCase(), style: AppTextStyles.labelMedium.copyWith(fontSize: isTablet ? 10.0 : 12.sp)),
                  Text(note, style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontSize: isTablet ? 8.0 : 9.sp, fontWeight: FontWeight.w500)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${double.parse(log.weightKg.toStringAsFixed(3)).toString()} KG', style: AppTextStyles.h3.copyWith(fontSize: isTablet ? 15.0 : 16.sp)),
                  Text('${log.positiveReps} POS REPS', style: AppTextStyles.labelSmall.copyWith(color: Colors.blueAccent, fontSize: isTablet ? 9.0 : 10.sp, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          if (log.negativeReps > 0 || log.staticHoldSeconds > 0 || log.forcedReps > 0) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: isTablet ? 8.0 : 12.h),
              child: Divider(color: AppColors.white.withValues(alpha: 0.05), height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (log.negativeReps > 0) _miniSpec(log.negativeReps.toString(), "NEG", Colors.tealAccent, isTablet),
                if (log.staticHoldSeconds > 0) _miniSpec("${log.staticHoldSeconds}S", "STATIC", Colors.orangeAccent, isTablet),
                if (log.forcedReps > 0) _miniSpec(log.forcedReps.toString(), "FORCED", Colors.purpleAccent, isTablet),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _miniSpec(String val, String label, Color color, bool isTablet) {
    return Column(
      children: [
        Text(val, style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w500, fontSize: isTablet ? 9.0 : 10.sp)),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: isTablet ? 7.0 : 8.sp, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildFireRating(int score, bool isTablet) {
    return Row(
      children: List.generate(5, (index) => Icon(
        Icons.local_fire_department_rounded,
        size: isTablet ? 12.0 : 14.r,
        color: index < score ? AppColors.crimson : AppColors.white.withValues(alpha: 0.1),
      )),
    );
  }
}
