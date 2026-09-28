# AURA — Minimalist Podcast & Audiobook Player

<p align="center">
  <b>A minimalist, warm-cream aesthetic podcast & audiobook listening application built with Flutter.</b>
</p>

---

## ✨ Features

- **🎧 Premium Audio Player**: Powered by `media_kit` and `audio_service` for seamless playback, live waveforms, pitch/speed controls, lock-screen media controls, and background audio service.
- **📚 Curated Free Audiobooks**: Integrated with the LibriVox and Internet Archive catalog, featuring classic novels, poetry, philosophy, and Hindi literature with full chapter navigation and progress tracking.
- **🎙️ Podcast Discovery**: Explore trending episodes, top podcasters, and curated regional and global collections.
- **⚡ Smart Streaming & Link Resolver**: Paste direct audio or video links for instant, buffer-resilient streaming.
- **🔄 In-App Auto-Update System**: Integrated version checker with elegant dismissible in-app alerts and direct website/APK download support.
- **🎨 Warm Cream & Luxury Dark Themes**: Designed with curated HSL color schemes, typography via Google Fonts (DM Sans), and micro-animations.
- **💾 Local Caching & Offline History**: Offline listening history, favorites, bookmark quotes, and resume points.

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.12.1)
- Android Studio / Xcode / VS Code

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/zen-void59/AURA---Podcast-AudioBooks-listening-app.git
   cd AURA---Podcast-AudioBooks-listening-app
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   flutter run
   ```

---

## 📦 Building for Production

### Android Release APK

```bash
flutter build apk --release
```
The output APK will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

### Configuring Release Signing (Optional)

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Update the credentials with your `.jks` keystore details:
   ```properties
   keyAlias=aura_release_key
   keyPassword=your_password
   storeFile=../keystore/aura-release-key.jks
   storePassword=your_password
   ```

---

## 🔄 Self-Hosted In-App Updates

AURA includes a built-in auto-update system configured for direct website / APK distribution.

1. Update `version.json` with your latest release info:
   ```json
   {
     "latest_version": "1.0.1",
     "version_code": 2,
     "title": "AURA Update Available!",
     "release_notes": "• Faster audio streaming\n• Improved audiobook covers\n• Bug fixes",
     "download_url": "https://yourwebsite.com/downloads/aura-v1.0.1.apk",
     "mandatory": false
   }
   ```
2. Host `version.json` on your website or GitHub repository.
3. Configure `updateCheckUrl` in `lib/core/constants.dart`.

---

## 🧪 Testing & Analysis

Run the test suite:
```bash
flutter test
```

Run static analysis:
```bash
flutter analyze
```

---

## 📄 License

This project is licensed under the MIT License.
