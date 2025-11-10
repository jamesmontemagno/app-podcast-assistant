# Podcast Assistant - Architecture Overview

## System Architecture

Podcast Assistant uses a **hybrid POCO + SwiftData architecture** with clean separation between UI and persistence layers:

```
PodcastAssistant/                          # App shell (minimal)
└── PodcastAssistantApp.swift              # Entry point only

PodcastAssistantPackage/                   # All feature code
└── Sources/PodcastAssistantFeature/
    ├── Models/
    │   ├── POCOs/                        # UI layer (fast, simple)
    │   ├── SwiftData/                    # Persistence layer
    │   └── Supporting/                    # Helper models
    ├── Services/
    │   ├── Data/                         # PodcastLibraryStore (POCO ↔ SwiftData)
    │   ├── UI/                           # UI services
    │   └── Utilities/                     # Business logic
    ├── ViewModels/                        # @MainActor state management
    └── Views/
        ├── Forms/                         # Modal create/edit forms
        ├── Sections/                      # Main content tabs
        └── Sheets/                        # Action popups
```

### Key Architectural Principles

1. **Workspace-first development** - Always open `PodcastAssistant.xcworkspace`, never `.xcodeproj`
2. **Public API pattern** - All types in the package exposed to the app target must be `public` with `public init()`
3. **POCO pattern** - Views and ViewModels use POCOs, never SwiftData models
4. **Hybrid persistence** - POCOs in memory, SwiftData for database (see `POCO_ARCHITECTURE.md`)
5. **Organized structure** - Logical folder nesting (see `FOLDER_STRUCTURE.md`)

## Application Flow

### Three-Column Master-Detail Navigation

```
Sidebar (Podcasts)  →  Middle (Episodes)  →  Detail (Sections)
     ↓                        ↓                    ↓
store.podcasts      store.episodes[podcastID]  TranscriptView
 [PodcastPOCO]         [EpisodePOCO]           ThumbnailView
                                               AIIdeasView
```

#### Column 1: Podcast Sidebar
- Displays `store.podcasts` array (POCOs, not SwiftData)
- Create/Edit/Delete via PodcastLibraryStore
- Persists last selected podcast ID in UserDefaults
- Auto-selects first podcast on launch

#### Column 2: Episode List
- Shows `store.episodes[selectedPodcastID]` (POCOs)
- Lazy-loaded when podcast selected
- Create/Edit/Delete via PodcastLibraryStore
- Visual indicators for transcript/thumbnail completion

#### Column 3: Detail Pane
- Tab selection for Transcript/Thumbnail/AI Ideas/Details
- Episode-scoped editing (POCOs updated, saved to SwiftData via store)
- Real-time preview for thumbnail generation
- AI-powered content generation (macOS 26+)
- Episode translation support (macOS 26+)
- File import/export operations

### Data Flow (POCO Pattern)

```
User Action → ViewModel → POCO Update → Store.updateEpisode() → SwiftData Save → POCO Array Update → UI Refresh
                ↑                                                                         ↓
                └────────────────────── @Published triggers ──────────────────────────────┘
```

**Key Difference:** ViewModels work with POCOs, PodcastLibraryStore handles SwiftData persistence.

## Core Components

### POCO + SwiftData Hybrid Stack

**See `POCO_ARCHITECTURE.md` for complete details.**

**POCOs (UI Layer):**
- `PodcastPOCO` - Simple class with podcast data
- `EpisodePOCO` - Simple class with episode data
- Used in all Views and ViewModels
- Fast, predictable, testable

**SwiftData (Persistence Layer):**
- `Podcast` - @Model with all properties mirroring PodcastPOCO
- `Episode` - @Model with all properties mirroring EpisodePOCO
- Cascade delete relationship (podcast → episodes)
- CloudKit-ready schema

**PodcastLibraryStore (Bridge):**
- `@Published` arrays of POCOs for UI binding
- Fetches from SwiftData, converts to POCOs
- Updates SwiftData when POCOs change
- Central CRUD operations
- Singleton pattern with ModelContext

**Benefits:**
- ✅ No SwiftData quirks in UI (no `@Query`, no faulting)
- ✅ Fast UI performance (simple objects)
- ✅ Reliable persistence (SwiftData + SQLite)
- ✅ Easy testing (POCOs don't need ModelContext)

### Services Layer

#### TranscriptConverter
- Pure business logic (no UI dependencies)
- Auto-detects transcript formats (Zencastr, time-range)
- Converts to YouTube-compatible SRT format
- Regex-based pattern matching for format detection

#### TranslationService
- Wraps macOS Translation API (available macOS 14+)
- Supports 12+ YouTube subtitle languages
- Preserves SRT timestamps while translating text
- Async translation with progress handling

#### ThumbnailGenerator
- AppKit-based image compositing
- Text rendering with stroke/fill effects
- Multi-format export (PNG, JPEG)
- Configurable positioning and styling

#### ImageUtilities
- Image preprocessing for Core Data storage
- Automatic resizing to max 1024x1024
- JPEG compression at 0.8 quality
- Keeps database size manageable while maintaining quality

#### FontManager
- Manages custom font import and registration
- Validates and copies font files (TTF, OTF, TTC)
- Storage: `~/Library/Application Support/PodcastAssistant/Fonts/`
- Uses CoreText (CTFontManager) for macOS font registration
- Auto-loads imported fonts on app launch
- Cleanup and unregistration support

### ViewModels

**Pattern:** ViewModels own POCO references, call store for persistence

#### ThumbnailViewModel
- Accepts `EpisodePOCO` and `PodcastLibraryStore` dependencies
- Computed properties read/write to POCO
- Auto-generation with debouncing (150ms)
- Calls `store.updateEpisode()` to persist changes
- No ModelContext needed

```swift
@MainActor
public final class ThumbnailViewModel: ObservableObject {
    @Published public var episode: EpisodePOCO
    private let store: PodcastLibraryStore
    
    public var backgroundImage: NSImage? {
        get { /* read from episode.thumbnailBackgroundData */ }
        set { 
            episode.thumbnailBackgroundData = processedData
            try? store.updateEpisode(episode)  // Persist
        }
    }
}
```

#### AIIdeasViewModel (macOS 26+)
- Apple Intelligence integration for content generation
- Generates titles, descriptions, social posts, chapter markers
- In-memory state (not persisted)
- Uses SystemLanguageModel for on-device AI
- Transcript cleaning and preparation

#### EpisodeTranslationViewModel (macOS 26+)
- Episode title/description translation
- Language availability tracking
- Uses TranslationService (macOS Translation API)
- Copy-to-clipboard workflow (not persisted)

### Views

**See `FOLDER_STRUCTURE.md` for complete organization and `UI_DESIGN_PATTERNS.md` for design system.**

#### ContentView (Main Navigation)
- NavigationSplitView with three columns
- `@StateObject` for PodcastLibraryStore
- Loads initial data on appear: `store.loadInitialData(context: modelContext)`
- Injects store via `.environmentObject()`
- Settings button with sheet presentation

#### Forms/ (Modal Create/Edit)
- **PodcastFormView** - Create/edit podcast with tabbed interface
- **EpisodeFormView** - Create/edit episodes
- Pattern: Local copy editing, save to store on submit
- Design: VStack(spacing: 0), dividers, .borderedProminent buttons

#### Sections/ (Main Detail Pane Tabs)
- **TranscriptView** - Side-by-side transcript conversion
- **ThumbnailView** - Three-column thumbnail generation
- **AIIdeasView** - Four-section AI content creation
- **DetailsView** - Episode metadata display
- Pattern: Accept EpisodePOCO, use ViewModels for state

#### Sheets/ (Action Popups)
- **EpisodeTranslationSheet** - Translate episode metadata
- **TranscriptTranslationSheet** - Translate SRT files
- Pattern: Temporary UI for one-time actions, copy-to-clipboard

## File Organization

**See `FOLDER_STRUCTURE.md` for complete details.**

```
Models/
├── POCOs/                                  # UI-layer simple classes
│   ├── EpisodePOCO.swift
│   └── PodcastPOCO.swift
├── SwiftData/                              # Database models
│   ├── Episode.swift
│   └── Podcast.swift
└── Supporting/                              # Helper models
    ├── AppSettings.swift                   # App-wide settings (@Model)
    ├── MenuActions.swift                   # Menu commands
    ├── SRTDocument.swift                   # File document
    └── TranscriptEntry.swift               # SRT entry

Services/
├── Data/                                   # Data management
│   ├── PersistenceController.swift         # SwiftData stack
│   └── PodcastLibraryStore.swift           # POCO/SwiftData bridge
├── UI/                                     # UI services
│   └── ThumbnailGenerator.swift            # Image composition
└── Utilities/                               # Business logic
    ├── ColorExtensions.swift               # Color utilities
    ├── FontManager.swift                   # Font management
    ├── ImageUtilities.swift                # Image processing
    ├── TranscriptCleaner.swift             # Preprocessing
    ├── TranscriptConverter.swift           # Format conversion
    └── TranslationService.swift            # Translation API

ViewModels/                                  # State management
├── AIIdeasViewModel.swift
├── EpisodeTranslationViewModel.swift
├── SettingsViewModel.swift
└── ThumbnailViewModel.swift

Views/                                       # UI layer
├── Forms/                                  # Modal create/edit
│   ├── EpisodeFormView.swift
│   └── PodcastFormView.swift
├── Sections/                               # Detail pane tabs
│   ├── AIIdeasView.swift
│   ├── DetailsView.swift
│   ├── ThumbnailView.swift
│   └── TranscriptView.swift
├── Sheets/                                 # Action popups
│   ├── EpisodeTranslationSheet.swift
│   └── TranscriptTranslationSheet.swift
├── EpisodeDetailView.swift                # Detail coordinator
└── SettingsView.swift                     # Settings modal
```

## Build Configuration

### XCConfig Files
- `Shared.xcconfig` - Common settings across all configurations
- `Debug.xcconfig` - Development-specific settings
- `Release.xcconfig` - Production build settings
- `Tests.xcconfig` - Test target settings

### Entitlements
- **Sandbox**: Enabled (required for macOS App Store)
- **User Selected Files**: Read/write access for user-chosen files
- **Future iCloud**: Entitlements documented but not enabled

### Package Dependencies
Managed in `PodcastAssistantPackage/Package.swift` (not Xcode project file)

## Build & Run

**Prerequisites:**
```bash
# Set Xcode developer directory (first time only)
sudo xcode-select --switch /Applications/Xcode-26.0.1.app/Contents/Developer
```

**Build:**
```bash
xcodebuild -workspace PodcastAssistant.xcworkspace \
           -scheme PodcastAssistant \
           -configuration Debug
```

**Clean build products:**
```bash
xcodebuild -workspace PodcastAssistant.xcworkspace \
           -scheme PodcastAssistant \
           clean
```

## Testing Strategy

### Unit Tests
- `PodcastAssistantFeatureTests/` - Swift Testing framework
- Tests for POCOs (no ModelContext needed!)
- Tests for services (TranscriptConverter, ImageUtilities)
- Tests for ViewModels with mock store

**Benefits of POCO architecture:**
```swift
@Test func testEpisodeCreation() {
    let podcast = PodcastPOCO(name: "Test")
    let episode = EpisodePOCO(
        podcastID: podcast.id,
        title: "Episode 1",
        episodeNumber: 1,
        podcast: podcast
    )
    
    #expect(episode.fontSize == podcast.defaultFontSize)
    // No ModelContext needed! ✅
}
```

### Preview Support
- `PersistenceController.preview` - In-memory SwiftData store
- Sample POCO data generation for previews
- Isolated testing environment

## Future Enhancements

### iCloud Sync (CloudKit-Ready)
- Schema is CloudKit-compatible (String IDs, proper relationships)
- Instructions in `PersistenceController.swift` class documentation
- Container ID prepared: `iCloud.com.refractored.PodcastAssistant`
- Requires: Uncomment config + entitlements + Apple Developer setup

### AI Content Persistence
- Save generated AI content to Core Data models
- Version history for AI-generated content
- Template library for common content types

### Enhanced Translation Features
- Batch translate multiple episodes
- Auto-translate on episode creation
- Translation quality feedback
- Custom terminology dictionaries

### Multi-Window Support
- Replace `WindowGroup` with `WindowGroup(for: Podcast.ID.self)`
- Per-podcast window management
- Window restoration support

### Export Workflows
- Batch export all episodes for a podcast
- Custom export templates
- Automated file naming conventions

### Advanced Thumbnail Features
- Gradient backgrounds
- Custom text effects (shadow, glow)
- Template library
- Drag-and-drop image support
- Video thumbnail generation from podcast audio

### Settings Enhancements
- Accent color customization
- Custom color schemes
- Font categories/tags
- Export/import settings profiles

## Documentation

### Core Documentation
- **`POCO_ARCHITECTURE.md`** - Hybrid POCO/SwiftData pattern explained
- **`FOLDER_STRUCTURE.md`** - File organization and where to add code
- **`UI_DESIGN_PATTERNS.md`** - Consistent design system and components
- **`ARCHITECTURE.md`** (this file) - System overview

### Feature Documentation
- **`AI_IDEAS.md`** - AI content generation features (macOS 26+)
- **`TRANSLATION.md`** - SRT and episode translation features (macOS 26+)
- **`SETTINGS.md`** - Settings and customization options
- **`SETTINGS_UI.md`** - Settings UI mockups and layout

## Summary

**Podcast Assistant Architecture:**
- ✅ **POCO Pattern** - Fast UI with simple objects
- ✅ **SwiftData Persistence** - Reliable database storage
- ✅ **Clean Separation** - POCOs for UI, SwiftData for persistence
- ✅ **Organized Structure** - Logical folder nesting
- ✅ **Consistent Design** - Polished UI patterns throughout
- ✅ **CloudKit-Ready** - Can enable iCloud sync without changing UI code

**Read the detailed docs** for complete information on each aspect of the architecture.
