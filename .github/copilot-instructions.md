# Podcast Assistant - AI Agent Instructions

## Project Architecture

This is a macOS SwiftUI app using a **workspace + SPM package architecture** with **hybrid POCO + SwiftData persistence** for clean separation:

- **App Shell**: `PodcastAssistant/` - Minimal app lifecycle code (App entry point only)
- **Feature Code**: `PodcastAssistantPackage/Sources/PodcastAssistantFeature/` - **ALL business logic, services, views, and models live here**
- **Always open**: `PodcastAssistant.xcworkspace` (never the .xcodeproj file)

This app targets the latest macOS SDK. Uses **POCOs (Plain Old Class Objects) for UI** with SwiftData for persistence (CloudKit-ready). macOS 26 APIs are preferred.

### Critical File Organization Pattern
```
PodcastAssistantPackage/Sources/PodcastAssistantFeature/
├── Models/
│   ├── POCOs/              # UI-layer simple classes (PodcastPOCO, EpisodePOCO)
│   ├── SwiftData/          # Database models (Podcast, Episode)
│   └── Supporting/         # Helper models (AppSettings, SRTDocument, etc.)
├── Services/
│   ├── Data/              # PodcastLibraryStore (POCO ↔ SwiftData bridge), PersistenceController
│   ├── UI/                # UI services (ThumbnailGenerator)
│   └── Utilities/         # Business logic (TranscriptConverter, ImageUtilities, etc.)
├── ViewModels/            # @MainActor ObservableObject classes working with POCOs
└── Views/
    ├── Forms/             # Modal create/edit forms
    ├── Sections/          # Main detail pane tabs (TranscriptView, ThumbnailView, etc.)
    └── Sheets/            # Action popups (translation sheets)
```

**See `/docs/POCO_ARCHITECTURE.md` and `/docs/FOLDER_STRUCTURE.md` for complete details.**

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

### 1. POCO Pattern (Critical!)
**UI layer uses POCOs, NOT SwiftData models directly**:
```swift
// PodcastLibraryStore bridges POCOs ↔ SwiftData
@EnvironmentObject var store: PodcastLibraryStore

// Views work with POCOs
let podcast: PodcastPOCO  // ✅ Simple class
let episode: EpisodePOCO  // ✅ Simple class

// ViewModels accept POCO + Store dependencies
@MainActor
public class ThumbnailViewModel: ObservableObject {
    @Published public var episode: EpisodePOCO
    private let store: PodcastLibraryStore
    
    public init(episode: EpisodePOCO, store: PodcastLibraryStore) {
        self.episode = episode
        self.store = store
    }
    
    // Update POCO, save via store
    public var fontSize: Double {
        get { episode.fontSize }
        set { 
            episode.fontSize = newValue
            try? store.updateEpisode(episode)  // Persist to SwiftData
        }
    }
}
```

**Why POCOs?**
- ✅ Fast UI performance (no SwiftData overhead)
- ✅ Easy testing (no ModelContext needed)
- ✅ Predictable updates (@Published works reliably)
- ✅ SwiftData still handles persistence in background

### 2. Image Storage Pattern
Images are stored as Data blobs in SwiftData (auto-processed before storage):
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
    // Sidebar: Podcast list with @Query
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

### 2. Data Management Pattern
**PodcastLibraryStore is the central data manager**:
```swift
// In ContentView - inject store
@StateObject private var store = PodcastLibraryStore()

var body: some View {
    NavigationSplitView { ... }
        .environmentObject(store)
        .onAppear {
            try? store.loadInitialData(context: modelContext)
        }
}

// In child views - use store
@EnvironmentObject var store: PodcastLibraryStore

// Access POCO data
let podcasts = store.podcasts  // [PodcastPOCO]
let episodes = store.episodes[podcastID]  // [EpisodePOCO]

// CRUD operations
try? store.addPodcast(newPodcast)
try? store.updateEpisode(modifiedEpisode)
try? store.deletePodcast(podcast)
```

**ViewModels use @MainActor and work with POCOs**:
```swift
@MainActor
public class MyViewModel: ObservableObject {
    @Published public var data: MyPOCO
    private let store: PodcastLibraryStore
    
    public func saveChanges() {
        try? store.updateData(data)  // Persist
        objectWillChange.send()
    }
}
```

### 3. UI Design Pattern
**All forms/sheets follow consistent design system** (see `/docs/UI_DESIGN_PATTERNS.md`):
```swift
VStack(spacing: 0) {
    // Header
    VStack(spacing: 8) {
        Text("Title").font(.title2).fontWeight(.bold)
        Text("Subtitle").foregroundStyle(.secondary)
    }.padding(.top, 20)
    
    Divider()
    
    // Content
    ScrollView {
        Form { ... }.formStyle(.grouped).padding(24)
    }
    
    Divider()
    
    // Button bar
    HStack {
        Button("Cancel") { }.buttonStyle(.bordered)
        Spacer()
        Button("Save") { }.buttonStyle(.borderedProminent).controlSize(.large)
    }
    .padding(16)
    .background(Color(NSColor.windowBackgroundColor))
}
```

**Side-by-side layouts use HSplitView**:
```swift
HSplitView {
    ScrollView { /* Left pane */ }.frame(minWidth: 300)
    ScrollView { /* Right pane */ }.frame(minWidth: 300)
}
```

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

1. **Determine architecture needs** (see `/docs/FOLDER_STRUCTURE.md`):
   - Need persistence? → Create SwiftData model + POCO + update PodcastLibraryStore
   - Need business logic? → Create service in `Services/Utilities/`
   - Need UI state? → Create ViewModel
   - New form? → `Views/Forms/`
   - New tab? → `Views/Sections/`
   - New popup? → `Views/Sheets/`

2. **Create files in proper folders**:
   - POCOs: `Models/POCOs/`
   - SwiftData: `Models/SwiftData/`
   - Services: `Services/Data/`, `Services/UI/`, or `Services/Utilities/`
   - ViewModels: `ViewModels/`
   - Views: `Views/Forms/`, `Views/Sections/`, or `Views/Sheets/`

3. **Follow patterns**:
   - Use POCO pattern (Views/ViewModels work with POCOs, not SwiftData)
   - Make everything `public` with `public init()`
   - Follow UI design patterns from `/docs/UI_DESIGN_PATTERNS.md`
   - For file I/O, use NSOpenPanel/NSSavePanel with proper UTType
   - For image processing, use AppKit (NSImage, NSBitmapImageRep, NSGraphicsContext)

## Testing

- **Unit tests**: `PodcastAssistantPackage/Tests/PodcastAssistantFeatureTests/` using Swift Testing framework
- Use `@Test` annotation, `#expect()` for assertions
- Test format detection, conversion logic, file operations

## Common Pitfalls

1. ❌ Opening `.xcodeproj` instead of `.xcworkspace` → SPM dependencies won't resolve
2. ❌ Forgetting `public` on types/inits → Compiler errors about inaccessible types
3. ❌ Using `xcodebuild` without setting developer directory → Falls back to Command Line Tools (insufficient)
4. ❌ **Passing SwiftData models to views** → Use POCOs instead
5. ❌ **Updating POCOs without saving** → Always call `store.updatePodcast()` or `store.updateEpisode()`
6. ❌ **Creating circular references** → Use `podcastID: String` in EpisodePOCO, not object reference
7. ❌ Ignoring design patterns → Follow `/docs/UI_DESIGN_PATTERNS.md` for consistency

## Project Context

Built with XcodeBuildMCP scaffolding tool. Core features:
1. **Multi-Podcast Management**: Create/manage via PodcastLibraryStore (POCO + SwiftData hybrid)
2. **Transcript Converter**: Zencastr/generic formats → YouTube SRT (with speaker names, timestamp calculation)
3. **Thumbnail Generator**: Background + overlay + episode number → PNG/JPEG (AppKit-based rendering)
4. **AI Content Generation**: Apple Intelligence integration for titles, descriptions, social posts (macOS 26+)
5. **Translation Support**: SRT subtitle and episode metadata translation (macOS 26+)
6. **POCO Architecture**: Hybrid persistence (POCOs for UI, SwiftData for database, CloudKit-ready)
7. **Master-Detail Navigation**: Three-column layout (Podcasts → Episodes → Detail)
8. **Settings & Customization**: Theme selection, font management

## POCO Architecture (Critical!)

**UI Layer uses POCOs, persistence layer uses SwiftData:**

**POCOs (UI Layer):**
- `PodcastPOCO` - Simple class with all podcast properties
- `EpisodePOCO` - Simple class with all episode properties
- Used in ALL Views and ViewModels
- Fast, testable, no SwiftData dependencies

**SwiftData (Persistence Layer):**
- `Podcast` - @Model mirroring PodcastPOCO structure
- `Episode` - @Model mirroring EpisodePOCO structure
- `@Relationship(deleteRule: .cascade)` for episodes
- `@Attribute(.unique)` on ID (CloudKit-compatible)

**PodcastLibraryStore (Bridge):**
- `@Published var podcasts: [PodcastPOCO]` - UI binds here
- `@Published var episodes: [String: [EpisodePOCO]]` - Keyed by podcast ID
- Converts SwiftData ↔ POCOs automatically
- Handles all CRUD operations

**Data Flow:**
```
User Action → ViewModel → POCO Update → Store.update() → SwiftData Save → POCO Array Update → UI Refresh
```

**Benefits:**
- ✅ No SwiftData quirks in UI (no @Query, no faulting)
- ✅ Fast rendering (simple classes)
- ✅ Easy testing (no ModelContext needed)
- ✅ Reliable persistence (SwiftData in background)

**See `/docs/POCO_ARCHITECTURE.md` for complete details.**

**Image Storage:**
- Stored as Data in both POCOs and SwiftData models
- Auto-processed: resize to 1024x1024 max + JPEG 0.8 compression

**CloudKit Sync:**
- Currently disabled (local-only)
- CloudKit-ready schema - see `PersistenceController.swift`
- Container ID: `iCloud.com.refractored.PodcastAssistant`

## App Documentation

**Comprehensive documentation in `/docs` folder:**

**Core Architecture:**
- `/docs/POCO_ARCHITECTURE.md` - **START HERE** - Hybrid POCO/SwiftData pattern explained
- `/docs/FOLDER_STRUCTURE.md` - File organization and where to add code
- `/docs/UI_DESIGN_PATTERNS.md` - Consistent design system and components
- `/docs/ARCHITECTURE.md` - System overview

**Features:**
- `/docs/AI_IDEAS.md` - AI content generation (macOS 26+)
- `/docs/TRANSLATION.md` - SRT and episode translation (macOS 26+)
- `/docs/SETTINGS.md` - Settings and customization

**When adding features or making changes:**
1. Read relevant docs first (especially POCO_ARCHITECTURE.md and FOLDER_STRUCTURE.md)
2. Follow established patterns
3. Update docs if you change architecture or add major features
4. Add to `/docs/README.md` if creating new doc files

## Apple API Documentation

Always refer to official Apple documentation for APIs used. We have the apple-docs-mcp server to search. Else, fetch from apple docs and try to get the latest information and only videos relevant to the latest WWDCs and SDKs.