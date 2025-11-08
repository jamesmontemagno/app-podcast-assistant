# Podcast Assistant - AI Agent Instructions

## Project Architecture

This is a macOS SwiftUI app using a **workspace + SPM package architecture** with **Core Data persistence** for clean separation:

- **App Shell**: `PodcastAssistant/` - Minimal app lifecycle code (App entry point only)
- **Feature Code**: `PodcastAssistantPackage/Sources/PodcastAssistantFeature/` - **ALL business logic, services, views, and models live here**
- **Always open**: `PodcastAssistant.xcworkspace` (never the .xcodeproj file)

### Critical File Organization Pattern
```
PodcastAssistantPackage/Sources/PodcastAssistantFeature/
├── Models/          # Core Data entities (Podcast, Episode), legacy models
├── Services/        # Pure business logic (TranscriptConverter, ThumbnailGenerator, PersistenceController, ImageUtilities)
├── ViewModels/      # @MainActor ObservableObject classes with Core Data bindings
└── Views/           # SwiftUI views (master-detail navigation pattern)
```

## Public API Pattern (Critical!)

All types in `PodcastAssistantFeature` exposed to the app target **must** be `public`:
```swift
public struct MyView: View {
    public init() {}  // ← Required!
    public var body: some View { ... }
}

public class MyViewModel: ObservableObject {
    @Published public var text: String = ""  // ← public on properties too
    public init() {}
}
```

## Building & Running

**CRITICAL**: After making changes, **ALWAYS ask the user if they want to run the app** to see the changes.

**Via XcodeBuildMCP tools** (preferred - builds and launches automatically):
```
mcp_xcodebuildmcp_build_run_macos({ 
    scheme: "PodcastAssistant", 
    workspacePath: "/Volumes/ExData/GitHub/app-podcast-assistant/PodcastAssistant.xcworkspace" 
})
```

**Setting up Xcode path** (required first time):
```bash
# Find Xcode installation
mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" | head -1

# Set developer directory (adjust version as needed)
sudo xcode-select --switch /Applications/Xcode-26.0.1.app/Contents/Developer
```

**Manual build** (command-line):
```bash
xcodebuild -workspace PodcastAssistant.xcworkspace -scheme PodcastAssistant -configuration Debug
```

**Workflow**: After implementing features or fixing issues → Build & Run → Ask user for feedback

## Key Conventions

### 1. Core Data Pattern
All podcast and episode data persists to Core Data for multi-podcast management:
```swift
// PersistenceController is singleton - access via shared instance
let persistenceController = PersistenceController.shared

// Inject context into app
ContentView()
    .environment(\.managedObjectContext, persistenceController.container.viewContext)

// ViewModels accept Episode + context dependencies
public class TranscriptViewModel: ObservableObject {
    public let episode: Episode
    private let context: NSManagedObjectContext
    
    public init(episode: Episode, context: NSManagedObjectContext) {
        self.episode = episode
        self.context = context
    }
    
    // Computed properties read/write to Core Data
    public var inputText: String {
        get { episode.transcriptInputText ?? "" }
        set {
            episode.transcriptInputText = newValue.isEmpty ? nil : newValue
            saveContext()
        }
    }
}
```

### 2. Image Storage Pattern
Images are stored as Data blobs in Core Data (auto-processed before storage):
```swift
// Automatic resize to 1024x1024 + JPEG 0.8 compression
if let image = selectedImage {
    podcast.artworkData = ImageUtilities.processImageForStorage(image)
}

// Retrieval
if let data = episode.thumbnailBackgroundData {
    let image = ImageUtilities.loadImage(from: data)
}
```

### 3. Master-Detail Navigation Pattern
Three-column NavigationSplitView replaces old tab-based UI:
```swift
NavigationSplitView {
    // Sidebar: Podcast list with @FetchRequest
} content: {
    // Middle: Episode list for selected podcast
} detail: {
    // Detail pane: TranscriptView/ThumbnailView for selected episode
}
```

Views now require episode parameter:
```swift
TranscriptView(episode: selectedEpisode)
ThumbnailView(episode: selectedEpisode)
```

### 4. File Dialogs Pattern (NSOpenPanel/NSSavePanel)
All file operations use macOS native panels with proper UTType handling:
```swift
let panel = NSSavePanel()
if let srtType = UTType(filenameExtension: "srt") {
    panel.allowedContentTypes = [srtType]
} else {
    panel.allowedContentTypes = [.plainText]  // Fallback
}
panel.canCreateDirectories = true
panel.begin { response in
    if response == .OK, let url = panel.url {
        // Handle file operation
    }
}
```

### 2. ViewModel Pattern
ViewModels use `@MainActor` and handle async operations with `Task { @MainActor in ... }`.
**ViewModels are now Core Data-backed** - they accept Episode + context dependencies:
```swift
@MainActor
public class TranscriptViewModel: ObservableObject {
    public let episode: Episode
    private let context: NSManagedObjectContext
    
    public init(episode: Episode, context: NSManagedObjectContext) {
        self.episode = episode
        self.context = context
    }
    
    public func importFile() {
        let panel = NSOpenPanel()
        panel.begin { [weak self] response in
            Task { @MainActor in  // ← Always wrap UI updates
                self?.episode.transcriptInputText = content
                self?.saveContext()
            }
        }
    }
}
```

### 3. Side-by-Side Layout Pattern
Views use HStack with independent ScrollViews (see `TranscriptView.swift`):
- Toolbar at top with all action buttons
- HStack for side-by-side content panes
- Each pane has its own ScrollView for independent scrolling
- Messages/status at bottom (not floating)

### 4. Format Detection Pattern
`TranscriptConverter` auto-detects input formats by sampling first 50 lines:
- **Zencastr format**: `MM:SS.ss` timestamp → speaker name → dialog (multi-line)
- **Time range format**: `HH:MM:SS - HH:MM:SS` → text
- Regex patterns with match counting to determine format

## Configuration Files

- **Build settings**: `Config/*.xcconfig` files (Shared, Debug, Release, Tests)
- **Entitlements**: `Config/PodcastAssistant.entitlements` - sandboxed with user-selected file access
- **Package config**: `PodcastAssistantPackage/Package.swift` - add dependencies here, not in Xcode project

## Adding New Features

1. Create files in `PodcastAssistantPackage/Sources/PodcastAssistantFeature/` (auto-appear in Xcode via Buildable Folders)
2. Use MVVM pattern: Service → ViewModel (with @Published) → View
3. Make everything `public` with `public init()`
4. For file I/O, use NSOpenPanel/NSSavePanel with proper UTType
5. For image processing, use AppKit (NSImage, NSBitmapImageRep, NSGraphicsContext)

## Testing

- **Unit tests**: `PodcastAssistantPackage/Tests/PodcastAssistantFeatureTests/` using Swift Testing framework
- Use `@Test` annotation, `#expect()` for assertions
- Test format detection, conversion logic, file operations

## Common Pitfalls

1. ❌ Opening `.xcodeproj` instead of `.xcworkspace` → SPM dependencies won't resolve
2. ❌ Forgetting `public` on types/inits → Compiler errors about inaccessible types
3. ❌ Using `xcodebuild` without setting developer directory → Falls back to Command Line Tools (insufficient)
4. ❌ Nesting TextEditor directly without ScrollView → No scrolling
5. ❌ Using `.compactMap { $0 }` on single UTType creation → File dialogs fail silently

## Project Context

Built with XcodeBuildMCP scaffolding tool. Core features:
1. **Multi-Podcast Management**: Create/manage multiple podcasts with metadata, artwork, and default settings
2. **Transcript Converter**: Zencastr/generic formats → YouTube SRT (with speaker names, timestamp calculation)
3. **Thumbnail Generator**: Background + overlay + episode number → PNG/JPEG (AppKit-based rendering)
4. **Core Data Persistence**: Local storage with CloudKit-ready schema for future iCloud sync
5. **Master-Detail Navigation**: Three-column layout (Podcasts → Episodes → Detail)

## Core Data Schema

**Entities:**
- `Podcast` - Podcast metadata, artwork, default thumbnail settings
  - One-to-many relationship with `Episode` (cascade delete)
- `Episode` - Episode title, number, transcript text, thumbnail images, settings
  - Many-to-one relationship with `Podcast`

**Image Storage:**
- All images stored as Data blobs in Core Data
- Auto-processed: resize to 1024x1024 max + JPEG 0.8 compression
- External binary storage enabled for files >100KB

**Data Flow:**
```
User Action → ViewModel → Core Data Entity → Context Save → UI Update
```

## Documentation

See `/docs` folder for comprehensive guides:
- `ARCHITECTURE.md` - System architecture, navigation flow, component details
- `CORE_DATA.md` - Core Data implementation, CloudKit migration path, best practices
