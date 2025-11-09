# Podcast Assistant - macOS App

> **⚠️ IMPORTANT:** Always open `PodcastAssistant.xcworkspace`, **NOT** `PodcastAssistant.xcodeproj`  
> Opening the `.xcodeproj` file directly will cause build errors: `Missing package product 'PodcastAssistantFeature'`

A SwiftUI macOS application for comprehensive podcast production management with Core Data persistence. Manage multiple podcasts, create episodes, convert transcripts to SRT format, and generate custom thumbnails—all in one integrated workflow.

## Features

### 🎙️ Multi-Podcast Management
- Create and manage multiple podcasts with metadata and artwork
- Set default thumbnail settings per podcast (overlay, fonts, positioning)
- Organize episodes within each podcast
- Persistent local storage with Core Data
- CloudKit-ready schema for future iCloud sync

### 📝 Transcript Conversion
- Import text transcript files per episode
- Automatically detect and convert multiple timestamp formats to SRT
- Export ready-to-upload SRT files for YouTube
- **Multi-language SRT translation** - Export SRT in 12+ languages (Spanish, French, German, Japanese, etc.) using macOS Translation API (macOS 26+)
- Speaker name preservation (Zencastr format)
- Intelligent timestamp calculation
- Episode-scoped storage (auto-saved to Core Data)

### 🎨 Thumbnail Generation
- Episode-specific thumbnail creation with live preview
- Inherit default settings from parent podcast or customize per episode
- Load custom background images
- Optional overlay layer for branding
- Automatic episode number placement with customizable fonts and positioning
- Export as PNG or JPEG
- Generated thumbnails auto-saved with episode
- **Lazy loading** - Instant view loading with smooth background generation

### 🤖 AI-Powered Content Generation (Apple Intelligence)
- Generate catchy episode titles from transcript content
- Create episode descriptions in multiple lengths (short/medium/long)
- Generate social media posts for multiple platforms (X/Twitter, LinkedIn, Threads/Bluesky)
- Auto-generate chapter markers with timestamps and descriptions
- **All content is generated locally on-device** using Apple Intelligence (macOS 26+)
- No cloud services or API keys required
- Content never leaves your Mac

### 🌐 Episode Translation
- Translate episode titles and descriptions to 12+ languages
- Uses macOS Translation API for high-quality, on-device translation
- Perfect for creating multilingual podcast content
- Supports Spanish, French, German, Japanese, Portuguese, Italian, Korean, Chinese, Dutch, Russian, Arabic, Hindi, and more
- Copy translated content directly to clipboard
- Requires macOS 26+

### ⚙️ Settings & Customization
- **Theme Selection** - Choose between System, Light, or Dark mode with instant application
- **Custom Font Management** - Import and manage TTF, OTF, and TTC fonts for thumbnails
- **Font Auto-Registration** - Imported fonts automatically available across the app
- Theme and font preferences persist across app launches
- All settings stored locally with Core Data

## Requirements

- **macOS 14.0 or later** - Core app functionality
- **macOS 26.0 or later** - For AI Ideas and Episode Translation features (requires Apple Intelligence)
- **Xcode 16 or later** - For building from source

## Getting Started

### Quick Start (macOS)

The easiest way to open the project correctly:
```bash
./open-in-xcode.sh
```

Or manually:

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

The app uses a **workspace + SPM package architecture** with Core Data for local persistence:

```
PodcastAssistant/
├── PodcastAssistant.xcworkspace/              # Open this file in Xcode
├── PodcastAssistant/                          # App shell (minimal)
│   └── PodcastAssistantApp.swift              # Entry point with Core Data injection
├── PodcastAssistantPackage/                   # 🚀 Primary development area
│   └── Sources/PodcastAssistantFeature/
│       ├── Models/                            # Core Data entities
│       │   ├── PodcastAssistant.xcdatamodeld  # Core Data model
│       │   ├── Podcast+CoreData*.swift        # Podcast entity
│       │   └── Episode+CoreData*.swift        # Episode entity
│       ├── Services/                          # Business logic
│       │   ├── PersistenceController.swift    # Core Data stack
│       │   ├── TranscriptConverter.swift      # SRT conversion
│       │   ├── ThumbnailGenerator.swift       # Image compositing
│       │   └── ImageUtilities.swift           # Image processing
│       ├── ViewModels/                        # Core Data-backed state
│       │   ├── TranscriptViewModel.swift      # Episode transcript state
│       │   └── ThumbnailViewModel.swift       # Episode thumbnail state
│       └── Views/                             # SwiftUI views
│           ├── ContentView.swift              # Master-detail navigation
│           ├── PodcastFormView.swift          # Create/edit podcasts
│           ├── EpisodeFormView.swift          # Create/edit episodes
│           ├── TranscriptView.swift           # Transcript editor
│           └── ThumbnailView.swift            # Thumbnail generator
├── docs/                                      # 📚 Architecture documentation
│   ├── ARCHITECTURE.md                        # System design & data flow
│   └── CORE_DATA.md                           # Core Data implementation guide
└── Config/                                    # XCConfig build settings
```

### Navigation Flow

The app uses a three-column master-detail layout:

```
Podcast List  →  Episode List  →  Episode Detail (Transcript/Thumbnail)
     ↓                ↓                      ↓
  Sidebar        Middle Column          Detail Pane
```

**See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for complete architectural details.**

## Usage

### Getting Started

1. **Create a Podcast**
   - Click the "+" button in the podcast sidebar
   - Enter podcast name and optional description
   - Upload podcast artwork (resized to 1024x1024, JPEG compressed)
   - Configure default thumbnail settings (overlay, font, positioning)
   - These defaults will be copied to new episodes

2. **Create an Episode**
   - Select a podcast from the sidebar
   - Click the "+" button in the episode list
   - Enter episode title and number
   - Default thumbnail settings are automatically copied from the podcast

3. **Work on Episode Content**
   - Select an episode to view its detail pane
   - Switch between Transcript and Thumbnail tabs
   - All changes auto-save to Core Data

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

**Steps:**
1. Select an episode from the episode list
2. Click the "Transcript" tab in the detail pane
3. Import your text file or paste content directly
4. Click "Convert to SRT" (format is auto-detected)
5. Export the generated SRT file
6. **Optional**: Click the "Translate" (globe) button to export SRT in another language
   - Choose from 12+ supported languages (Spanish, French, German, Japanese, Portuguese, Italian, Korean, Chinese, Dutch, Russian, Arabic, Hindi)
   - macOS will translate the subtitles while preserving timestamps
   - Requires macOS 26+ with translation packs installed
   - Download language packs in System Settings > General > Language & Region > Translation Languages
7. Input and output are auto-saved with the episode

**Output Format:**
```srt
1
00:00:00,290 --> 00:00:05,290
James: Welcome back everyone to Merge Conflict, your weekly developer podcast.

2
00:00:08,360 --> 00:00:13,360
Frank: I am the other host. Hi, everyone.
```

### Thumbnail Generation

**Steps:**
1. Select an episode from the episode list
2. Click the "Thumbnail" tab in the detail pane
3. Select a background image (required) - auto-processed and saved
4. Optionally select an overlay image for branding
5. Episode number is pre-filled from episode data
6. Font and position settings are inherited from podcast defaults
7. Thumbnail generates automatically with live preview (lazy loaded for smooth UI)
8. Generated thumbnail auto-saves with the episode
9. Click "Export Thumbnail" to save as PNG/JPEG file

**Performance:**
- View loads instantly with lazy thumbnail generation
- Background processing with progress indicator
- Smooth UI even with large 4K images

### AI Content Generation

**Requirements:**
- macOS 26+ with Apple Intelligence enabled
- Episode must have a transcript

**Steps:**
1. Select an episode with a transcript
2. Click the "AI Ideas" tab in the detail pane
3. Choose content type to generate:
   - **Titles**: Generate 3 catchy title variations
   - **Description**: Create short, medium, or long descriptions
   - **Social Posts**: Generate platform-optimized posts (X/Twitter, LinkedIn, Threads/Bluesky)
   - **Chapters**: Auto-detect chapter breaks with timestamps and descriptions
4. Click "Generate All" to create all content types at once
5. Copy generated content directly to clipboard
6. Refine and regenerate as needed

**Privacy:**
- All AI processing happens on-device using Apple Intelligence
- No data is sent to cloud services
- No API keys or accounts required

### Episode Translation

**Requirements:**
- macOS 26+ with Translation API support
- Translation packs installed for both source and target languages

**Steps:**
1. Select an episode from the episode list
2. Click "Edit Details" (pencil icon) next to the episode
3. Click the "Translate" (globe) button at the bottom
4. Select target language from the dropdown
5. Click "Translate"
6. Review translated title and description
7. Copy to clipboard or click "Done" to close

**Installing Translation Packs:**
1. Open System Settings > General > Language & Region
2. Scroll to "Translation Languages"
3. Add both your source language (e.g., English) and target languages
4. Wait for packs to download
5. Restart Podcast Assistant

### Settings & Customization

**Accessing Settings:**
- Click the gear icon (⚙️) in the sidebar header

**Theme Selection:**
1. Open Settings
2. Find "Appearance" section
3. Choose between:
   - **System** - Follows macOS appearance
   - **Light** - Always light mode
   - **Dark** - Always dark mode
4. Theme applies instantly

**Font Management:**
1. Open Settings
2. Scroll to "Font Management" section
3. Click "Import Font"
4. Select TTF, OTF, or TTC font file
5. Font appears in list and is available in thumbnail generator
6. To remove: hover over font and click trash icon

**Default Settings:**
- New episodes automatically copy font, overlay, and positioning from podcast defaults
- Customize per-episode if needed—changes won't affect the podcast defaults

## Core Data & Persistence

### Data Model

**Podcast Entity:**
- Name, description, artwork
- Default thumbnail settings (overlay, font, positioning)
- One-to-many relationship with episodes (cascade delete)

**Episode Entity:**
- Title, episode number
- Transcript input text and SRT output text
- Thumbnail images (background, overlay, generated output)
- Font and positioning settings (copied from podcast defaults)
- Many-to-one relationship with podcast

**See [docs/CORE_DATA.md](docs/CORE_DATA.md) for complete Core Data implementation details.**

### Image Storage

Images are stored as binary data (BLOBs) in Core Data for simplicity and future iCloud compatibility:
- Automatically resized to max 1024x1024 pixels
- JPEG compressed at 0.8 quality
- External binary storage enabled for large files
- Typical size: 100-500KB per image

### iCloud Sync (Future)

The Core Data schema is CloudKit-ready. To enable iCloud sync in the future:
1. Change `NSPersistentContainer` → `NSPersistentCloudKitContainer`
2. Add CloudKit entitlements
3. No data migration needed

**See detailed iCloud migration steps in [docs/CORE_DATA.md](docs/CORE_DATA.md).**

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

The app supports two approaches for adding custom fonts:

#### Option 1: Runtime Font Loading (Recommended)
The app includes a built-in font loader that lets you add custom fonts at runtime without rebuilding:

1. Click the "Thumbnail" tab
2. Click "Load Custom Font" button
3. Select a `.ttf` or `.otf` font file
4. The font will be registered and added to the font picker automatically

**Advantages:**
- No code changes needed
- Fonts persist across app launches (saved in UserDefaults)
- Easy to add/test different fonts

#### Option 2: Bundling Fonts in the App
To bundle fonts directly in the app package for distribution:

1. **Create a Fonts folder:**
   ```bash
   mkdir -p PodcastAssistantPackage/Sources/PodcastAssistantFeature/Resources/Fonts
   ```

2. **Add your font files** (`.ttf` or `.otf`) to this folder

3. **Update Package.swift** to include resources:
   ```swift
   .target(
       name: "PodcastAssistantFeature",
       dependencies: [],
       resources: [.process("Resources")]
   )
   ```

4. **Register bundled fonts** in `ThumbnailViewModel.init()`:
   ```swift
   // Add this code to register bundled fonts on app launch
   let ttfFonts = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
   let otfFonts = Bundle.module.urls(forResourcesWithExtension: "otf", subdirectory: "Fonts") ?? []
   for fontURL in ttfFonts + otfFonts {
       registerCustomFont(from: fontURL)
   }
   ```

5. **Rebuild the app** to include the bundled fonts

**Note:** 
- System fonts (Helvetica, Arial, Futura, etc.) are always available without any setup.
- Unlike iOS, macOS apps don't require `UIAppFonts`/`Fonts provided by application` entries in Info.plist when using runtime font registration via `CTFontManagerRegisterGraphicsFont`.
- The SPM package resources are automatically included in the app bundle, no additional build settings needed.

### Modifying Transcript Format
Edit `TranscriptConverter.swift` to support different timestamp patterns by updating the format detection logic.

### Changing Thumbnail Layout
Modify `ThumbnailGenerator.swift` to adjust:
- Episode number position
- Text styling (color, stroke, shadows)
- Padding and spacing

## Troubleshooting

### Build Issues

**Error: "Missing package product 'PodcastAssistantFeature'"**

This error means you opened the wrong file. You must open `PodcastAssistant.xcworkspace`, NOT `PodcastAssistant.xcodeproj`.

**Why?** The project uses a local Swift Package for features. The `.xcworkspace` file tells Xcode about this package. Opening just the `.xcodeproj` file will cause Xcode to fail with missing package errors.

**Fix:**
1. Close Xcode
2. Open `PodcastAssistant.xcworkspace` (the workspace file)
3. Build and run (⌘R)

**Other build issues:**
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