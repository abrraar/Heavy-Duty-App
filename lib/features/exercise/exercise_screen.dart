import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/features/exercise/provider/exercise_provider.dart';
import 'package:provider/provider.dart';
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
                labelStyle: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2),
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
    return showDialog<bool>(
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
                Icons.delete_outline_rounded,
                color: AppColors.crimson,
                size: 28.r,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "DELETE EXERCISE",
              style: AppTextStyles.h3.copyWith(
                fontSize: 16.sp,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THE '${exerciseName.toUpperCase()}' TEMPLATE?",
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.white.withOpacity(0.1)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "CANCEL",
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.crimson.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.crimson.withOpacity(0.5)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "DELETE",
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.crimson,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseExerciseCard(ExerciseTemplate exercise) {
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
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 150.w,
                child: Container(
                  foregroundDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.surface, AppColors.surface.withOpacity(0.0)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                  child: Image.network(
                    exercise.imageUrl ?? 'https://via.placeholder.com/150x120/1A1A1A/FFFFFF?text=HIT', 
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: AppColors.surface),
                  ),
                ),
              ),
              
              Padding(
                padding: EdgeInsets.all(20.r),
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
                                  fontWeight: FontWeight.w900,
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
                              fontWeight: FontWeight.bold,
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
  }}
