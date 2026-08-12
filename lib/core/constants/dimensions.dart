// dimensions.dart

// 1. DEFINE BREAKPOINTS: Using logical pixels (dp) following Material 3 guidelines
const double kMobileBreakpoint = 600.0;
const double kTabletBreakpoint = 1024.0;
const double kDesktopBreakpoint = 1440.0;

// 2. UNIFIED SPACING GRID: Standardized spacing tokens for consistent adaptive layouts
const double kOuterPadding = 16.0;
const double kGridGap = 16.0;
const double kCardInternalPadding = 16.0;

// Content Constraints
const double kMaxContentWidth = 1024.0;
const double kMaxFormWidth = 480.0;

// Compatibility Aliases
const double kCompactBreakpoint = kMobileBreakpoint;
const double kMediumBreakpoint = kTabletBreakpoint;
const double kExpandedBreakpoint = kDesktopBreakpoint;
