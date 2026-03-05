# VoiceCoach

VoiceCoach is a SwiftUI vocal practice app for iOS, iPadOS, and Mac Catalyst. Import instructor demo videos as exercises, record your own attempts, review attempts inline, rate takes, and organize practice routines with playlists.

## Current Features

- Exercise library with title/category/session metadata
- Instructor video import via `PhotosPicker` (video-only selection)
- Attempt recording with front camera + microphone
- Exercise detail workflow with:
  - demo video playback
  - inline attempt playback selection
  - sort order toggle (newest/oldest)
  - quick attempt deletion
- Per-attempt 1-5 star ratings (in exercise detail and global feed)
- Global full-screen vertical feed across all attempts
- Playlist creation, editing, reordering, and playlist-mode exercise navigation
- Keyboard and menu-driven navigation for Mac Catalyst and hardware keyboards

## Keyboard Shortcuts

- `Cmd+1` / `Cmd+2` / `Cmd+3`: switch tabs (Exercises / Feed / Playlists)
- `Cmd+N`: start a new attempt in exercise detail
- `,` and `.`: previous/next attempt (exercise detail and feed)
- `Option+1` ... `Option+5`: rate selected attempt
- `Esc`: return from selected attempt to demo video
- `[` and `]`: previous/next exercise inside playlist mode

## Requirements

- Xcode 16+
- iOS 17+ deployment target
- macOS 14+ (for Mac Catalyst)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) for project generation from `project.yml`

## Setup

```bash
brew install xcodegen
git clone https://github.com/donbox/voice-coach.git
cd voice-coach
xcodegen generate
```

## Build and Run

Use the helper script:

```bash
./build.sh        # compile check on iOS Simulator
./build.sh sim    # build + install + launch in iPad simulator
./build.sh mac    # build + launch Mac Catalyst app
```

Or in Xcode:

- Open `VoiceCoach.xcodeproj`
- Select an iOS simulator/device or Mac Catalyst destination
- Run with `Cmd+R`

## Testing

Run all tests:

```bash
xcodebuild test \
  -project VoiceCoach.xcodeproj \
  -scheme VoiceCoach \
  -destination "platform=iOS Simulator,name=iPad (A16)" \
  -only-testing:VoiceCoachTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

Test coverage currently includes:

- `VoiceCoachTests/VideoStorageServiceTests.swift`: video file pathing/import/delete behavior
- `VoiceCoachTests/ModelTests.swift`: SwiftData model relationships and persistence behavior
- `VoiceCoachTests/RecordingServiceTests.swift`: recording session lifecycle and crash-regression coverage

## Project Structure

```text
VoiceCoach/
├── Commands/             App command/menu wiring and focused scene actions
├── Models/               SwiftData models (Exercise, Attempt, Playlist)
├── Services/             Recording + video storage services
├── Utilities/            Transfer helpers (e.g. Photos picker video transferable)
├── Views/
│   ├── Exercises/
│   ├── Feed/
│   ├── Playlists/
│   ├── Recording/
│   └── Components/
├── Preview Content/      In-memory preview seed data
└── Resources/            App assets
```

## Architecture Notes

- Persistence uses SwiftData with direct `@Query` usage in SwiftUI views; all data is stored locally on-device with no cloud sync
- Video files are stored under `Documents/VoiceCoachMedia` using relative paths in models
- Recording is powered by AVFoundation (`AVCaptureSession` + `AVCaptureMovieFileOutput`)
- App and exercise actions are exposed through focused scene values for menu/shortcut integration
- Project settings are source-controlled in `project.yml`; regenerate with `xcodegen generate` after config changes
