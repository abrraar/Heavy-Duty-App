// dimensions.dart

// 1. DEFINE BREAKPOINTS: Using logical pixels (dp) following Material 3 guidelines
const double kMobileBreakpoint = 600.0;
const double kTabletBreakpoint = 900.0; // Adjusted for better foldable/tablet transition
const double kDesktopBreakpoint = 1200.0;

// 2. ASPECT RATIO & ORIENTATION BREAKPOINTS
const double kTallDeviceRatio = 2.0; // e.g. 21:9 phones
const double kSquareDeviceRatio = 1.2; // e.g. Unfolded foldables / narrow tablets

// 3. UNIFIED SPACING GRID: Standardized spacing tokens
const double kOuterPaddingMobile = 16.0;
const double kOuterPaddingTablet = 24.0;
const double kOuterPaddingDesktop = 32.0;

// Content Constraints
const double kMaxContentWidth = 1100.0;
const double kMaxFormWidth = 460.0;

// Compatibility Aliases
const double kCompactBreakpoint = kMobileBreakpoint;
const double kMediumBreakpoint = kTabletBreakpoint;
const double kExpandedBreakpoint = kDesktopBreakpoint;

// UI Element Sizes
const double kNavRailWidth = 84.0;
const double kBottomNavBarHeight = 70.0;
const double kTopAppBarHeight = 100.0;
