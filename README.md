# Termul POD Video

A separate Flutter Android application for photo/video proof of delivery (POD). This repository is intentionally independent from TERMULSCAN.

## Current foundation

- Material 3 dashboard with Documentation, History, and Settings navigation.
- Separate entry points for photo and video POD workflows.
- Working photo/video camera preview and capture with back-camera preference.
- Capture timestamp and optional GPS coordinates/accuracy are recorded as metadata, together with the age of the GPS fix and whether Android flagged it as a mock location.
- Photo/video files are copied into app-private local storage and indexed for the History screen.
- History displays saved photos and metadata and supports deleting a selected record.
- Photo and video watermarks are burned into saved media with capture time, GPS coordinates, accuracy, and reverse-geocoded address when available. Video export uses the native MediaCodec/OpenGL pipeline through watermark_kit; if processing fails, the original recording is still saved and the failure is recorded in history.
- GitHub Actions runs static analysis, widget tests, and an Android release-mode APK build.
- A successful push build publishes the APK to a GitHub pre-release tagged at the commit that was built.

## CI build

The workflow uses Java 21 and pins Flutter 3.50.0 for reproducible builds. It generates the Android platform directory if missing, applies the idempotent Android configuration script, then runs:

```sh
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --no-pub --build-number="$GITHUB_RUN_NUMBER"
```

The build number is taken from the GitHub Actions run number. The workflow does not upload Actions artifacts; it attaches `app-release.apk` to a GitHub pre-release named `build-N`, created with `--target` so the tag points at the built commit. The release is skipped when a newer commit has already landed on the branch. Pull requests from branches of this repository are not built a second time because their push run already covers them; fork PRs still build but never publish.

## Location and capture behaviour

While the camera screen is open, `PodLocationTracker` keeps a live GPS fix. A capture snapshots the position at the shutter (photo) or when recording starts (video), and the address lookup runs while the picture is being taken, not after it. If there is no fresh fix it waits up to 4 s for the next reading, then falls back to a last-known position no older than 5 minutes; otherwise the media is saved without coordinates. Addresses are reused for captures within 30 m of each other.

Location permission is requested after the camera is ready, so the two dialogs never stack. The camera is released only when the app is truly backgrounded (`paused`), not for permission dialogs or the notification shade.

The camera screen shows the GPS state live (searching, weak accuracy above 50 m, mock location, permission or service problems), and the History list repeats the mock/weak-accuracy warning. Captures are never blocked by these flags; they are recorded so they can be reviewed.

Raw camera files and intermediate watermark copies are removed after a successful save, the saved file is moved rather than copied, and a startup sweep deletes image/video leftovers older than 6 hours from the cache directory.

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

1. Add configurable photo and video watermark templates.
2. Add media playback, sharing/export, and storage management.
3. Complete physical-device verification for video codec, audio passthrough, and long recordings.
