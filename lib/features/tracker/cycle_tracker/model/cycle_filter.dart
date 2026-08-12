import 'package:flutter/material.dart';

class CycleFilter {
  final bool isDescending;
  final DateTimeRange? dateRange;
  final int? year;
  final int? month;
  final Set<String> selectedCycleNames;
  final double? minStrength;
  final double? maxStrength;
  final double? minVolume;
  final double? maxVolume;

  CycleFilter({
    this.isDescending = true,
    this.dateRange,
    this.year,
    this.month,
    this.selectedCycleNames = const {},
    this.minStrength,
    this.maxStrength,
    this.minVolume,
    this.maxVolume,
  });

  CycleFilter copyWith({
    bool? isDescending,
    DateTimeRange? dateRange,
    int? year,
    int? month,
    Set<String>? selectedCycleNames,
    double? minStrength,
    double? maxStrength,
    double? minVolume,
    double? maxVolume,
  }) {
    return CycleFilter(
      isDescending: isDescending ?? this.isDescending,
      dateRange: dateRange ?? this.dateRange,
      year: year ?? this.year,
      month: month ?? this.month,
      selectedCycleNames: selectedCycleNames ?? this.selectedCycleNames,
      minStrength: minStrength ?? this.minStrength,
      maxStrength: maxStrength ?? this.maxStrength,
      minVolume: minVolume ?? this.minVolume,
      maxVolume: maxVolume ?? this.maxVolume,
    );
  }

  bool get isInitial =>
      isDescending == true &&
      dateRange == null &&
      year == null &&
      month == null &&
      selectedCycleNames.isEmpty &&
      minStrength == null &&
      maxStrength == null &&
      minVolume == null &&
      maxVolume == null;
}
