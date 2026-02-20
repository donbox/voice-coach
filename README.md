# VoiceCoach

A SwiftUI vocal coaching app for iOS, iPadOS, and Mac (Catalyst). Students import instructor demo videos as exercises, record their own attempts, and organize exercises into playlists for daily practice routines.

## Features

- **Exercise library** — import instructor demo videos with title, category, and session metadata
- **Recording** — capture audio + video attempts using the front camera
- **Attempt feed** — per-exercise chronological list of recorded attempts with video playback
- **Global feed** — full-screen vertical video feed (TikTok-style) across all exercises
- **Playlists** — create and reorder custom exercise playlists for daily routines
- **Local storage** — all data stored on-device using SwiftData; architected for future iCloud sync

## Requirements

- Xcode 16+ (iOS 17 SDK)
- macOS 14+ (for Mac Catalyst)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — used to generate the `.xcodeproj` from `project.yml`

## Setup

Install XcodeGen if you don't have it:

```bash
brew install xcodegen
```

Clone the repo and generate the Xcode project:

```bash
git clone https://github.com/donbox/voice-coach.git
cd voice-coach
xcodegen generate
```

## Building & Running

A `build.sh` script wraps the common `xcodebuild` commands:

```bash
./build.sh        # compile check against iOS Simulator (shows errors/warnings)
./build.sh sim    # build + install + launch in iPad simulator
./build.sh mac    # build + launch Mac Catalyst app
```

### In Xcode

Open `VoiceCoach.xcodeproj`, select a simulator or device, and press **Cmd+R**.

To run the Mac version from Xcode, select **My Mac (Designed for iPad)** or **My Mac (Mac Catalyst)** from the destination picker.

> **Note:** On first open, go to the **Signing & Capabilities** tab and set your development team.

## Testing

Run the full test suite against the iPad simulator:

```bash
xcodebuild test \
  -project VoiceCoach.xcodeproj \
  -scheme VoiceCoach \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M4)" \
  -only-testing:VoiceCoachTests \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO \
  > /tmp/vc-test.log 2>&1 && grep -E "(✔|✘|passed|failed)" /tmp/vc-test.log
```

Or from Xcode, press **Cmd+U** with the `VoiceCoach` scheme selected.

The test suite contains two files:

- **`VoiceCoachTests/VideoStorageServiceTests.swift`** — unit tests for file I/O: path resolution, unique URL generation, import, and delete
- **`VoiceCoachTests/ModelTests.swift`** — SwiftData integration tests using an in-memory container: Exercise CRUD, cascade deletes, Playlist relationships

## Project Structure

```
VoiceCoach/
├── Models/               SwiftData models (Exercise, Attempt, Playlist)
├── Services/
│   ├── VideoStorageService.swift   File I/O for imported and recorded videos
│   └── RecordingService.swift      AVCaptureSession management
├── Views/
│   ├── ContentView.swift           TabView root (Exercises / Feed / Playlists)
│   ├── Exercises/                  List, detail, creation views
│   ├── Feed/                       Global TikTok-style attempt feed
│   ├── Playlists/                  Playlist list and detail views
│   ├── Recording/                  Camera preview + recording UI
│   └── Components/                 VideoPlayerView, AttemptRowView, SortOrderPicker
├── Preview Content/
│   └── PreviewSampleData.swift     In-memory seed data for Xcode previews
└── Resources/
    └── Assets.xcassets
```

## Architecture Notes

- **SwiftData** for persistence — no CoreData boilerplate, iCloud sync can be enabled by changing one line in `VoiceCoachApp.swift`
- **No ViewModel layer** — `@Query` works directly in views; services handle non-view logic
- **Relative video paths** — SwiftData stores paths relative to `Documents/VoiceCoachMedia/`, not absolute URLs, so the database is portable across sandbox changes and future iCloud containers
- **Swift 6 strict concurrency** — all AVFoundation work dispatched off the main actor

## Regenerating the Xcode Project

If you change `project.yml` (e.g. to add a new target or build setting), regenerate the `.xcodeproj`:

```bash
xcodegen generate
```

The `.xcodeproj` is committed to the repo for convenience, but `project.yml` is the source of truth for project settings.
