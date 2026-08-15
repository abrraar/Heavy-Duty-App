// lib/features/tracker/sleep/sleep_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:heavy_duty/features/main_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'provider/sleep_provider.dart';
import 'provider/sleep_alarm_provider.dart';
import 'model/sleep_log.dart';

import 'widgets/circular_sleep_picker.dart';
import 'widgets/sleep_analytical_graph.dart';

class SleepScreen extends StatefulWidget {
  const SleepScreen({super.key});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late PageController _pageController;
  
  // Trends State
  final Set<String> _visibleMetrics = {'duration'};
  int? _comparePointA;
  int? _comparePointB;

  // Entry State
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedHistoryDate = DateTime.now();
  TimeOfDay _entryBedTime = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay _entryWakeTime = const TimeOfDay(hour: 06, minute: 45);
  int _selectedQuality = 4;
  String _entryNote = "";
  SleepType _selectedType = SleepType.night;
  final List<String> _chartLabels = [];

  Color get _activeAccentColor => _selectedType == SleepType.night ? AppColors.crimson : Colors.amber;
  
  // Filter/Sort State
  bool _showSleep = true;
  bool _showNaps = true;
  String _sortBy = 'Date'; // 'Date' or 'Duration'
  bool _isAscending = false;

  // Calendar State
  DateTime _displayedMonth = DateTime.now();
  bool _isCalendarExpanded = false;

  // Overlap State
  SleepLog? _conflictingLog;
  OverlayEntry? _snackbarOverlay;

  @override
  void initState() {
    super.initState();
    activeSettingsContext.value = "sleep"; 
    _tabController = TabController(length: 3, vsync: this);
    _pageController = PageController(
      viewportFraction: 0.2,
      initialPage: 0,
    );
    _displayedMonth = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month);
  }

  @override
  void dispose() {
    _snackbarOverlay?.remove();
    activeSettingsContext.value = "";
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _validateOverlap() {
    // This is now handled reactively inside the Consumer builder
    // We keep the method signature to avoid breaking existing calls
    if (mounted) setState(() {});
  }

  void _showCustomSnackbar(String message, VoidCallback onUndo) {
    EliteSnackbar.show(context, message, onUndo: onUndo);
  }

  void _showInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.crimson.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: AppColors.crimson,
                size: 28.r,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "SLEEP CONTROLS",
              style: AppTextStyles.h3.copyWith(
                fontSize: 16.sp,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _instructionRow(
              Icons.touch_app_rounded,
              "Hold and drag the moon or sun icons to adjust your sleep timing.",
            ),
            SizedBox(height: 16.h),
            _instructionRow(
              Icons.calendar_today_rounded,
              "Tap the current date to select previous sessions for entry.",
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.crimson.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.crimson.withOpacity(0.5)),
                ),
                alignment: Alignment.center,
                child: Text(
                  "GOT IT",
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.crimson, size: 20.r),
        SizedBox(width: 16.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final provider = context.read<SleepProvider>();
    
    // Check if current _selectedDate is still valid (not logged and not future)
    bool isCurrentDateSelectable(DateTime date) {
      final bool hasLog = provider.logs.any((l) =>
          l.wakeUpTime.year == date.year &&
          l.wakeUpTime.month == date.month &&
          l.wakeUpTime.day == date.day);
      final bool isFuture = date.isAfter(DateTime.now());
      return !hasLog && !isFuture;
    }

    DateTime initialDatePickerDate = _selectedDate;
    if (!isCurrentDateSelectable(initialDatePickerDate)) {
      // Find the most recent unlogged day
      DateTime searchDate = DateTime.now();
      while (!isCurrentDateSelectable(searchDate) && searchDate.isAfter(DateTime(2000))) {
        searchDate = searchDate.subtract(const Duration(days: 1));
      }
      initialDatePickerDate = searchDate;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDatePickerDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      selectableDayPredicate: (DateTime date) {
        final bool hasLog = provider.logs.any((l) =>
            l.wakeUpTime.year == date.year &&
            l.wakeUpTime.month == date.month &&
            l.wakeUpTime.day == date.day);
        return !hasLog;
      },
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _validateOverlap();
    }
  }

  Future<void> _pickAudio(bool isBedtime, SleepAlarmProvider provider) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
        if (isBedtime) {
          await provider.updateSettings(
            bedtimeAudioPath: result.files.single.path,
          );
        } else {
          await provider.updateSettings(
            wakeUpAudioPath: result.files.single.path,
          );
        }
        if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8.w, 16.h, 8.w, 8.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'SLEEP PERFORMANCE',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.white,
                        ),
                        onPressed: _showInstructions,
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.crimson,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.w400,
                  ),
                  unselectedLabelColor: AppColors.textSecondary,
                  labelColor: AppColors.crimson,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "TRACKER"),
                    Tab(text: "TRENDS"),
                    Tab(text: "LOGS"),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer2<SleepProvider, SleepAlarmProvider>(
              builder: (context, provider, alarmProvider, _) {
                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTrackerTab(provider, alarmProvider),
                    _buildTrendsTab(provider),
                    _buildHistoryTab(provider),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackerTab(SleepProvider provider, SleepAlarmProvider alarmProvider) {
    final bool hasLogForSelectedDate = provider.logs.any((l) =>
        l.wakeUpTime.year == _selectedDate.year &&
        l.wakeUpTime.month == _selectedDate.month &&
        l.wakeUpTime.day == _selectedDate.day);
    final bool isFutureDate = _selectedDate.isAfter(DateTime.now());
    final bool canSave = !hasLogForSelectedDate && !isFutureDate;

    String? disabledReason;
    if (isFutureDate) {
      disabledReason = "CANNOT RECORD SLEEP FOR FUTURE DATES";
    } else if (hasLogForSelectedDate) {
      disabledReason = "SLEEP ALREADY RECORDED FOR THIS DATE";
    }

    return RefreshIndicator(
      onRefresh: () => provider.forceRefresh(),
      color: AppColors.crimson,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Column(
          children: [
            SizedBox(height: 12.h),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: _buildSectionTitle('LOG SLEEP'),
            ),
            SizedBox(height: 16.h),
            CircularSleepPicker(
              initialBedtime: _entryBedTime,
              initialWakeTime: _entryWakeTime,
              canSave: canSave,
              disabledReason: disabledReason,
              selectedDate: _selectedDate,
              quality: _selectedQuality,
              note: _entryNote,
              use24HourClock: provider.settings.use24HourClock,
              onPickDate: _pickDate,
              onTimeChanged: (bedtime, wakeTime) {
                _entryBedTime = bedtime;
                _entryWakeTime = wakeTime;
              },
              onQualityChanged: (q) => setState(() => _selectedQuality = q),
              onNoteChanged: (n) => _entryNote = n,
              onSave: () async {
                if (!canSave) {
                  EliteSnackbar.show(context, disabledReason ?? "CANNOT RECORD SLEEP", isError: true);
                  return;
                }

                DateTime end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _entryWakeTime.hour, _entryWakeTime.minute);
                DateTime start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _entryBedTime.hour, _entryBedTime.minute);
                
                // If bedtime is "after" wake up time on the clock (e.g., 10 PM vs 7 AM),
                // it means the sleep started the previous night.
                if (start.isAfter(end)) {
                  start = start.subtract(const Duration(days: 1));
                }
                
                final logId = const Uuid().v4();
                final log = SleepLog(
                  id: logId, 
                  bedtime: start, 
                  wakeUpTime: end, 
                  quality: _selectedQuality, 
                  type: SleepType.night,
                  note: _entryNote,
                );
                await provider.addSleepLog(log);
                
                if (mounted) {
                  _showCustomSnackbar(
                    "Sleep session recorded!",
                    () async {
                       await provider.deleteLog(logId);
                    },
                  );
                  setState(() {
                    _entryNote = "";
                    _selectedQuality = 4;
                  });
                }
              },
            ),
            
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 40.h),
                  _buildSectionTitle('ALARM CONFIGURATION'),
                  SizedBox(height: 16.h),
                  _buildEnhancedAlarmCard(alarmProvider),
                  SizedBox(height: 40.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab(SleepProvider provider) {
    if (provider.logs.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => RefreshIndicator(
          onRefresh: () => provider.forceRefresh(),
          color: AppColors.crimson,
          child: ListView(
            children: [
              Container(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "INSUFFICIENT DATA FOR TRENDS",
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary.withOpacity(0.2),
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedLogs = List<SleepLog>.from(provider.logs)..sort((a, b) => a.bedtime.compareTo(b.bedtime));
    final List<DateTime> dates = sortedLogs.map((l) => l.wakeUpTime).toList();
    final Map<String, List<double?>> data = {
      "duration": sortedLogs.map((l) => l.duration.inMinutes / 60.0).toList(),
    };

    return RefreshIndicator(
      onRefresh: () => provider.forceRefresh(),
      color: AppColors.crimson,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Column(
          children: [
            SizedBox(height: 32.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: _buildSectionTitle('SLEEP TRENDS'),
            ),
            SizedBox(height: 24.h),

            // Analytical Graph
            SleepAnalyticalGraph(
              dates: dates,
              data: data,
              visibleMetrics: _visibleMetrics,
              onPointSelected: (idx) {
                // Potential for haptic feedback
              },
            ),

            SizedBox(height: 32.h),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: _buildSectionTitle('DATA COMPARISON'),
            ),
            SizedBox(height: 24.h),

            // Comparison Widget
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: SleepComparisonWidget(
                idx1: _comparePointA,
                idx2: _comparePointB,
                dates: dates,
                data: data,
                use24HourClock: provider.settings.use24HourClock,
                onPointAChanged: (idx) => setState(() => _comparePointA = idx),
                onPointBChanged: (idx) => setState(() => _comparePointB = idx),
              ),
            ),

            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  // Remove _buildMetricToggle as it's no longer used

  Widget _buildBigStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withOpacity(0.4),
            fontSize: 9.sp,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: AppTextStyles.h2.copyWith(
            fontSize: 20.sp,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(SleepProvider provider) {
    final Set<DateTime> dateSet = provider.logs.map((l) => 
      DateTime(l.wakeUpTime.year, l.wakeUpTime.month, l.wakeUpTime.day)
    ).toSet();
    
    final now = DateTime.now();
    dateSet.add(DateTime(now.year, now.month, now.day));

    final historyLogs = provider.logs.where((l) {
      return l.wakeUpTime.year == _selectedHistoryDate.year &&
             l.wakeUpTime.month == _selectedHistoryDate.month &&
             l.wakeUpTime.day == _selectedHistoryDate.day;
    }).toList();

    if (_isCalendarExpanded) {
      return Container(
        color: AppColors.background,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildCustomExpandedCalendar(dateSet),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _isCalendarExpanded = false);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final target = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month, _selectedHistoryDate.day);
                  final int dayDiff = today.difference(target).inDays;
                  if (dayDiff >= 0 && dayDiff < 365) {
                    if (_pageController.hasClients) {
                      _pageController.animateToPage(
                        dayDiff, 
                        duration: const Duration(milliseconds: 300), 
                        curve: Curves.easeInOut
                      );
                    }
                  }
                });
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                color: Colors.transparent,
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                  size: 24.r,
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildHorizontalCalendar(dateSet),
        GestureDetector(
          onTap: () {
            setState(() {
              _isCalendarExpanded = true;
              _displayedMonth = DateTime(_selectedHistoryDate.year, _selectedHistoryDate.month);
            });
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 4.h),
            color: Colors.transparent,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary.withValues(alpha: 0.4),
              size: 24.r,
            ),
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.forceRefresh(),
            color: AppColors.crimson,
            backgroundColor: AppColors.surface,
            child: historyLogs.isEmpty
                ? LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      children: [
                        Container(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: Center(
                            child: Text(
                              "No logs for this date.",
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                    itemCount: historyLogs.length,
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final log = historyLogs[index];
                      return Dismissible(
                        key: Key("sleep_log_${log.id}"),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 24.w),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
                        ),
                        confirmDismiss: (direction) => _confirmDelete(context, provider, log.id),
                        onDismissed: (_) {
                          provider.deleteLog(log.id);
                        },
                        child: _buildHistoryCard(context, provider, log),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomExpandedCalendar(Set<DateTime> dateSet) {
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final isCurrentMonth = _displayedMonth.year == DateTime.now().year && _displayedMonth.month == DateTime.now().month;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                onPressed: () => setState(() {
                  _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
                }),
              ),
              GestureDetector(
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedHistoryDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
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
                  if (picked != null) {
                    setState(() {
                      _selectedHistoryDate = picked;
                      _displayedMonth = DateTime(picked.year, picked.month);
                    });
                  }
                },
                child: Text(
                  DateFormat('MMMM yyyy').format(_displayedMonth).toUpperCase(),
                  style: AppTextStyles.labelMedium.copyWith(color: Colors.white, letterSpacing: 1.5),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded, color: isCurrentMonth ? Colors.white.withValues(alpha: 0.1) : Colors.white),
                onPressed: isCurrentMonth ? null : () => setState(() {
                  _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
                }),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["M", "T", "W", "T", "F", "S", "S"].map((d) => SizedBox(
              width: 40.w,
              child: Text(d, textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: 10.sp)),
            )).toList(),
          ),
          SizedBox(height: 10.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: daysInMonth + (firstDayOfMonth - 1),
            itemBuilder: (context, index) {
              if (index < firstDayOfMonth - 1) return const SizedBox.shrink();
              
              final day = index - (firstDayOfMonth - 1) + 1;
              final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
              final isSelected = date.year == _selectedHistoryDate.year &&
                  date.month == _selectedHistoryDate.month &&
                  date.day == _selectedHistoryDate.day;
              final hasData = dateSet.contains(date);
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;
              final isFuture = date.isAfter(DateTime.now());

              return GestureDetector(
                onTap: isFuture ? null : () {
                  setState(() {
                    _selectedHistoryDate = date;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.crimson : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isToday && !isSelected 
                        ? Border.all(color: AppColors.crimson.withValues(alpha: 0.5))
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        day.toString(),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isSelected 
                              ? Colors.white 
                              : (isFuture ? Colors.white.withValues(alpha: 0.05) : (hasData ? Colors.white : Colors.white.withValues(alpha: 0.2))),
                          fontWeight: (isSelected || hasData) ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (hasData && !isSelected)
                        Positioned(
                          bottom: 4.h,
                          child: Container(
                            width: 3.r,
                            height: 3.r,
                            decoration: const BoxDecoration(color: AppColors.crimson, shape: BoxShape.circle),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCalendar(Set<DateTime> dateSet) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: 90.h,
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: PageView.builder(
        controller: _pageController,
        padEnds: false,
        physics: const PageScrollPhysics(),
        itemCount: 365,
        itemBuilder: (context, index) {
          final dateOnly = today.subtract(Duration(days: index));
          
          final isSelected = dateOnly.year == _selectedHistoryDate.year &&
              dateOnly.month == _selectedHistoryDate.month &&
              dateOnly.day == _selectedHistoryDate.day;
          
          final isToday = dateOnly.day == today.day && 
                          dateOnly.month == today.month && 
                          dateOnly.year == today.year;
          
          final hasData = dateSet.contains(dateOnly);

          return GestureDetector(
            onTap: () {
              setState(() => _selectedHistoryDate = dateOnly);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: 6.w),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.crimson : Colors.transparent,
                borderRadius: BorderRadius.circular(12.r),
                border: isToday && !isSelected 
                    ? Border.all(color: AppColors.crimson.withValues(alpha: 0.5))
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(dateOnly).toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 10.sp,
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.2)),
                      fontWeight: (isSelected || hasData) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    dateOnly.day.toString(),
                    style: AppTextStyles.h3.copyWith(
                      fontSize: 16.sp,
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.white : AppColors.white.withValues(alpha: 0.15)),
                    ),
                  ),
                  if (hasData && !isSelected)
                    Container(
                      margin: EdgeInsets.only(top: 4.h),
                      width: 4.r,
                      height: 4.r,
                      decoration: const BoxDecoration(
                        color: AppColors.crimson,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, SleepProvider provider, SleepLog log) {
    final hours = log.duration.inHours;
    final minutes = log.duration.inMinutes % 60;
    final dateStr = DateFormat('MMM dd, yyyy').format(log.wakeUpTime);
    
    final String bedTimeStr = _formatTime(TimeOfDay.fromDateTime(log.bedtime), provider.settings.use24HourClock);
    final String wakeTimeStr = _formatTime(TimeOfDay.fromDateTime(log.wakeUpTime), provider.settings.use24HourClock);
    final timeStr = "$bedTimeStr - $wakeTimeStr";

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: log.type == SleepType.night ? AppColors.crimson.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  log.type == SleepType.night ? Icons.bedtime_rounded : Icons.wb_sunny_rounded,
                  color: log.type == SleepType.night ? AppColors.crimson : Colors.amber,
                  size: 20.r,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${hours}h ${minutes}m",
                      style: AppTextStyles.labelMedium.copyWith(fontSize: 16.sp, color: AppColors.white),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      dateStr,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp),
                    ),
                    Text(
                      timeStr,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 9.sp),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  Icons.star_rounded,
                  size: 12.r,
                  color: i < log.quality 
                    ? (log.type == SleepType.night ? AppColors.crimson : Colors.amber) 
                    : AppColors.white.withValues(alpha: 0.1),
                )),
              ),
            ],
          ),
          if (log.note.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "NOTES",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      fontSize: 8.sp,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    log.note,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 11.sp,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, SleepProvider provider, String id) {
    return EliteConfirmDialog.show(
      context,
      title: "DELETE SLEEP LOG",
      message: "ARE YOU SURE YOU WANT TO PERMANENTLY REMOVE THIS SESSION FROM YOUR HISTORY?",
    );
  }

  Widget _buildEnhancedAlarmCard(SleepAlarmProvider alarmProvider) {
    final settings = alarmProvider.settings;
    
    return Column(
      children: [
        _buildSystemTimeTile(
          title: "Bedtime Reminder",
          subtitle: "Optimized Recovery Start",
          icon: Icons.bedtime_rounded,
          iconColor: AppColors.crimson,
          time: TimeOfDay(hour: settings.bedtimeHour, minute: settings.bedtimeMinute),
          isEnabled: settings.bedtimeEnabled,
          audioName: settings.bedtimeAudioPath != null ? settings.bedtimeAudioPath!.split('/').last : 'Standard',
          use24HourClock: context.read<SleepProvider>().settings.use24HourClock,
          onToggle: (val) async {
             if (val) {
                final ok = await alarmProvider.checkAndRequestPermissions(context);
                if (!ok) return;
                await alarmProvider.updateSettings(bedtimeEnabled: true);
             } else {
                await alarmProvider.updateSettings(bedtimeEnabled: false);
             }
          },
          onTimeTap: () async {
            final picked = await showTimePicker(
              context: context, 
              initialTime: TimeOfDay(hour: settings.bedtimeHour, minute: settings.bedtimeMinute),
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: context.read<SleepProvider>().settings.use24HourClock),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              await alarmProvider.updateSettings(bedtimeHour: picked.hour, bedtimeMinute: picked.minute);
            }
          },
          onAudioTap: () => _pickAudio(true, alarmProvider),
        ),
        SizedBox(height: 12.h),
        _buildSystemTimeTile(
          title: "Wake Up Alarm",
          subtitle: "Growth Protocol Active",
          icon: Icons.wb_sunny_rounded,
          iconColor: Colors.amber,
          time: TimeOfDay(hour: settings.wakeUpHour, minute: settings.wakeUpMinute),
          isEnabled: settings.wakeUpEnabled,
          audioName: settings.wakeUpAudioPath != null ? settings.wakeUpAudioPath!.split('/').last : 'Standard',
          use24HourClock: context.read<SleepProvider>().settings.use24HourClock,
          onToggle: (val) async {
             if (val) {
                final ok = await alarmProvider.checkAndRequestPermissions(context);
                if (!ok) return;
                await alarmProvider.updateSettings(wakeUpEnabled: true);
             } else {
                await alarmProvider.updateSettings(wakeUpEnabled: false);
             }
          },
          onTimeTap: () async {
            final picked = await showTimePicker(
              context: context, 
              initialTime: TimeOfDay(hour: settings.wakeUpHour, minute: settings.wakeUpMinute),
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: context.read<SleepProvider>().settings.use24HourClock),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              await alarmProvider.updateSettings(wakeUpHour: picked.hour, wakeUpMinute: picked.minute);
            }
          },
          onAudioTap: () => _pickAudio(false, alarmProvider),
        ),
      ],
    );
  }

  Widget _buildSystemTimeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required TimeOfDay time,
    required bool isEnabled,
    required String audioName,
    required Function(bool) onToggle,
    required VoidCallback onTimeTap,
    required VoidCallback onAudioTap,
    required bool use24HourClock,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 12.w, 8.h),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20.r),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.labelMedium.copyWith(color: AppColors.white, fontSize: 14.sp)),
                      Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 9.sp)),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  activeThumbColor: AppColors.crimson,
                  onChanged: onToggle,
                ),
              ],
            ),
          ),
          Divider(color: AppColors.white.withValues(alpha: 0.03), height: 1),
          IntrinsicH(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onTimeTap,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: Column(
                        children: [
                          Text("SCHEDULED", style: AppTextStyles.labelSmall.copyWith(fontSize: 8.sp, color: AppColors.textSecondary, letterSpacing: 1)),
                          SizedBox(height: 4.h),
                          Text(
                            _formatTime(time, use24HourClock), 
                            style: AppTextStyles.h2.copyWith(
                              fontSize: 22.sp, 
                              color: isEnabled ? AppColors.white : AppColors.textSecondary.withValues(alpha: 0.5)
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, color: AppColors.white.withValues(alpha: 0.03)),
                Expanded(
                  child: InkWell(
                    onTap: onAudioTap,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
                      child: Column(
                        children: [
                          Text("ALARM TONE", style: AppTextStyles.labelSmall.copyWith(fontSize: 8.sp, color: AppColors.textSecondary, letterSpacing: 1)),
                          SizedBox(height: 6.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.graphic_eq_rounded, size: 12.r, color: AppColors.crimson),
                              SizedBox(width: 6.w),
                              Flexible(
                                child: Text(
                                  audioName.toUpperCase(),
                                  style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: AppColors.white, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
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

  String _formatTime(TimeOfDay time, bool use24HourClock) {
    if (use24HourClock) {
      final String hour = time.hour.toString().padLeft(2, '0');
      final String minute = time.minute.toString().padLeft(2, '0');
      return "$hour:$minute";
    } else {
      final int hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final String minute = time.minute.toString().padLeft(2, '0');
      final String period = time.period == DayPeriod.am ? "AM" : "PM";
      return "$hour:$minute $period";
    }
  }







































  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(width: 3.w, height: 12.h, decoration: BoxDecoration(color: AppColors.crimson, borderRadius: BorderRadius.circular(2.r))),
        SizedBox(width: 8.w),
        Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.8))),
      ],
    );
  }


}

class IntrinsicH extends StatelessWidget {
  final Widget child;
  const IntrinsicH({super.key, required this.child});

  @override
  Widget build(BuildContext context) => IntrinsicHeight(child: child);
}

class SleepComparisonWidget extends StatelessWidget {
  final int? idx1;
  final int? idx2;
  final List<DateTime> dates;
  final Map<String, List<double?>> data;
  final Function(int?) onPointAChanged;
  final Function(int?) onPointBChanged;
  final bool use24HourClock;

  const SleepComparisonWidget({
    super.key,
    required this.idx1,
    required this.idx2,
    required this.dates,
    required this.data,
    required this.onPointAChanged,
    required this.onPointBChanged,
    required this.use24HourClock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPointPicker("POINT A", idx1, idx2, dates, onPointAChanged, context),
              SizedBox(width: 16.w),
              _buildPointPicker("POINT B", idx2, idx1, dates, onPointBChanged, context, isEnd: true),
            ],
          ),
          if (idx1 != null && idx2 != null) ...[
            SizedBox(height: 24.h),
            _buildComparisonDetails(),
          ] else ...[
            SizedBox(height: 32.h),
            Center(
              child: Text(
                "SELECT TWO POINTS TO COMPARE",
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.2)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointPicker(String title, int? selectedIdx, int? otherIdx, List<DateTime> dates, Function(int?) onChanged, BuildContext context, {bool isEnd = false}) {
    final labels = dates.map((d) {
      if (use24HourClock) {
        return DateFormat('MMM dd, HH:mm').format(d).toUpperCase();
      } else {
        return DateFormat('MMM dd, hh:mm a').format(d).toUpperCase();
      }
    }).toList();
    return Expanded(
      child: Column(
        crossAxisAlignment: isEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (selectedIdx != null && isEnd) ...[
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: 12.r),
                  ),
                ),
                SizedBox(width: 8.w),
              ],
              Text(title, style: AppTextStyles.labelSmall.copyWith(color: selectedIdx != null ? AppColors.crimson : AppColors.textSecondary.withOpacity(0.4), fontSize: 11.sp, fontWeight: FontWeight.w900)),
              if (selectedIdx != null && !isEnd) ...[
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: EdgeInsets.all(4.r),
                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: 12.r),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 10.h),
          GestureDetector(
            onTap: () => _showPicker(context, selectedIdx, otherIdx, dates, onChanged),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: selectedIdx != null ? AppColors.crimson.withOpacity(0.05) : AppColors.surfaceLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: selectedIdx != null ? AppColors.crimson.withOpacity(0.4) : AppColors.white.withOpacity(0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selectedIdx != null ? Icons.event_available_rounded : Icons.event_note_rounded, color: AppColors.crimson, size: 18.r),
                  SizedBox(width: 10.w),
                  Flexible(child: Text(selectedIdx != null ? labels[selectedIdx] : "SET POINT", overflow: TextOverflow.ellipsis, style: AppTextStyles.labelSmall.copyWith(fontSize: 11.sp, color: selectedIdx != null ? Colors.white : AppColors.textSecondary.withOpacity(0.4)))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPicker(BuildContext context, int? current, int? other, List<DateTime> dates, Function(int?) onChanged) async {
    final Map<String, List<int>> dateGroups = {};
    for (int i = 0; i < dates.length; i++) {
      final dateKey = DateFormat('yyyy-MM-dd').format(dates[i]);
      dateGroups.putIfAbsent(dateKey, () => []).add(i);
    }
    final sortedDateKeys = dateGroups.keys.toList()..sort((a, b) => b.compareTo(a));

    final int? result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 40.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: AppColors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w, height: 4.h, margin: EdgeInsets.only(bottom: 24.h),
              decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.2), borderRadius: BorderRadius.circular(2.r)),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(Icons.event_note_rounded, color: AppColors.crimson, size: 24.r),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SELECT LOG", style: AppTextStyles.h3.copyWith(fontSize: 18.sp)),
                      Text("CHOOSE A DATE FROM YOUR LOGS", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.5), letterSpacing: 1)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: sortedDateKeys.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, i) {
                  final String dateKey = sortedDateKeys[i];
                  final List<int> indices = dateGroups[dateKey]!;
                  final DateTime displayDate = dates[indices.first];
                  
                  bool isPartiallySelected = indices.contains(current);
                  bool isOccupiedByOther = indices.contains(other);

                  return GestureDetector(
                    onTap: () async {
                      if (indices.length == 1) {
                        Navigator.pop(context, indices.first);
                      } else {
                        final int? timeResult = await showModalBottomSheet<int>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => Container(
                            padding: EdgeInsets.all(24.r),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r))),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("SELECT TIME", style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson, letterSpacing: 1.2)),
                                SizedBox(height: 20.h),
                                ...indices.map((idx) {
                                  final bool isCurrent = idx == current;
                                  final bool isOther = idx == other;
                                  return ListTile(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w),
                                    leading: Icon(
                                      isCurrent ? Icons.check_circle_rounded : (isOther ? Icons.info_outline_rounded : Icons.radio_button_off_rounded),
                                      color: isCurrent ? AppColors.crimson : (isOther ? AppColors.textSecondary.withOpacity(0.5) : AppColors.textSecondary.withOpacity(0.2)),
                                    ),
                                    title: Text(
                                      use24HourClock 
                                          ? DateFormat('HH:mm').format(dates[idx])
                                          : DateFormat('hh:mm a').format(dates[idx]),
                                      style: AppTextStyles.labelSmall.copyWith(color: isCurrent ? Colors.white : (isOther ? AppColors.textSecondary.withOpacity(0.5) : AppColors.textSecondary)),
                                    ),
                                    onTap: () => Navigator.pop(ctx, idx),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                        if (timeResult != null && context.mounted) Navigator.pop(context, timeResult);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: EdgeInsets.all(16.r),
                      decoration: BoxDecoration(
                        color: isPartiallySelected ? AppColors.crimson.withOpacity(0.1) : AppColors.background.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isPartiallySelected ? AppColors.crimson : (isOccupiedByOther ? AppColors.crimson.withOpacity(0.3) : AppColors.white.withOpacity(0.05)),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPartiallySelected ? Icons.check_circle_rounded : (isOccupiedByOther ? Icons.info_outline_rounded : Icons.calendar_today_rounded),
                            color: isPartiallySelected ? AppColors.crimson : (isOccupiedByOther ? AppColors.crimson.withOpacity(0.5) : AppColors.textSecondary.withOpacity(0.2)),
                            size: 20.r,
                          ),
                          SizedBox(width: 16.w),
                          Text(
                            DateFormat('MMMM dd, yyyy').format(displayDate).toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isPartiallySelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isPartiallySelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13.sp,
                            ),
                          ),
                          const Spacer(),
                          if (indices.length > 1)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                              decoration: BoxDecoration(color: AppColors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8.r)),
                              child: Text("${indices.length} LOGS", style: AppTextStyles.labelSmall.copyWith(fontSize: 9.sp, color: AppColors.textSecondary.withOpacity(0.5))),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (result != null) onChanged(result);
  }

  Widget _buildComparisonDetails() {
    final List<Widget> items = [];
    final v1 = data["duration"]?[idx1!];
    final v2 = data["duration"]?[idx2!];
    if (v1 != null && v2 != null) {
      items.add(_buildMetricComparison("SLEEP DURATION", v1, v2, "hr", AppColors.crimson));
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Text(
            "NO OVERLAPPING METRICS ON THESE DATES", 
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.3), fontSize: 8.sp)
          ),
        ),
      );
    }

    return Column(children: items);
  }

  Widget _buildMetricComparison(String label, double v1, double v2, String unit, Color color) {
    final delta = v2 - v1;
    final percent = v1 != 0 ? (delta / v1.abs()) * 100 : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w900, fontSize: 13.sp, letterSpacing: 1)),
              Row(
                children: [
                  Icon(delta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, size: 18.r),
                  SizedBox(width: 6.w),
                  Text("${delta >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%", style: AppTextStyles.labelSmall.copyWith(color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14.sp)),
                ],
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _valItem("Point A", v1, unit),
              _valItem("Point B", v2, unit),
              _valItem("Difference", delta, unit, isDelta: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valItem(String l, double v, String u, {bool isDelta = false}) {
    return Column(
      children: [
        Text(l, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.4), fontSize: 10.sp, fontWeight: FontWeight.bold)),
        SizedBox(height: 4.h),
        Text("${v >= 0 && isDelta ? '+' : ''}${v.toStringAsFixed(1)}$u", style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16.sp)),
      ],
    );
  }
}
