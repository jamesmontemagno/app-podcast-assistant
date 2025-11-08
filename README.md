# Podcast Assistant - macOS App

A SwiftUI macOS application for podcast management with two key features:
1. **Transcript to SRT Converter** - Convert text transcripts to YouTube-compatible SRT format
2. **Thumbnail Generator** - Create podcast thumbnails with episode numbers and custom backgrounds

## Features

### 📝 Transcript Conversion
- Import text transcript files
- Automatically detect and convert multiple timestamp formats to SRT
- Export ready-to-upload SRT files for YouTube
- Speaker name preservation (Zencastr format)
- Intelligent timestamp calculation

### 🎨 Thumbnail Generation
- Load custom background images
- Optional overlay layer for branding
- Automatic episode number placement (top right corner)
- Customizable fonts and font sizes
- Export as PNG or JPEG

## Requirements

- macOS 14.0 or later
- Xcode 16 or later (for building)

## Getting Started

### Opening the Project
1. Open `PodcastAssistant.xcworkspace` in Xcode (NOT the .xcodeproj file)
2. Wait for Swift Package Manager to resolve dependencies
3. Select the "PodcastAssistant" scheme
4. Build and run (⌘R)

### Building from Command Line
```bash
# Build the app
xcodebuild -workspace PodcastAssistant.xcworkspace -scheme PodcastAssistant -configuration Debug
```

## Project Architecture

```
PodcastAssistant/
├── PodcastAssistant.xcworkspace/              # Open this file in Xcode
├── PodcastAssistant.xcodeproj/                # App shell project
├── PodcastAssistant/                          # App target (minimal)
│   ├── Assets.xcassets/                # App-level assets (icons, colors)
│   ├── PodcastAssistantApp.swift              # App entry point
│   ├── PodcastAssistant.entitlements          # App sandbox settings
│   └── PodcastAssistant.xctestplan            # Test configuration
├── PodcastAssistantPackage/                   # 🚀 Primary development area
│   ├── Package.swift                   # Package configuration
│   ├── Sources/PodcastAssistantFeature/       # Your feature code
│   └── Tests/PodcastAssistantFeatureTests/    # Unit tests
├── PodcastAssistantUITests/                   # UI automation tests
└── Config/                                    # XCConfig build settings
```

The complete project structure:
```
PodcastAssistant/
└── PodcastAssistantPackage/
    ├── Sources/PodcastAssistantFeature/
    │   ├── Models/                            # Data models
    │   │   └── TranscriptEntry.swift
    │   ├── Services/                          # Business logic
    │   │   ├── TranscriptConverter.swift      # SRT conversion engine
    │   │   └── ThumbnailGenerator.swift       # Thumbnail creation engine
    │   ├── ViewModels/                        # View models
    │   │   ├── TranscriptViewModel.swift
    │   │   └── ThumbnailViewModel.swift
    │   └── Views/                             # SwiftUI views
    │       ├── ContentView.swift              # Main tab view
    │       ├── TranscriptView.swift           # Transcript converter UI
    │       └── ThumbnailView.swift            # Thumbnail generator UI
    └── Tests/PodcastAssistantFeatureTests/    # Unit tests
```

## Key Architecture Points

### Workspace + SPM Structure
- **App Shell**: `PodcastAssistant/` contains minimal app lifecycle code
- **Feature Code**: `PodcastAssistantPackage/Sources/PodcastAssistantFeature/` is where most development happens
- **Separation**: Business logic lives in the SPM package, app target just imports and displays it

### Buildable Folders (Xcode 16)
- Files added to the filesystem automatically appear in Xcode
- No need to manually add files to project targets
- Reduces project file conflicts in teams

### App Sandbox
The app is sandboxed by default with basic file access permissions. Modify `PodcastAssistant.entitlements` to add capabilities as needed.

## Usage

### Transcript Conversion

**Supported Input Formats:**

The converter automatically detects and handles multiple transcript formats:

**1. Zencastr Format** (automatically detected):
```
00:00.29
James
Welcome back everyone to Merge Conflict, your weekly developer podcast.

00:08.36
Frank
I am the other host. Hi, everyone.
```

**2. Time Range Format** (automatically detected):
```
00:00:00 - 00:00:05 Welcome to the podcast
00:00:05 - 00:00:10 Today we're talking about...
```

Or with text on separate lines:
```
00:00:00 - 00:00:05
Welcome to the podcast
00:00:05 - 00:00:10
Today we're talking about...
```

**Steps:**
1. Click the "Transcript" tab
2. Import your text file or paste content directly
3. Click "Convert to SRT" (format is auto-detected)
4. Export the generated SRT file

**Output Format:**
```srt
1
00:00:00,290 --> 00:00:05,290
James: Welcome back everyone to Merge Conflict, your weekly developer podcast.

2
00:00:08,360 --> 00:00:13,360
Frank: I am the other host. Hi, everyone.
```

**Features:**
- Automatic format detection
- Speaker name preservation (Zencastr format)
- Intelligent timestamp calculation
- YouTube-compatible SRT output

### Thumbnail Generation

**Steps:**
1. Click the "Thumbnail" tab
2. Select a background image (required)
3. Optionally select an overlay image for branding
4. Enter the episode number
5. Customize font and size
6. Click "Generate Thumbnail"
7. Export when satisfied with the preview

**Tips:**
- Background images are scaled to fit
- Overlay images maintain transparency
- Episode numbers appear in top right corner
- White text with black stroke for readability

## Development Notes

### Code Organization
Most development happens in `PodcastAssistantPackage/Sources/PodcastAssistantFeature/` - organize your code as you prefer.

### Public API Requirements
Types exposed to the app target need `public` access:
```swift
public struct SettingsView: View {
    public init() {}
    
    public var body: some View {
        // Your view code
    }
}
```

### Adding Dependencies
Edit `PodcastAssistantPackage/Package.swift` to add SPM dependencies:
```swift
dependencies: [
    .package(url: "https://github.com/example/SomePackage", from: "1.0.0")
],
targets: [
    .target(
        name: "PodcastAssistantFeature",
        dependencies: ["SomePackage"]
    ),
]
```

### Test Structure
- **Unit Tests**: `PodcastAssistantPackage/Tests/PodcastAssistantFeatureTests/` (Swift Testing framework)
- **UI Tests**: `PodcastAssistantUITests/` (XCUITest framework)
- **Test Plan**: `PodcastAssistant.xctestplan` coordinates all tests

## Configuration

### XCConfig Build Settings
Build settings are managed through **XCConfig files** in `Config/`:
- `Config/Shared.xcconfig` - Common settings (bundle ID, versions, deployment target)
- `Config/Debug.xcconfig` - Debug-specific settings  
- `Config/Release.xcconfig` - Release-specific settings
- `Config/Tests.xcconfig` - Test-specific settings

### App Sandbox & Entitlements
The app is sandboxed by default with basic file access. Edit `PodcastAssistant/PodcastAssistant.entitlements` to add capabilities:
```xml
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<!-- Add other entitlements as needed -->
```

## macOS-Specific Features

### Window Management
Add multiple windows and settings panels:
```swift
@main
struct PodcastAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        Settings {
            SettingsView()
        }
    }
}
```

### Asset Management
- **App-Level Assets**: `PodcastAssistant/Assets.xcassets/` (app icon with multiple sizes, accent color)
- **Feature Assets**: Add `Resources/` folder to SPM package if needed

### SPM Package Resources
To include assets in your feature package:
```swift
.target(
    name: "PodcastAssistantFeature",
    dependencies: [],
    resources: [.process("Resources")]
)
```

## Customization

### Adding New Fonts
Edit `ThumbnailViewModel.swift` and add fonts to the `availableFonts` array:
```swift
public let availableFonts = [
    "YourCustomFont-Bold",
    "Helvetica-Bold",
    // ... more fonts
]
```

### Modifying Transcript Format
Edit `TranscriptConverter.swift` to support different timestamp patterns by updating the format detection logic.

### Changing Thumbnail Layout
Modify `ThumbnailGenerator.swift` to adjust:
- Episode number position
- Text styling (color, stroke, shadows)
- Padding and spacing

## Troubleshooting

### Build Issues
- Make sure you're opening `.xcworkspace`, not `.xcodeproj`
- Clean build folder: Product → Clean Build Folder (⇧⌘K)
- Reset package caches: File → Packages → Reset Package Caches

### File Access Issues
The app is sandboxed. If you need additional file access:
1. Edit `PodcastAssistant/PodcastAssistant.entitlements`
2. Add required entitlements

### Image Loading Issues
- Ensure images are in supported formats (PNG, JPEG, TIFF, BMP)
- Check image file permissions
- Try smaller image files if memory issues occur

## License

MIT License - See [LICENSE](LICENSE) file for details

## Credits

Built with:
- SwiftUI
- AppKit
- Swift Package Manager
- Scaffolded with [XcodeBuildMCP](https://github.com/cameroncooke/XcodeBuildMCP)