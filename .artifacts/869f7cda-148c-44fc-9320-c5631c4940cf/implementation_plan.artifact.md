# Fix Android Extension Type Mismatch Error

The error `Android extension 'android' is of type ... ApplicationExtensionImpl$AgpDecorated_Decorated, expected BaseExtension` occurs because the current versions of the Android Gradle Plugin (AGP) and Gradle are likely ahead of what the Flutter Gradle plugin supports. Specifically, AGP 9.3.1 uses a decorated extension type that the Flutter plugin's internal type checks do not yet recognize or handle correctly.

To fix this, we will downgrade AGP and Gradle to stable, widely-supported versions (AGP 8.7.0 and Gradle 8.10.2) and adjust the `compileSdk` to a stable version (35).

## Proposed Changes

### Build Configuration

#### [MODIFY] [build.gradle.kts](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/android/build.gradle.kts)
- Downgrade AGP classpath from `9.3.1` to `8.7.0`.

#### [MODIFY] [settings.gradle.kts](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/android/settings.gradle.kts)
- Downgrade AGP plugin versions from `9.3.1` to `8.7.0`.

#### [MODIFY] [gradle-wrapper.properties](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/android/gradle/wrapper/gradle-wrapper.properties)
- Downgrade Gradle distribution from `9.7.0` to `8.10.2`.

#### [MODIFY] [app/build.gradle.kts](file:///C:/Users/Abrar/Documents/Developer/heavy_duty/android/app/build.gradle.kts)
- Change `compileSdk` from `37` to `35` (Android 15).

## Verification Plan

### Automated Tests
- Run `./gradlew :app:assembleDebug` to verify the build completes successfully.
- Trigger a Gradle Sync in Android Studio to ensure the error is resolved.

### Manual Verification
- Verify that the `android` block in `app/build.gradle.kts` is correctly recognized by the IDE.
