# Termul POD Video

A separate Flutter Android application for photo/video proof of delivery (POD). This repository is intentionally independent from TERMULSCAN.

## Current foundation

- Material 3 dashboard with Documentation, History, and Settings navigation.
- Separate entry points for photo and video POD workflows.
- Working photo/video camera preview and capture with back-camera preference.
- Capture timestamp and optional GPS coordinates/accuracy are recorded as metadata.
- Photo/video files are copied into app-private local storage and indexed for the History screen.
- History displays saved photos and metadata and supports deleting a selected record.
- Photo watermark is burned into the saved JPEG with capture time, GPS coordinates (when available), and accuracy. Video watermark and address reverse-geocoding remain planned.
- GitHub Actions runs static analysis, widget tests, and an Android release-mode APK build.
- A successful push build publishes the APK to a GitHub Release.

## CI build

The workflow uses Java 21 and pins Flutter 3.50.0 for reproducible builds. It generates the Android platform directory if missing, applies the idempotent Android configuration script, then runs:

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --no-pub --build-number="$GITHUB_RUN_NUMBER"
```

The build number is taken from the GitHub Actions run number. The workflow does not upload Actions artifacts; it attaches `app-release.apk` to a GitHub Release named `build-N`.

## Android configuration

`tool/configure_android.py` adds INTERNET, CAMERA, RECORD_AUDIO, and location permissions, declares camera/GPS hardware features as optional, and sets Android `minSdk` to at least 24. It is safe to run more than once.

The script does not access, create, replace, or modify any keystore. The generated Flutter Android template debug signing is used for the release-mode APK; it is installable for internal testing, but a different runner-generated debug key can prevent in-place upgrades between builds.

## APK signing note

The CI build uses the generated Flutter Android template's debug signing configuration for the release-mode APK. This is suitable for internal installation/testing only, not production distribution. Because the Android project and debug keystore are generated on the CI runner, a later build may have a different signing certificate; Android may reject it as an update over an APK installed from an earlier run. No existing keystore is changed.

## Local setup

With Flutter installed, run:

```sh
flutter create --platforms=android --org com.termul --project-name termul_pod_video .
python3 tool/configure_android.py
flutter pub get
flutter analyze
flutter test
```

Commit the generated `android/` directory and `.metadata` only if you choose to maintain the Android project in source control. The CI workflow can also generate it when it is absent.

## Roadmap

1. Improve GPS status feedback and add reverse geocoded address metadata.
2. Add configurable photo watermark templates.
3. Implement video watermark overlay/export strategy.
4. Add media playback, sharing/export, and storage management.
5. Complete offline tests and physical-device verification.
