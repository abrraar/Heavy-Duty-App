import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
    required this.intensity,
    required this.imagePath,
    this.about = "",
    this.initialAspectRatio,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final List<String> _allMuscles = [
    'Chest', 'Back', 'Legs', 'Calf', 'Abdominals', 'Shoulder', 'Biceps', 'Triceps'
  ];

  double? _calculatedHeight;

  @override
  void initState() {
    super.initState();
    // If we passed a ratio from the list, set the height immediately
    if (widget.initialAspectRatio != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final double screenWidth = MediaQuery.of(context).size.width;
        setState(() {
          _calculatedHeight = (screenWidth / widget.initialAspectRatio!).clamp(250.h, 450.h);
        });
      });
    }
  }

  void _updateImageHeight(String url) {
    if (url.isEmpty || !url.startsWith('http')) return;
    
    final image = Image.network(url);
    image.image.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          final double screenWidth = MediaQuery.of(context).size.width;
          final double aspectRatio = info.image.width / info.image.height;
          setState(() {
            _calculatedHeight = (screenWidth / aspectRatio).clamp(250.h, 450.h);
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double standardHeight = 250.h;
    final double screenWidth = MediaQuery.of(context).size.width;

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

          // ELITE INSTANT HEIGHT LOGIC (METHOD A)
          // Priority 1: Use the height already calculated (State persistence)
          // Priority 2: Calculate from the passed initialAspectRatio (Instant navigation)
          // Priority 3: Fallback to standard 250.h
          double dynamicHeight = standardHeight;
          if (_calculatedHeight != null) {
            dynamicHeight = _calculatedHeight!;
          } else if (widget.initialAspectRatio != null) {
            dynamicHeight = (screenWidth / widget.initialAspectRatio!).clamp(250.h, 450.h);
          }

          // Trigger dimension resolution if we don't have a value yet
          if (_calculatedHeight == null && (template.imageUrl ?? "").startsWith('http')) {
            _updateImageHeight(template.imageUrl!);
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
              setState(() => _calculatedHeight = null); // Reset for re-calculation
              await exProvider.forceRefresh();
            },
            color: AppColors.crimson,
            backgroundColor: AppColors.surface,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                _buildSliverAppBar(context, template, exProvider, dynamicHeight),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildIntensityAndAbout(template),
                        SizedBox(height: 30.h),
                        _buildProgressGraphSection(relevantLogs),
                        SizedBox(height: 30.h),
                        _buildHistoryLogs(relevantLogs),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ExerciseTemplate template, ExerciseProvider exProvider, double height) {
    return SliverAppBar(
      expandedHeight: height,
      backgroundColor: AppColors.background,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: Container(
          padding: EdgeInsets.all(8.r),
          decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (!template.isDefault) ...[
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8.r),
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: Icon(Icons.ios_share_rounded, color: Colors.white, size: 18.r),
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
            padding: EdgeInsets.only(right: 12.w),
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(8.r),
                decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
                child: Icon(Icons.edit_rounded, color: Colors.white, size: 18.r),
              ),
              onPressed: () => _showGlobalEditSheet(template, exProvider),
            ),
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 40.w, right: 40.w, bottom: 16.h),
        title: Text(
          template.name.toUpperCase(),
          textAlign: TextAlign.center,
          style: AppTextStyles.h3.copyWith(fontSize: 18.sp, color: Colors.white, letterSpacing: 1.2),
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
                debugPrint("Detail Screen Image Error: $error | URL: $url");
                return Container(
                  color: AppColors.background,
                  child: Center(
                    child: Text(
                      'IMAGE NOT FOUND PULL DOWN TO REFRESH',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10.sp,
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

  Widget _buildIntensityAndAbout(ExerciseTemplate template) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('METABOLIC DEMAND', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
            _buildFireRating(template.intensity),
          ],
        ),
        SizedBox(height: 20.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ABOUT THE MOVEMENT', style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson)),
              SizedBox(height: 8.h),
              Opacity(
                opacity: (template.aboutTheMovement ?? "").isNotEmpty ? 1.0 : 0.4,
                child: ExpandableAboutText(
                  text: (template.aboutTheMovement ?? "").isNotEmpty 
                      ? template.aboutTheMovement!
                      : "NO COACHING NOTES HAVE BEEN ADDED FOR THIS EXERCISE. YOU CAN ADD THEM BY EDITING THE EXERCISE DETAILS.",
                ),
              ),
              if (!template.isDefault) ...[
                SizedBox(height: 16.h),
                Divider(color: AppColors.white.withValues(alpha: 0.05)),
                SizedBox(height: 12.h),
                Text('TARGET MUSCLES', style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson)),
                SizedBox(height: 8.h),
                Text(
                  template.targetMuscles?.toUpperCase() ?? "NOT SPECIFIED",
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showGlobalEditSheet(ExerciseTemplate template, ExerciseProvider exProvider) {
    final nameController = TextEditingController(text: template.name);
    final aboutController = TextEditingController(text: template.aboutTheMovement);
    final Set<String> selectedMuscles = template.targetMuscles?.split(', ').toSet() ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          ExerciseType calculatedType = selectedMuscles.length > 1 ? ExerciseType.compound : ExerciseType.isolation;
          int calculatedIntensity = 1;
          if (selectedMuscles.isEmpty) calculatedIntensity = 1;
          else if (selectedMuscles.length == 1) calculatedIntensity = 2;
          else if (selectedMuscles.length == 2) calculatedIntensity = 3;
          else if (selectedMuscles.length <= 4) calculatedIntensity = 4;
          else calculatedIntensity = 5;

          bool isReady = selectedMuscles.isNotEmpty && nameController.text.trim().isNotEmpty;
          String buttonText = nameController.text.isEmpty ? "ENTER EXERCISE NAME" : (selectedMuscles.isEmpty ? "SELECT TARGET MUSCLES" : "SAVE CHANGES");

          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
                  child: Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.2), borderRadius: BorderRadius.circular(2.r)),
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(24.r, 0, 24.r, 24.r),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("EDIT EXERCISE", style: AppTextStyles.h3),
                        SizedBox(height: 24.h),
                        _buildEditTextField("EXERCISE NAME", nameController, "e.g. Hammer Curls"),
                        SizedBox(height: 24.h),
                        _buildEditTextField("ABOUT THE MOVEMENT (OPTIONAL)", aboutController, "Describe the proper form...", maxLines: 3),
                        SizedBox(height: 24.h),
                        Text("TARGET MUSCLES", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
                        SizedBox(height: 12.h),
                        Wrap(
                          spacing: 8.w,
                          runSpacing: 8.h,
                          children: _allMuscles.map((m) {
                            bool isSelected = selectedMuscles.contains(m);
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  if (isSelected) selectedMuscles.remove(m);
                                  else selectedMuscles.add(m);
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.crimson : AppColors.surfaceLight.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8.r),
                                  border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.05)),
                                ),
                                child: Text(m.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 9.sp)),
                              ),
                            );
                          }).toList(),
                        ),
                        SizedBox(height: 24.h),
                        Container(
                          padding: EdgeInsets.all(16.r),
                          decoration: BoxDecoration(
                            color: AppColors.background.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.white.withOpacity(0.03)),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("TYPE", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: calculatedType == ExerciseType.compound ? AppColors.crimson.withOpacity(0.1) : AppColors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      calculatedType.name.toUpperCase(),
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: calculatedType == ExerciseType.compound ? AppColors.crimson : AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("DEMAND", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
                                  _buildFireRating(calculatedIntensity),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 32.h),
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
                            Navigator.pop(context);
                            if (oldName.trim().toUpperCase() != newName) {
                              context.read<CycleProvider>().renameExerciseGlobally(oldName, newName);
                            }
                            await exProvider.addTemplate(updated);
                          } : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            height: 54.h,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isReady ? AppColors.crimson : AppColors.surfaceLight.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.r),
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
    );
  }

  Widget _buildEditTextField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.2), fontSize: 12.sp),
            filled: true,
            fillColor: AppColors.background.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressGraphSection(List<ExerciseLog> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('PROGRESS ANALYTICS', style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w900)),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.crimson.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                "DATA TRENDS",
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontSize: 8.sp, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        SizedBox(height: 15.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 24.h),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24.r),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: logs.isEmpty 
            ? SizedBox(
                height: 200.h,
                child: Center(child: Text("NO PERFORMANCE DATA RECORDED YET", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5)))),
              )
            : ExerciseAnalyticalGraph(
                logs: logs.reversed.toList(), // Analytics widget handles the last-to-first sorting internally
                onPointSelected: (idx) {},
              ),
        ),
      ],
    );
  }

  Widget _buildHistoryLogs(List<ExerciseLog> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECENT SESSIONS', style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.5)),
        SizedBox(height: 15.h),
        if (logs.isEmpty)
           Padding(
             padding: EdgeInsets.symmetric(vertical: 20.h),
             child: Center(child: Text("NO RECENT SESSIONS FOUND", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.3)))),
           )
        else
          ...logs.take(5).map((log) {
            String diffText = "";
            final index = logs.indexOf(log);
            if (index < logs.length - 1) {
              final prev = logs[index + 1];
              final wDiff = log.weightKg - prev.weightKg;
              final rDiff = log.positiveReps - prev.positiveReps;
              if (wDiff > 0) diffText = "+${wDiff.toStringAsFixed(1)}KG LOAD INCREASE";
              else if (rDiff > 0) diffText = "+$rDiff REPS INCREASE";
              else if (wDiff == 0 && rDiff == 0) diffText = "MAINTAINED PERFORMANCE";
              else diffText = "PERFORMANCE DECREASE";
            } else {
              diffText = "BASELINE SESSION";
            }
            return _buildLogEntry(log, diffText);
          }),
      ],
    );
  }

  Widget _buildLogEntry(ExerciseLog log, String note) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16.r),
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
                  Text(DateFormat('MMM dd').format(log.timestamp).toUpperCase(), style: AppTextStyles.labelMedium),
                  Text(note, style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontSize: 9.sp, fontWeight: FontWeight.w500)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${double.parse(log.weightKg.toStringAsFixed(3)).toString()} KG', style: AppTextStyles.h3.copyWith(fontSize: 16.sp)),
                  Text('${log.positiveReps} POS REPS', style: AppTextStyles.labelSmall.copyWith(color: Colors.blueAccent, fontSize: 10.sp, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          if (log.negativeReps > 0 || log.staticHoldSeconds > 0 || log.forcedReps > 0) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: Divider(color: AppColors.white.withValues(alpha: 0.05), height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (log.negativeReps > 0) _miniSpec(log.negativeReps.toString(), "NEG", Colors.tealAccent),
                if (log.staticHoldSeconds > 0) _miniSpec("${log.staticHoldSeconds}S", "STATIC", Colors.orangeAccent),
                if (log.forcedReps > 0) _miniSpec(log.forcedReps.toString(), "FORCED", Colors.purpleAccent),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _miniSpec(String val, String label, Color color) {
    return Column(
      children: [
        Text(val, style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w500)),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: color, fontSize: 8.sp, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildFireRating(int score) {
    return Row(
      children: List.generate(5, (index) => Icon(
        Icons.local_fire_department_rounded,
        size: 16.r,
        color: index < score ? AppColors.crimson : AppColors.white.withValues(alpha: 0.1),
      )),
    );
  }
}
