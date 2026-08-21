import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/features/exercise/provider/exercise_provider.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_search_bar.dart';
import 'exercise_detail_screen.dart';
import 'model/exercise_template.dart';
import 'package:heavy_duty/features/exercise/widgets/add_custom_exercise_sheet.dart';

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({super.key});

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isCustomTab = false;
  String _searchQuery = "";
  
  // Filter States
  final Set<int> _selectedDemands = {};
  final Set<String> _selectedMuscles = {};
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _isCustomTab = _tabController.index == 1);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ExerciseProvider>(
      builder: (context, provider, _) {
        List<ExerciseTemplate> filterList(List<ExerciseTemplate> original) {
          var list = original.where((t) {
            final matchesSearch = t.name.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesDemand = _selectedDemands.isEmpty || _selectedDemands.contains(t.intensity);
            
            bool matchesMuscle = _selectedMuscles.isEmpty;
            if (!matchesMuscle && t.targetMuscles != null) {
              final targets = t.targetMuscles!.split(',').map((m) => m.trim().toUpperCase());
              matchesMuscle = _selectedMuscles.any((sm) => targets.contains(sm.toUpperCase()));
            }
            
            return matchesSearch && matchesDemand && matchesMuscle;
          }).toList();

          list.sort((a, b) => _isAscending 
              ? a.name.compareTo(b.name) 
              : b.name.compareTo(a.name));
          
          return list;
        }

        final defaultFiltered = filterList(provider.defaultTemplates);
        final customFiltered = filterList(provider.customTemplates);

        return Column(
          children: [
            // Search Bar Area
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: AppSearchBar(
                hintText: "Search exercises...",
                maxLength: 30,
                showAdd: _isCustomTab,
                showFilter: true,
                onChanged: (value) => setState(() => _searchQuery = value),
                onFilterTap: () => _showFilterOptions(context),
                onAddTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const AddCustomExerciseSheet(),
                  );
                },
              ),
            ),

            // Tab Bar
            Container(
              width: double.infinity,
              height: 48.h,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.1),
                border: Border(bottom: BorderSide(color: AppColors.white.withOpacity(0.05))),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.crimson, width: 3)),
                ),
                labelColor: AppColors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w500, letterSpacing: 1.2),
                tabs: const [
                  Tab(text: 'DEFAULT EXERCISES'),
                  Tab(text: 'MY EXERCISES'),
                ],
              ),
            ),

            // Exercise Lists
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExerciseList(defaultFiltered),
                  _buildExerciseList(customFiltered),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExerciseList(List<ExerciseTemplate> exercises) {
    return RefreshIndicator(
      onRefresh: () => context.read<ExerciseProvider>().forceRefresh(),
      color: AppColors.crimson,
      backgroundColor: AppColors.surface,
      child: exercises.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              children: [
                SizedBox(
                  height: 400.h,
                  child: Center(
                    child: Text(
                      "No exercises found.",
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.all(20.w),
              itemCount: exercises.length,
              separatorBuilder: (context, index) => SizedBox(height: 16.h),
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return _buildVisualExerciseCard(exercise, key: ValueKey(exercise.id));
              },
            ),
    );
  }

  Widget _buildVisualExerciseCard(ExerciseTemplate exercise, {Key? key}) {
    if (!exercise.isDefault) {
      return Dismissible(
        key: key ?? ValueKey(exercise.id),
        direction: DismissDirection.endToStart,
        confirmDismiss: (dir) async => await _showDeleteConfirmation(exercise.name),
        onDismissed: (dir) {
          context.read<ExerciseProvider>().deleteTemplate(exercise.id);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: 24.w),
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28.r),
        ),
        child: _buildBaseExerciseCard(exercise),
      );
    }
    return _buildBaseExerciseCard(exercise);
  }

  Future<bool?> _showDeleteConfirmation(String exerciseName) async {
    return EliteConfirmDialog.show(
      context,
      title: "DELETE EXERCISE",
      message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THE '${exerciseName.toUpperCase()}' TEMPLATE?",
      icon: Icons.delete_outline_rounded,
    );
  }

  Widget _buildBaseExerciseCard(ExerciseTemplate exercise) {
    final bool hasImage = (exercise.imageUrl ?? "").isNotEmpty && (exercise.imageUrl ?? "").startsWith('http');

    // Resolve Aspect Ratio in background for the Detail Screen (Method A)
    if (hasImage && exercise.aspectRatio == null) {
      final img = Image.network(exercise.imageUrl!);
      img.image.resolve(const ImageConfiguration()).addListener(
        ImageStreamListener((info, _) {
          // Store in memory without triggering list rebuild
          exercise.aspectRatio = info.image.width / info.image.height;
        }),
      );
    }

    return GestureDetector(
      key: ValueKey(exercise.id),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExerciseDetailScreen(
              exerciseId: exercise.id,
              exerciseName: exercise.name,
              intensity: exercise.intensity,
              imagePath: exercise.imageUrl ?? "",
              about: exercise.aboutTheMovement ?? "",
              initialAspectRatio: exercise.aspectRatio,
            ),
          ),
        );
      },
      child: Container(
        constraints: BoxConstraints(minHeight: 120.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.white.withOpacity(0.05)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.r),
          child: Stack(
            children: [
              if (hasImage)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 150.w,
                  child: Container(
                    child: CachedNetworkImage(
                      imageUrl: exercise.imageUrl ?? '',
                      fit: BoxFit.contain, // SHRINK TO FIT: Shows the entire image without cropping
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: AppColors.surfaceLight.withOpacity(0.1),
                        highlightColor: AppColors.surfaceLight.withOpacity(0.2),
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              
              Padding(
                padding: EdgeInsets.all(20.r),
                child: SizedBox(
                  width: hasImage ? 200.w : double.infinity, // Guard text from overlapping image
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        exercise.name.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.h3.copyWith(fontSize: 18.sp, letterSpacing: 0.5, color: AppColors.white),
                      ),
                      if (exercise.sharedBy != null)
                        Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6.r),
                              border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.share_rounded, color: Colors.blueAccent, size: 10.r),
                                SizedBox(width: 4.w),
                                Text(
                                  "SHARED BY ${exercise.sharedBy!.toUpperCase()}",
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Colors.blueAccent,
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      SizedBox(height: 4.h),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: exercise.type == ExerciseType.compound ? AppColors.crimson.withOpacity(0.2) : AppColors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4.r),
                              border: Border.all(color: exercise.type == ExerciseType.compound ? AppColors.crimson.withOpacity(0.3) : AppColors.white.withOpacity(0.1)),
                            ),
                            child: Text(
                              exercise.type.name.toUpperCase(),
                              style: AppTextStyles.labelSmall.copyWith(
                                fontSize: 8.sp, 
                                color: exercise.type == ExerciseType.compound ? AppColors.crimson : AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              exercise.targetMuscles?.toUpperCase() ?? "",
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Text('DEMAND: ', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 9.sp, fontWeight: FontWeight.bold)),
                          _buildFireRating(exercise.intensity),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              Positioned(
                right: 15.w,
                top: 0,
                bottom: 0,
                child: Icon(Icons.arrow_forward_ios_rounded, color: AppColors.white.withOpacity(0.2), size: 16.r),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFireRating(int score) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          Icons.local_fire_department_rounded,
          size: 14.r,
          color: index < score 
              ? AppColors.crimson 
              : AppColors.white.withOpacity(0.1),
        );
      }),
    );
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(24.r, 12.r, 24.r, 24.r),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHandle(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("FILTER EXERCISES", style: AppTextStyles.h3),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedDemands.clear();
                            _selectedMuscles.clear();
                            _isAscending = true;
                          });
                          setState(() {});
                        },
                        child: Text("RESET", style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson)),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                  
                  // Sort Order
                  Text("SORT ORDER", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      _buildFilterChip(
                        label: "A-Z",
                        isSelected: _isAscending,
                        onTap: () {
                          setModalState(() => _isAscending = true);
                          setState(() {});
                        },
                      ),
                      SizedBox(width: 8.w),
                      _buildFilterChip(
                        label: "Z-A",
                        isSelected: !_isAscending,
                        onTap: () {
                          setModalState(() => _isAscending = false);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),

                  // Metabolic Demand
                  Text("METABOLIC DEMAND", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: List.generate(5, (index) {
                      final demand = index + 1;
                      final isSelected = _selectedDemands.contains(demand);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) _selectedDemands.remove(demand);
                            else _selectedDemands.add(demand);
                          });
                          setState(() {});
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.crimson : AppColors.surfaceLight.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(demand, (i) => Icon(
                              Icons.local_fire_department_rounded,
                              size: 14.r,
                              color: isSelected ? Colors.white : AppColors.crimson,
                            )),
                          ),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 24.h),

                  // Muscle Groups
                  Text("TARGET MUSCLES", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      'Chest', 'Back', 'Legs', 'Calf', 'Abdominals', 'Shoulder', 'Biceps', 'Triceps'
                    ].map((m) {
                      final isSelected = _selectedMuscles.contains(m);
                      return _buildFilterChip(
                        label: m.toUpperCase(),
                        isSelected: isSelected,
                        onTap: () {
                          setModalState(() {
                            if (isSelected) _selectedMuscles.remove(m);
                            else _selectedMuscles.add(m);
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 32.h),
                  
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      height: 54.h,
                      width: double.infinity,
                      decoration: BoxDecoration(color: AppColors.crimson, borderRadius: BorderRadius.circular(12.r)),
                      alignment: Alignment.center,
                      child: Text("APPLY FILTERS", style: AppTextStyles.buttonPrimary),
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  Widget _buildFilterChip({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson : AppColors.surfaceLight.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.05)),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: EdgeInsets.only(bottom: 24.h),
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.2), borderRadius: BorderRadius.circular(2.r)),
      ),
    );
  }
}
