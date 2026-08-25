# Implementation Plan - Modernizing Plugins for AGP 9.0+

This plan outlines the steps to replace legacy/unmaintained plugins with modern, AGP 9.0+ compatible alternatives and clean up Gradle configurations.

## Proposed Changes

### Dependencies

#### [MODIFY] [pubspec.yaml](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/pubspec.yaml)
- Remove `flutter_timezone`, `file_picker`, and `alarm`.
- Add `flutter_native_timezone_plus`, `file_selector`, and `android_alarm_manager_plus`.
- Run `flutter pub get`.

---

### Android Configuration

#### [MODIFY] [gradle.properties](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/android/gradle.properties)
- Remove legacy flags: `android.builtInKotlin=false` and `android.newDsl=false`.

#### [MODIFY] [build.gradle.kts](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/android/app/build.gradle.kts)
- Add modern Kotlin compiler options for JVM 17.

---

### Dart Code Refactoring

#### [MODIFY] [notification_service.dart](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/lib/core/services/notification_service.dart)
- Replace `flutter_timezone` with `flutter_native_timezone_plus`.
- Update `FlutterTimezone.getLocalTimezone()` to `FlutterNativeTimezonePlus.getLocalTimezone()`.

#### [MODIFY] [sleep_screen.dart](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/lib/features/tracker/sleep/sleep_screen.dart)
- Replace `file_picker` with `file_selector`.
- Update file picking logic to use `openFile` and `XTypeGroup`.

#### [MODIFY] [main.dart](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/lib/main.dart)
- Initialize `AndroidAlarmManager`.

#### [MODIFY] [sleep_alarm_provider.dart](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/lib/features/tracker/sleep/provider/sleep_alarm_provider.dart)
- Replace `alarm` package usage with `android_alarm_manager_plus`.
- Refactor alarm scheduling and management logic.

## Verification Plan

### Automated Tests
- Run `flutter clean` and `flutter pub get`.
- Attempt a build: `flutter build apk --debug`.

### Manual Verification
- Verify timezone detection in logs/UI.
- Test file selection in the Sleep Screen.
- Verify alarm scheduling functionality.
