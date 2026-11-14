# Termul POD Video

A separate Flutter Android application for photo/video proof of delivery (POD). This repository is intentionally independent from TERMULSCAN.

## Current foundation

- Material 3 dashboard with Documentation, History, and Settings navigation.
- Separate entry points for photo and video POD workflows.
- Planned offline-first storage and timestamp/GPS watermark modules; these features are not implemented yet.
- GitHub Actions runs static analysis, widget tests, and an Android release-mode APK build.
- A successful push build publishes the APK to a GitHub Release.

## CI build

The workflow uses Java 21 and the current Flutter stable channel. It generates the Android platform directory if missing, applies the idempotent Android configuration script, then runs:

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --no-pub --build-number="$GITHUB_RUN_NUMBER"
```

The build number is taken from the GitHub Actions run number. The workflow does not upload Actions artifacts; it attaches `app-release.apk` to a GitHub Release named `build-N`.

## Android configuration

`tool/configure_android.py` adds INTERNET, CAMERA, RECORD_AUDIO, and location permissions, declares camera/GPS hardware features as optional, and sets Android `minSdk` to at least 24. It is safe to run more than once.

The script does not access or modify any keystore and does not configure permanent signing.

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

1. Camera capture and lifecycle/permission handling.
2. GPS acquisition, accuracy display, and reverse geocoding.
3. Photo/video watermark renderer with selectable layouts.
4. Local media index, history, and safe cleanup.
5. Offline tests and device-level verification.
