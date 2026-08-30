// lib/features/tracker/sleep/sleep_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:heavy_duty/features/main_wrapper.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:heavy_duty/core/constants/dimensions.dart';
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
  final SleepType _selectedType = SleepType.night;
  final List<String> _chartLabels = [];

  Color get _activeAccentColor => _selectedType == SleepType.night ? AppColors.crimson : Colors.amber;
  
  // Filter/Sort State
  final bool _showSleep = true;
  final bool _showNaps = true;
  final String _sortBy = 'Date'; // 'Date' or 'Duration'
  final bool _isAscending = false;

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
      builder: (context) => LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompact = constraints.maxWidth < 600;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isCompact ? double.infinity : 400),
              child: AlertDialog(
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
                      "SLEEP CONTROLS",
                      style: AppTextStyles.h3.copyWith(
                        fontSize: isCompact ? 16.sp : 15.0,
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
                      isCompact,
                    ),
                    SizedBox(height: isCompact ? 16.h : 12.0),
                    _instructionRow(
                      Icons.calendar_today_rounded,
                      "Tap the current date to select previous sessions for entry.",
                      isCompact,
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 12.w : 12.0,
                      0,
                      isCompact ? 12.w : 12.0,
                      isCompact ? 16.h : 16.0,
                    ),
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
                          "GOT IT",
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.crimson,
                            fontWeight: FontWeight.w500,
                            fontSize: isCompact ? 13.sp : 12.0,
                          ),
                        ),
                      ),
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

  Widget _instructionRow(IconData icon, String text, bool isCompact) {
    return Row(
      children: [
        Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 18.0),
        SizedBox(width: isCompact ? 16.w : 12.0),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
              fontSize: isCompact ? 13.sp : 12.0,
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
      builder: (context, child) => child!,
      selectableDayPredicate: (DateTime date) {
        final bool hasLog = provider.logs.any((l) =>
            l.wakeUpTime.year == date.year &&
            l.wakeUpTime.month == date.month &&
            l.wakeUpTime.day == date.day);
        return !hasLog;
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _validateOverlap();
    }
  }

  Future<void> _pickAudio(bool isBedtime, SleepAlarmProvider provider) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
    );

    if (result != null && result.files.single.path != null) {
        final String path = result.files.single.path!;
        if (isBedtime) {
          await provider.updateSettings(
            bedtimeAudioPath: path,
          );
        } else {
          await provider.updateSettings(
            wakeUpAudioPath: path,
          );
        }
        if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < kMobileBreakpoint;
        final double hPad = !isCompact
            ? (width - kMaxContentWidth).clamp(24.0, double.infinity) / 2
            : 8.w;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 24.h : 20.0),
                      child: IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: AppColors.white,
                                size: isCompact ? 24.r : 20.0,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                            Expanded(
                              child: Text(
                                'SLEEP PERFORMANCE',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.h2.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: isCompact ? 20.sp : 18.0,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.white,
                                size: isCompact ? 24.r : 20.0,
                              ),
                              onPressed: _showInstructions,
                            ),
                          ],
                        ),
                      ),
                    ),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.crimson,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: AppTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: isCompact ? 11.sp : 11.0,
                      ),
                      unselectedLabelColor: AppColors.textSecondary.withValues(alpha: 0.5),
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
                        _buildTrackerTab(provider, alarmProvider, isCompact),
                        _buildTrendsTab(provider, isCompact),
                        _buildHistoryTab(provider, isCompact),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackerTab(SleepProvider provider, SleepAlarmProvider alarmProvider, bool isCompact) {
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth > 700;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- LEFT COLUMN: LOG SLEEP ---
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: _buildSectionTitle('LOG SLEEP', isCompact),
                      ),
                      SizedBox(height: 16.0),
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
                        isCompact: isCompact,
                        onSave: () async {
                          if (!canSave) {
                            EliteSnackbar.show(context, disabledReason ?? "CANNOT RECORD SLEEP", isError: true);
                            return;
                          }

                          DateTime end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _entryWakeTime.hour, _entryWakeTime.minute);
                          DateTime start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _entryBedTime.hour, _entryBedTime.minute);
                          
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
                    ],
                  ),
                ),
                VerticalDivider(color: AppColors.white.withOpacity(0.05), width: 1),
                // --- RIGHT COLUMN: ALARM ---
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.all(20.0),
                    children: [
                      _buildSectionTitle('ALARM CONFIGURATION', isCompact),
                      SizedBox(height: 20.0),
                      _buildEnhancedAlarmCard(alarmProvider, isCompact),
                    ],
                  ),
                ),
              ],
            );
          }

          // --- MOBILE: SINGLE COLUMN ---
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            child: Column(
              children: [
                SizedBox(height: 12.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: _buildSectionTitle('LOG SLEEP', isCompact),
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
                  isCompact: isCompact,
                  onSave: () async {
                    if (!canSave) {
                      EliteSnackbar.show(context, disabledReason ?? "CANNOT RECORD SLEEP", isError: true);
                      return;
                    }

                    DateTime end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _entryWakeTime.hour, _entryWakeTime.minute);
                    DateTime start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _entryBedTime.hour, _entryBedTime.minute);
                    
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
                      _buildSectionTitle('ALARM CONFIGURATION', isCompact),
                      SizedBox(height: 16.h),
                      _buildEnhancedAlarmCard(alarmProvider, isCompact),
                      SizedBox(height: 40.h),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendsTab(SleepProvider provider, bool isCompact) {
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
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                          letterSpacing: 2,
                          fontSize: isCompact ? 11.sp : 10.0,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth > 700;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- LEFT COLUMN: TRENDS ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('SLEEP TRENDS', isCompact),
                        SizedBox(height: isCompact ? 24.h : 20.0),
                        SleepAnalyticalGraph(
                          dates: dates,
                          data: data,
                          visibleMetrics: _visibleMetrics,
                          onPointSelected: (idx) {},
                        ),
                      ],
                    ),
                  ),
                ),
                VerticalDivider(color: AppColors.white.withOpacity(0.05), width: 1),
                // --- RIGHT COLUMN: COMPARISON ---
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('DATA COMPARISON', isCompact),
                        SizedBox(height: isCompact ? 24.h : 20.0),
                        SleepComparisonWidget(
                          idx1: _comparePointA,
                          idx2: _comparePointB,
                          dates: dates,
                          data: data,
                          use24HourClock: provider.settings.use24HourClock,
                          isCompact: isCompact,
                          onPointAChanged: (idx) => setState(() => _comparePointA = idx),
                          onPointBChanged: (idx) => setState(() => _comparePointB = idx),
                        ),
                        SizedBox(height: 40.h),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          // --- MOBILE: SINGLE COLUMN ---
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
            child: Column(
              children: [
                SizedBox(height: 12.h),
                _buildSectionTitle('SLEEP TRENDS', isCompact),
                SizedBox(height: 24.h),
                SleepAnalyticalGraph(
                  dates: dates,
                  data: data,
                  visibleMetrics: _visibleMetrics,
                  onPointSelected: (idx) {},
                ),
                SizedBox(height: 32.h),
                _buildSectionTitle('DATA COMPARISON', isCompact),
                SizedBox(height: 24.h),
                SleepComparisonWidget(
                  idx1: _comparePointA,
                  idx2: _comparePointB,
                  dates: dates,
                  data: data,
                  use24HourClock: provider.settings.use24HourClock,
                  isCompact: isCompact,
                  onPointAChanged: (idx) => setState(() => _comparePointA = idx),
                  onPointBChanged: (idx) => setState(() => _comparePointB = idx),
                ),
                SizedBox(height: 40.h),
              ],
            ),
          );
        },
      ),
    );
  }

  // Remove _buildMetricToggle as it's no longer used


  Widget _buildHistoryTab(SleepProvider provider, bool isCompact) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth > 700;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- LEFT COLUMN: CALENDAR ---
              Expanded(
                flex: 5,
                child: Container(
                  color: AppColors.background,
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 20.0),
                          child: _buildCustomExpandedCalendar(dateSet, isCompact),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(color: AppColors.white.withOpacity(0.05), width: 1),
              // --- RIGHT COLUMN: SLIDER + LOGS ---
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildHorizontalCalendar(dateSet, isCompact),
                    const Divider(color: Colors.white10, height: 1),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () => provider.forceRefresh(),
                        color: AppColors.crimson,
                        backgroundColor: AppColors.surface,
                        child: historyLogs.isEmpty
                            ? Center(
                                child: Text(
                                  "No logs for this date.",
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: isCompact ? 13.sp : 12.0),
                                ),
                              )
                            : ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(20.0),
                                itemCount: historyLogs.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12.0),
                                itemBuilder: (context, index) {
                                  final log = historyLogs[index];
                                  return Dismissible(
                                    key: Key("sleep_log_${log.id}"),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: EdgeInsets.only(right: 24.0),
                                      decoration: BoxDecoration(
                                        color: AppColors.error.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(20.r),
                                      ),
                                      child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
                                    ),
                                    confirmDismiss: (direction) => _confirmDelete(context, provider, log.id),
                                    onDismissed: (_) => provider.deleteLog(log.id),
                                    child: _buildHistoryCard(context, provider, log, isCompact),
                                  );
                                },
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // --- MOBILE: SINGLE COLUMN ---
        if (_isCalendarExpanded) {
          return Container(
            color: AppColors.background,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _buildCustomExpandedCalendar(dateSet, isCompact),
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
            _buildHorizontalCalendar(dateSet, isCompact),
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
                            child: _buildHistoryCard(context, provider, log, isCompact),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomExpandedCalendar(Set<DateTime> dateSet, bool isCompact) {
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstDayOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday;
    final isCurrentMonth = _displayedMonth.year == DateTime.now().year && _displayedMonth.month == DateTime.now().month;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 16.0, vertical: isCompact ? 10.h : 8.0),
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
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(foregroundColor: AppColors.crimson),
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
                  style: AppTextStyles.labelMedium.copyWith(color: Colors.white, letterSpacing: 1.5, fontSize: isCompact ? 14.sp : 14.0),
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
          SizedBox(height: isCompact ? 10.h : 8.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["M", "T", "W", "T", "F", "S", "S"].map((d) => Expanded(
              child: Text(d, textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), fontSize: isCompact ? 10.sp : 10.0)),
            )).toList(),
          ),
          SizedBox(height: isCompact ? 10.h : 8.0),
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
                          fontWeight: FontWeight.w500,
                          fontSize: isCompact ? 12.sp : 12.0,
                        ),
                      ),
                      if (hasData && !isSelected)
                        Positioned(
                          bottom: isCompact ? 4.h : 4.0,
                          child: Container(
                            width: isCompact ? 3.r : 3.0,
                            height: isCompact ? 3.r : 3.0,
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

  Widget _buildHorizontalCalendar(Set<DateTime> dateSet, bool isCompact) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: isCompact ? 90.h : 80.0,
      padding: EdgeInsets.symmetric(vertical: isCompact ? 10.h : 8.0),
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
              margin: EdgeInsets.symmetric(horizontal: isCompact ? 6.w : 6.0),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.crimson : Colors.transparent,
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
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
                      fontSize: isCompact ? 10.sp : 10.0,
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.textSecondary : AppColors.textSecondary.withValues(alpha: 0.2)),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isCompact ? 4.h : 4.0),
                  Text(
                    dateOnly.day.toString(),
                    style: AppTextStyles.h3.copyWith(
                      fontSize: isCompact ? 16.sp : 16.0,
                      color: isSelected 
                          ? Colors.white 
                          : (hasData ? AppColors.white : AppColors.white.withValues(alpha: 0.15)),
                    ),
                  ),
                  if (hasData && !isSelected)
                    Container(
                      margin: EdgeInsets.only(top: isCompact ? 4.h : 4.0),
                      width: isCompact ? 4.r : 4.0,
                      height: isCompact ? 4.r : 4.0,
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

  Widget _buildHistoryCard(BuildContext context, SleepProvider provider, SleepLog log, bool isCompact) {
    final hours = log.duration.inHours;
    final minutes = log.duration.inMinutes % 60;
    final dateStr = DateFormat('MMM dd, yyyy').format(log.wakeUpTime);
    
    final String bedTimeStr = _formatTime(TimeOfDay.fromDateTime(log.bedtime), provider.settings.use24HourClock);
    final String wakeTimeStr = _formatTime(TimeOfDay.fromDateTime(log.wakeUpTime), provider.settings.use24HourClock);
    final timeStr = "$bedTimeStr - $wakeTimeStr";

    return Container(
      padding: EdgeInsets.all(isCompact ? 16.r : 14.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 12.r : 10.0),
                decoration: BoxDecoration(
                  color: log.type == SleepType.night ? AppColors.crimson.withValues(alpha: 0.1) : Colors.amber.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  log.type == SleepType.night ? Icons.bedtime_rounded : Icons.wb_sunny_rounded,
                  color: log.type == SleepType.night ? AppColors.crimson : Colors.amber,
                  size: isCompact ? 20.r : 18.0,
                ),
              ),
              SizedBox(width: isCompact ? 16.w : 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "${hours}h ${minutes}m",
                      style: AppTextStyles.labelMedium.copyWith(fontSize: isCompact ? 16.sp : 14.0, color: AppColors.white),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      dateStr,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: isCompact ? 10.sp : 9.0),
                    ),
                    Text(
                      timeStr,
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: isCompact ? 9.sp : 8.0),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  Icons.star_rounded,
                  size: isCompact ? 12.r : 12.0,
                  color: i < log.quality 
                    ? (log.type == SleepType.night ? AppColors.crimson : Colors.amber) 
                    : AppColors.white.withValues(alpha: 0.1),
                )),
              ),
            ],
          ),
          if (log.note.isNotEmpty) ...[
            SizedBox(height: isCompact ? 16.h : 14.0),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isCompact ? 12.r : 10.0),
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
                      fontSize: isCompact ? 8.sp : 8.0,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    log.note,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: isCompact ? 11.sp : 11.0,
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

  Widget _buildEnhancedAlarmCard(SleepAlarmProvider alarmProvider, bool isCompact) {
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
          isCompact: isCompact,
          onToggle: (val) {
             if (val) {
                // Optimistic UI update
                alarmProvider.updateSettings(bedtimeEnabled: true);
                // Background permission check
                alarmProvider.checkAndRequestPermissions(context).then((ok) {
                   if (!ok) {
                      // Revert if denied
                      alarmProvider.updateSettings(bedtimeEnabled: false);
                   }
                });
             } else {
                alarmProvider.updateSettings(bedtimeEnabled: false);
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
        SizedBox(height: isCompact ? 12.h : 10.0),
        _buildSystemTimeTile(
          title: "Wake Up Alarm",
          subtitle: "Growth Protocol Active",
          icon: Icons.wb_sunny_rounded,
          iconColor: Colors.amber,
          time: TimeOfDay(hour: settings.wakeUpHour, minute: settings.wakeUpMinute),
          isEnabled: settings.wakeUpEnabled,
          audioName: settings.wakeUpAudioPath != null ? settings.wakeUpAudioPath!.split('/').last : 'Standard',
          use24HourClock: context.read<SleepProvider>().settings.use24HourClock,
          isCompact: isCompact,
          onToggle: (val) {
             if (val) {
                // Optimistic UI update
                alarmProvider.updateSettings(wakeUpEnabled: true);
                // Background permission check
                alarmProvider.checkAndRequestPermissions(context).then((ok) {
                   if (!ok) {
                      // Revert if denied
                      alarmProvider.updateSettings(wakeUpEnabled: false);
                   }
                });
             } else {
                alarmProvider.updateSettings(wakeUpEnabled: false);
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
    required bool isCompact,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(isCompact ? 24.r : 20.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(isCompact ? 20.w : 16.0, isCompact ? 16.h : 14.0, isCompact ? 12.w : 10.0, isCompact ? 8.h : 6.0),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 10.r : 8.0),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: isCompact ? 20.r : 18.0),
                ),
                SizedBox(width: isCompact ? 14.w : 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.labelMedium.copyWith(color: AppColors.white, fontSize: isCompact ? 14.sp : 12.0)),
                      Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: isCompact ? 9.sp : 8.0)),
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
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 14.0),
                      child: Column(
                        children: [
                          Text("SCHEDULED", style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 8.sp : 8.0, color: AppColors.textSecondary, letterSpacing: 1)),
                          SizedBox(height: isCompact ? 4.h : 4.0),
                          Text(
                            _formatTime(time, use24HourClock), 
                            style: AppTextStyles.h2.copyWith(
                              fontSize: isCompact ? 22.sp : 18.0, 
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
                      padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 14.0, horizontal: isCompact ? 16.w : 14.0),
                      child: Column(
                        children: [
                          Text("ALARM TONE", style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 8.sp : 8.0, color: AppColors.textSecondary, letterSpacing: 1)),
                          SizedBox(height: isCompact ? 6.h : 4.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.graphic_eq_rounded, size: isCompact ? 12.r : 12.0, color: AppColors.crimson),
                              SizedBox(width: isCompact ? 6.w : 4.0),
                              Flexible(
                                child: Text(
                                  audioName.toUpperCase(),
                                  style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 10.sp : 10.0, color: AppColors.white, fontWeight: FontWeight.w500),
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







































  Widget _buildSectionTitle(String title, bool isCompact) {
    return Row(
      children: [
        Container(
          width: 3.0, 
          height: isCompact ? 12.h : 10.0, 
          decoration: BoxDecoration(color: AppColors.crimson, borderRadius: BorderRadius.circular(2.r))
        ),
        SizedBox(width: 8.w),
        Text(
          title, 
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontSize: isCompact ? 11.sp : 9.0,
          )
        ),
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
  final bool isCompact;

  const SleepComparisonWidget({
    super.key,
    required this.idx1,
    required this.idx2,
    required this.dates,
    required this.data,
    required this.onPointAChanged,
    required this.onPointBChanged,
    required this.use24HourClock,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isCompact ? 28.r : 20.0),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPointPicker("POINT A", idx1, idx2, dates, onPointAChanged, context),
              SizedBox(width: isCompact ? 16.w : 12.0),
              _buildPointPicker("POINT B", idx2, idx1, dates, onPointBChanged, context, isEnd: true),
            ],
          ),
          if (idx1 != null && idx2 != null) ...[
            SizedBox(height: isCompact ? 24.h : 20.0),
            _buildComparisonDetails(),
          ] else ...[
            SizedBox(height: isCompact ? 32.h : 24.0),
            Center(
              child: Text(
                "SELECT TWO POINTS TO COMPARE",
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.2), fontSize: isCompact ? 11.sp : 9.0),
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
                    padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: isCompact ? 12.r : 10.0),
                  ),
                ),
                SizedBox(width: isCompact ? 8.w : 6.0),
              ],
              Text(title, style: AppTextStyles.labelSmall.copyWith(color: selectedIdx != null ? AppColors.crimson : AppColors.textSecondary.withValues(alpha: 0.4), fontSize: isCompact ? 11.sp : 9.0, fontWeight: FontWeight.w500, letterSpacing: 2)),
              if (selectedIdx != null && !isEnd) ...[
                SizedBox(width: isCompact ? 8.w : 6.0),
                GestureDetector(
                  onTap: () => onChanged(null),
                  child: Container(
                    padding: EdgeInsets.all(isCompact ? 4.r : 4.0),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded, color: AppColors.error, size: isCompact ? 12.r : 10.0),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: isCompact ? 10.h : 8.0),
          GestureDetector(
            onTap: () => _showPicker(context, selectedIdx, otherIdx, dates, onChanged),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 14.w : 12.0, vertical: isCompact ? 12.h : 10.0),
              decoration: BoxDecoration(
                color: selectedIdx != null ? AppColors.crimson.withValues(alpha: 0.05) : AppColors.surfaceLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
                border: Border.all(color: selectedIdx != null ? AppColors.crimson.withValues(alpha: 0.4) : AppColors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selectedIdx != null ? Icons.event_available_rounded : Icons.event_note_rounded, color: AppColors.crimson, size: isCompact ? 18.r : 16.0),
                  SizedBox(width: isCompact ? 10.w : 8.0),
                  Flexible(child: Text(selectedIdx != null ? labels[selectedIdx] : "SET POINT", overflow: TextOverflow.ellipsis, style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 11.sp : 10.0, color: selectedIdx != null ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.4)))),
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
        padding: EdgeInsets.fromLTRB(isCompact ? 24.w : 20.0, isCompact ? 12.h : 10.0, isCompact ? 24.w : 20.0, isCompact ? 40.h : 32.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0)),
          border: Border.all(color: AppColors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isCompact ? 40.w : 40.0, height: isCompact ? 4.h : 4.0, margin: EdgeInsets.only(bottom: isCompact ? 24.h : 20.0),
              decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.2), borderRadius: BorderRadius.circular(2.r)),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isCompact ? 10.r : 8.0),
                  decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.event_note_rounded, color: AppColors.crimson, size: isCompact ? 24.r : 20.0),
                ),
                SizedBox(width: isCompact ? 16.w : 12.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SELECT LOG", style: AppTextStyles.h3.copyWith(fontSize: isCompact ? 20.sp : 18.0)), // Fixed size
                      Text("CHOOSE A DATE FROM YOUR LOGS", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.5), letterSpacing: 1, fontSize: isCompact ? 11.sp : 10.0)), // Fixed size
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isCompact ? 24.h : 20.0),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: sortedDateKeys.length,
                separatorBuilder: (context, index) => SizedBox(height: isCompact ? 12.h : 10.0),
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
                            padding: EdgeInsets.all(isCompact ? 24.r : 20.0),
                            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(isCompact ? 32.r : 24.0))),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text("SELECT TIME", style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson, letterSpacing: 1.2, fontSize: isCompact ? 14.sp : 12.0)), // Fixed size
                                SizedBox(height: 20.h),
                                ...indices.map((idx) {
                                  final bool isCurrent = idx == current;
                                  final bool isOther = idx == other;
                                  return ListTile(
                                    contentPadding: EdgeInsets.symmetric(horizontal: isCompact ? 16.w : 12.0),
                                    leading: Icon(
                                      isCurrent ? Icons.check_circle_rounded : (isOther ? Icons.info_outline_rounded : Icons.radio_button_off_rounded),
                                      color: isCurrent ? AppColors.crimson : (isOther ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.textSecondary.withValues(alpha: 0.2)),
                                    ),
                                    title: Text(
                                      use24HourClock 
                                          ? DateFormat('HH:mm').format(dates[idx])
                                          : DateFormat('hh:mm a').format(dates[idx]),
                                      style: AppTextStyles.labelSmall.copyWith(color: isCurrent ? Colors.white : (isOther ? AppColors.textSecondary.withValues(alpha: 0.5) : AppColors.textSecondary), fontSize: isCompact ? 11.sp : 10.0), // Fixed size
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
                      padding: EdgeInsets.all(isCompact ? 16.r : 14.0),
                      decoration: BoxDecoration(
                        color: isPartiallySelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.background.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
                        border: Border.all(
                          color: isPartiallySelected ? AppColors.crimson : (isOccupiedByOther ? AppColors.crimson.withValues(alpha: 0.3) : AppColors.white.withValues(alpha: 0.05)),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPartiallySelected ? Icons.check_circle_rounded : (isOccupiedByOther ? Icons.info_outline_rounded : Icons.calendar_today_rounded),
                            color: isPartiallySelected ? AppColors.crimson : (isOccupiedByOther ? AppColors.crimson.withValues(alpha: 0.5) : AppColors.textSecondary.withValues(alpha: 0.2)),
                            size: isCompact ? 20.r : 18.0,
                          ),
                          SizedBox(width: isCompact ? 16.w : 12.0),
                          Text(
                            DateFormat('MMMM dd, yyyy').format(displayDate).toUpperCase(),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: isPartiallySelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: isCompact ? 12.sp : 11.0, // Fixed size
                            ),
                          ),
                          const Spacer(),
                          if (indices.length > 1)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: isCompact ? 8.w : 6.0, vertical: isCompact ? 4.h : 2.0),
                              decoration: BoxDecoration(color: AppColors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(isCompact ? 8.r : 6.0)),
                              child: Text("${indices.length} LOGS", style: AppTextStyles.labelSmall.copyWith(fontSize: isCompact ? 9.sp : 8.0, color: AppColors.textSecondary.withValues(alpha: 0.5))), // Fixed size
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
          padding: EdgeInsets.symmetric(vertical: isCompact ? 20.h : 16.0),
          child: Text(
            "NO OVERLAPPING METRICS ON THESE DATES", 
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.3), fontSize: isCompact ? 10.sp : 8.0)
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
      margin: EdgeInsets.only(bottom: isCompact ? 16.h : 12.0),
      padding: EdgeInsets.all(isCompact ? 20.r : 16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(isCompact ? 20.r : 16.0),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w500, fontSize: isCompact ? 13.sp : 12.0, letterSpacing: 1)),
              Row(
                children: [
                  Icon(delta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, size: isCompact ? 18.r : 16.0),
                  SizedBox(width: isCompact ? 6.w : 4.0),
                  Text("${delta >= 0 ? '+' : ''}${percent.toStringAsFixed(1)}%", style: AppTextStyles.labelSmall.copyWith(color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w500, fontSize: isCompact ? 13.sp : 12.0)),
                ],
              ),
            ],
          ),
          SizedBox(height: isCompact ? 20.h : 16.0),
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
        Text(l, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.4), fontSize: isCompact ? 10.sp : 9.0, fontWeight: FontWeight.w500)),
        SizedBox(height: isCompact ? 4.h : 2.0),
        Text("${v >= 0 && isDelta ? '+' : ''}${v.toStringAsFixed(1)}$u", style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w500, fontSize: isCompact ? 15.sp : 14.0)),
      ],
    );
  }
}
