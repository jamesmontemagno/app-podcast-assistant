# Podcast Assistant - AI Agent Instructions

## Project Architecture

This is a macOS SwiftUI app using a **workspace + SPM package architecture** with **pure SwiftData @Query binding**:

- **App Shell**: `PodcastAssistant/` - Minimal app lifecycle code (App entry point only)
- **Feature Code**: `PodcastAssistantPackage/Sources/PodcastAssistantFeature/` - **ALL business logic, services, views, and models live here**
- **Always open**: `PodcastAssistant.xcworkspace` (never the .xcodeproj file)

This app targets the latest macOS SDK. Uses **SwiftData models with @Query for reactive UI binding** (CloudKit-ready). macOS 26 APIs are preferred.

### Critical File Organization Pattern
```
PodcastAssistantPackage/Sources/PodcastAssistantFeature/
├── Models/
│   ├── SwiftData/          # Database models (Podcast, Episode, EpisodeContent)
│   └── Supporting/         # Helper models (AppSettings, SRTDocument, etc.)
├── Services/
│   ├── Data/              # PersistenceController (SwiftData container setup)
│   ├── UI/                # UI services (ThumbnailGenerator)
│   └── Utilities/         # Business logic (TranscriptConverter, ImageUtilities, etc.)
├── ViewModels/            # @MainActor ObservableObject classes for complex business logic
└── Views/
    ├── Forms/             # Modal create/edit forms
    ├── Sections/          # Main detail pane tabs (TranscriptView, ThumbnailView, etc.)
    └── Sheets/            # Action popups (translation sheets)
```

**See `/docs/SWIFTDATA_QUERY_ARCHITECTURE.md` and `/docs/FOLDER_STRUCTURE.md` for complete details.**

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

### 1. SwiftData @Query Pattern (Critical!)
**Views bind directly to SwiftData models using @Query**:
```swift
// Top-level @Query for all data
@Query(sort: \Podcast.name) private var podcasts: [Podcast]

// Create child views with filtered @Query (dynamic predicates)
struct EpisodeListView: View {
    let podcastID: String
    @Query private var episodes: [Episode]
    
    init(podcastID: String) {
        self.podcastID = podcastID
        let predicate = #Predicate<Episode> { episode in
            episode.podcast?.id == podcastID
        }
        _episodes = Query(filter: predicate, sort: \Episode.episodeNumber)
    }
}

// ViewModels work with SwiftData models + ModelContext
@MainActor
public class ThumbnailViewModel: ObservableObject {
    @Published public var episode: Episode
    private var modelContext: ModelContext?
    
    public init(episode: Episode, modelContext: ModelContext?) {
        self.episode = episode
        self.modelContext = modelContext
    }
    
    // Update model directly, save via ModelContext
    public var fontSize: Double {
        get { episode.fontSize }
        set { 
            episode.fontSize = newValue
            try? modelContext?.save()  // Persist immediately
            objectWillChange.send()
        }
    }
}
```

**Why pure SwiftData?**
- ✅ Trust the framework - @Query is reactive and works reliably
- ✅ No intermediate bridge layers (~1,500 lines eliminated)
- ✅ Direct model binding with @Bindable
- ✅ External storage for performance (large data)

### 2. External Storage Pattern (Critical for Performance!)
**Use @Attribute(.externalStorage) for large data** to prevent memory bloat:
```swift
@Model
public final class EpisodeContent {
    // Large text - store externally
    @Attribute(.externalStorage) public var transcriptInputText: String?
    @Attribute(.externalStorage) public var transcriptSRT: String?
    
    // Large binary data - store externally
    @Attribute(.externalStorage) public var thumbnailBackgroundData: Data?
    @Attribute(.externalStorage) public var videoData: Data?
    
    // Small metadata - inline is fine
    public var lastModified: Date = Date()
}

// Separate lightweight metadata from heavy content
@Model
public final class Episode: Hashable {
    public var id: String
    public var title: String
    
    // Lazy-loaded heavy content with cascade delete
    @Relationship(deleteRule: .cascade, inverse: \EpisodeContent.episode)
    public var content: EpisodeContent?
    
    // Convenience accessor for UI
    public var transcriptInputText: String? {
        get { content?.transcriptInputText }
        set { 
            if content == nil { content = EpisodeContent() }
            content?.transcriptInputText = newValue
        }
    }
}
```

### 3. List Selection Pattern (Required for NavigationSplitView!)
**MUST use .tag() + Hashable** for selection binding to work:
```swift
// Add Hashable conformance to models
@Model
public final class Podcast: Hashable {
    @Attribute(.unique) public var id: String
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Podcast, rhs: Podcast) -> Bool {
        lhs.id == rhs.id
    }
}

// In view - MUST add .tag() to each row
NavigationSplitView {
    List(podcasts, selection: $selectedPodcast) { podcast in
        PodcastRow(podcast: podcast)
            .tag(podcast)  // ← REQUIRED! Without this, selection won't work
    }
}
```

### 4. Master-Detail Navigation Pattern
Three-column NavigationSplitView with @Query at each level:
```swift
NavigationSplitView {
    // Sidebar: @Query for all podcasts
    @Query(sort: \Podcast.name) private var podcasts: [Podcast]
    List(podcasts, selection: $selectedPodcast) { podcast in
        PodcastRow(podcast).tag(podcast)
    }
} content: {
    // Middle: New view with filtered @Query for episodes
    if let podcast = selectedPodcast {
        EpisodeListView(podcastID: podcast.id, selection: $selectedEpisode)
    }
} detail: {
    // Detail: Pass SwiftData model directly
    if let episode = selectedEpisode {
        EpisodeDetailView(episode: episode)
    }
}
```

### 5. File Dialogs Pattern (NSOpenPanel/NSSavePanel)
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

### 6. Data Management Pattern
**Use @Query and ModelContext directly** - no bridge layers needed:
```swift
// In ContentView - @Query for top-level data
@Query(sort: \Podcast.name) private var podcasts: [Podcast]
@Environment(\.modelContext) private var modelContext

// Create/Update/Delete directly
let podcast = Podcast(name: "New Show")
modelContext.insert(podcast)
try? modelContext.save()

// Update existing
podcast.name = "Updated Name"
try? modelContext.save()  // @Query views will auto-refresh

// Delete
modelContext.delete(podcast)
try? modelContext.save()
```

**ViewModels work with SwiftData models**:
```swift
@MainActor
public class MyViewModel: ObservableObject {
    @Published public var episode: Episode
    private var modelContext: ModelContext?
    
    public init(episode: Episode, modelContext: ModelContext?) {
        self.episode = episode
        self.modelContext = modelContext
    }
    
    public func saveChanges() {
        try? modelContext?.save()  // That's it!
        objectWillChange.send()
    }
}
```

### 7. UI Design Pattern
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

### 8. Format Detection Pattern
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
   - Need persistence? → Create SwiftData @Model in `Models/SwiftData/`
   - Need filtered data? → Create new View with @Query and #Predicate ("when in doubt, create a new view")
   - Need business logic? → Create service in `Services/Utilities/`
   - Need complex UI state? → Create ViewModel (only if needed, prefer direct model binding)
   - New form? → `Views/Forms/`
   - New tab? → `Views/Sections/`
   - New popup? → `Views/Sheets/`

2. **Create files in proper folders**:
   - SwiftData models: `Models/SwiftData/`
   - Supporting models: `Models/Supporting/`
   - Services: `Services/Data/`, `Services/UI/`, or `Services/Utilities/`
   - ViewModels: `ViewModels/` (only for complex business logic)
   - Views: `Views/Forms/`, `Views/Sections/`, or `Views/Sheets/`

3. **Follow patterns**:
   - Use @Query with dynamic predicates for filtered data
   - Add @Attribute(.externalStorage) to large string/Data properties
   - Add Hashable conformance + .tag() for List selection
   - Pass ModelContext explicitly to ViewModels
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
4. ❌ **Forgetting .tag() on List rows** → Selection binding won't update (but rows will highlight)
5. ❌ **Missing Hashable conformance** → List selection won't work with SwiftData models
6. ❌ **Filtering arrays instead of using @Query** → Breaks reactivity, UI won't auto-update
7. ❌ **Not using @Attribute(.externalStorage) for large data** → Memory bloat, sluggish UI
8. ❌ **Passing filtered arrays down** → Create new View with its own @Query instead
9. ❌ Ignoring design patterns → Follow `/docs/UI_DESIGN_PATTERNS.md` for consistency

## Project Context

Built with XcodeBuildMCP scaffolding tool. Core features:
1. **Multi-Podcast Management**: Create/manage via SwiftData @Query with reactive UI binding
2. **Transcript Converter**: Zencastr/generic formats → YouTube SRT (with speaker names, timestamp calculation)
3. **Thumbnail Generator**: Background + overlay + episode number → PNG/JPEG (AppKit-based rendering)
4. **AI Content Generation**: Apple Intelligence integration for titles, descriptions, social posts (macOS 26+)
5. **Translation Support**: SRT subtitle and episode metadata translation (macOS 26+)
6. **SwiftData Architecture**: Pure SwiftData with @Query (no intermediate layers, CloudKit-ready)
7. **Master-Detail Navigation**: Three-column layout (Podcasts → Episodes → Detail)
8. **Settings & Customization**: Theme selection, font management

## SwiftData Architecture (Critical!)

**Pure SwiftData with @Query - no intermediate layers:**

**SwiftData Models:**
- `Podcast` - @Model with Hashable conformance for List selection
- `Episode` - @Model with lightweight metadata + Hashable conformance
- `EpisodeContent` - @Model with @Attribute(.externalStorage) for heavy data
- `@Relationship(deleteRule: .cascade)` for parent-child relationships
- `@Attribute(.unique)` on ID (CloudKit-compatible)

**UI Layer:**
- Views use @Query directly with dynamic #Predicate for filtering
- `@Bindable` for two-way binding to model properties
- `@Environment(\.modelContext)` for CRUD operations
- Create new Views with filtered @Query instead of passing arrays

**Data Flow:**
```
User Action → Update Model → modelContext.save() → @Query Auto-Refreshes → UI Updates
```

**Performance Optimization:**
- `@Attribute(.externalStorage)` on all large strings and Data properties
- Separate heavy content (EpisodeContent) from lightweight metadata (Episode)
- Lazy loading via optional relationships
- Batch operations with single save() call

**Benefits:**
- ✅ ~1,500 lines of code eliminated (no POCOs, no bridge layer)
- ✅ Trust the framework - @Query reactivity works reliably
- ✅ Direct model binding with @Bindable
- ✅ External storage prevents memory bloat

**See `/docs/SWIFTDATA_QUERY_ARCHITECTURE.md` for complete details.**

**Image Storage:**
- Stored as Data in SwiftData models with @Attribute(.externalStorage)
- Auto-processed: resize to 1024x1024 max + JPEG 0.8 compression
- External storage prevents memory bloat with large images

**CloudKit Sync:**
- Currently disabled (local-only)
- CloudKit-ready schema - see `PersistenceController.swift`
- Container ID: `iCloud.com.refractored.PodcastAssistant`

## SwiftData Quick Tips (CRITICAL!)

**The 5 SwiftData Rules to Remember:**

1. **"When in Doubt, Create a New View"** - Don't filter and pass arrays, create new View with @Query and #Predicate:
   ```swift
   init(podcastID: String) {
       let predicate = #Predicate<Episode> { $0.podcast?.id == podcastID }
       _episodes = Query(filter: predicate)
   }
   ```

2. **External Storage is Required for Performance** - Use @Attribute(.externalStorage) on large strings and Data:
   ```swift
   @Attribute(.externalStorage) public var transcriptInputText: String?
   @Attribute(.externalStorage) public var thumbnailBackgroundData: Data?
   ```

3. **List Selection Needs .tag() + Hashable** - BOTH are required or selection won't work:
   ```swift
   List(items, selection: $selected) { item in
       Row(item).tag(item)  // ← Don't forget .tag()!
   }
   // Plus Hashable conformance on model
   ```

4. **Trust modelContext.save()** - Update models directly, call save(), @Query handles reactivity:
   ```swift
   episode.title = "New Title"
   try? modelContext.save()  // @Query views auto-refresh
   ```

5. **Keep It Simple** - Don't over-engineer with bridge layers, ViewModels, or manual sync logic. SwiftData handles it.

**Common Mistakes:**
- ❌ Forgetting .tag() → selection appears to work but binding doesn't update
- ❌ Not using external storage → memory bloat with large data
- ❌ Filtering arrays in parent views → breaks @Query reactivity
- ❌ Missing Hashable → List selection won't work

## App Documentation

**Comprehensive documentation in `/docs` folder:**

**Core Architecture:**
- `/docs/SWIFTDATA_QUERY_ARCHITECTURE.md` - **START HERE** - Pure SwiftData @Query pattern explained
- `/docs/SWIFTDATA_BEST_PRACTICES.md` - **CRITICAL TIPS** - The 5 rules, common pitfalls, performance optimization
- `/docs/FOLDER_STRUCTURE.md` - File organization and where to add code
- `/docs/UI_DESIGN_PATTERNS.md` - Consistent design system and components
- `/docs/ARCHITECTURE.md` - System overview

**Features:**
- `/docs/AI_IDEAS.md` - AI content generation (macOS 26+)
- `/docs/TRANSLATION.md` - SRT and episode translation (macOS 26+)
- `/docs/SETTINGS.md` - Settings and customization

**When adding features or making changes:**
1. Read relevant docs first (especially SWIFTDATA_QUERY_ARCHITECTURE.md and SWIFTDATA_BEST_PRACTICES.md)
2. Follow the 5 SwiftData rules (see Quick Tips above)
3. Follow established patterns
4. Update docs if you change architecture or add major features
5. Add to `/docs/README.md` if creating new doc files

## Apple API Documentation

Always refer to official Apple documentation for APIs used. We have the apple-docs-mcp server to search. Else, fetch from apple docs and try to get the latest information and only videos relevant to the latest WWDCs and SDKs.