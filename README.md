# Termul POD Video

A separate Flutter Android application for photo/video proof of delivery (POD). This repository is intentionally independent from TERMULSCAN.

## Current foundation

- Material 3 dashboard with Documentation, History, and Settings navigation.
- Separate entry points for photo and video POD workflows.
- Planned offline-first storage and timestamp/GPS watermark modules.
- GitHub Actions workflow for analysis, tests, and unsigned release APK builds.
- Optional GitHub Release publishing through manual workflow dispatch.

## Build

The GitHub Actions workflow installs Java 17 and Flutter stable, generates the Android platform directory when it is absent, then runs:

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

No permanent signing keystore is configured or modified. The APK is intended as an unsigned release build.

## Roadmap

1. Camera capture and lifecycle/permission handling.
2. GPS acquisition, accuracy display, and reverse geocoding.
3. Photo/video watermark renderer with selectable layouts.
4. Local media index, history, and safe cleanup.
5. Offline tests and device-level verification.
