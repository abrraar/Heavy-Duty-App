# Upgrade AGP and compileSdk

This plan upgrades the Android Gradle Plugin (AGP) and the `compileSdk` version to their latest stable releases as of August 2026.

## Proposed Changes

### Android Project Configuration

#### [MODIFY] [build.gradle.kts](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/android/build.gradle.kts)
- Upgrade the Android Gradle Plugin version from `8.7.3` to `9.3.1`.

#### [MODIFY] [app/build.gradle.kts](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/android/app/build.gradle.kts)
- Upgrade the `compileSdk` version from `34` to `36`.

## Verification Plan

### Automated Tests
- Run `./gradlew assembleDebug` to ensure the project builds correctly with the new plugin and SDK versions.

### Manual Verification
- Verify that Android Studio recognizes the new SDK version and that there are no synchronization errors.
