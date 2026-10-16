---
name: build-android
description: Build Android AARs and the test application with Gradle. Use when you need to build, install, or run an Android variant of a library or application.
---

# Build Android (Gradle) — Skill

Android builds are **not** part of the monorepo CMake build. Each repo that has an Android
port has a self-contained Gradle project at `repos/<name>/build/android/`. Build it with the
Gradle wrapper from that directory, not with CMake.

## Prerequisites

- JDK is not on `PATH`; pass it explicitly via `JAVA_HOME` (`~/.jdks/<jbr-*>`).
- Android SDK path comes from `local.properties` (`sdk.dir=...`) in the Gradle project dir.
- NDK / CMake used for native code are the ones under that SDK, not the monorepo's.

## Build

Run from the repo's Gradle project dir (`repos/<name>/build/android`):

`JAVA_HOME=/home/ivan/.jdks/jbr-21.0.11 ./gradlew :app:assembleDebug --console=plain`

- `:app:assembleDebug` builds the test application APK (`app` module). This is what to build
  for an app-like repo such as `ruisapp`.
- `:<lib>:assembleDebug` (or `:<lib>:assembleRelease`) builds the library AAR only.
- `:<lib>:bundleStaticLibRelease` builds the static-lib AAR used for publishing.
- Use `--offline` if the network is unavailable and dependencies are already cached.
- Native sources are compiled by the module's own `CMakeLists.txt` (e.g.
  `repos/ruisapp/build/android/app/CMakeLists.txt` globs `../../../src/*.cpp` and
  `../../../tests/app/*.cpp`), so editing `src/**` is picked up by the Gradle build.
- All ABIs configured by the module are built (arm64-v8a, armeabi-v7a, x86, x86_64).

APK output: `app/build/outputs/apk/debug/app-debug.apk`.

## Install and run on a connected device

`adb devices -l` to confirm the device, then:

```
adb install -r repos/<name>/build/android/app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n <applicationId>/<activity>
```

For `ruisapp` the component is
`io.github.cppfw.ruisapp_test_app/io.github.cppfw.ruisapp.RuisappActivity`
(`applicationId` is in `app/build.gradle`, activity comes from the library's manifest; the
activity loads the `ruisapp_application` native lib, so the native target name must stay
`ruisapp_application`).

Gradle also provides `:app:installDebug` which builds and installs in one step.

## Verify

```
adb logcat -c
adb shell am start -n <applicationId>/<activity>
adb logcat -d -t 200 | grep -iE "ruisapp|FATAL|AndroidRuntime"
```

The Java side logs under tag `ruisapp java side`; check `adb shell pidof <applicationId>` to
confirm the process is alive.

## Notes

- Java sources of the Android glue live in `repos/<name>/build/android/<lib>/src/main/java/`
  (e.g. `RuisappActivity.java`) and are compiled by the Gradle build, not by CMake — a CMake
  build will not catch Java errors there.
- JNI methods declared `native` in the activity must be registered in
  `JNI_OnLoad()`'s `JNINativeMethod` array (and the array count updated) in
  `src/<name>/glue/android/glue.cxx`.
- Do not commit or push; `local.properties` and `build/` dirs are local artifacts.
