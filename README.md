# iPhone-Style Launcher — Flutter

A polished, iPhone-inspired launcher interface written in **Flutter/Dart**. Flutter is the primary implementation for the new launcher UI; the older Godot prototype remains in the repository for reference.

## Flutter features

- iPhone-inspired home screen
- Responsive 4-column app grid
- Glassmorphism cards and dock
- Weather and battery widgets
- Search overlay with app suggestions
- Control Center-style overlay
- Wi-Fi, Bluetooth and flashlight toggles
- Brightness and volume sliders
- App preview sheets
- Touch-friendly mobile layout
- Original UI and icons; no Apple proprietary assets

## Run locally

Install Flutter, then run:

```bash
flutter pub get
flutter run
```

The official Flutter documentation covers Android setup and building Android releases. See https://docs.flutter.dev/platform-integration/android and https://docs.flutter.dev/deployment/android.

## GitHub Actions

`.github/workflows/flutter-android.yml` scaffolds the Android platform, runs Flutter analysis, builds a release APK, and uploads the APK as a workflow artifact.

## Important

This project is an iPhone-inspired interface, not an Apple operating-system clone. A true Android home-screen launcher additionally requires Android launcher intent registration and native app-discovery/intent integration. The current Flutter UI is ready for that bridge.

Repository: https://github.com/emzaro731-byte/g
