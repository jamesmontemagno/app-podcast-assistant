# Podcast Assistant - Architecture Overview

## System Architecture

Podcast Assistant uses a **workspace + SPM package architecture** for clean code separation and modularity:

```
PodcastAssistant/                          # App shell (minimal)
└── PodcastAssistantApp.swift              # Entry point only

PodcastAssistantPackage/                   # All feature code
└── Sources/PodcastAssistantFeature/
    ├── Models/                            # SwiftData models
    ├── Services/                          # Business logic
    ├── ViewModels/                        # @MainActor state management
    └── Views/                             # SwiftUI views
```

### Key Architectural Principles

1. **Workspace-first development** - Always open `PodcastAssistant.xcworkspace`, never `.xcodeproj`
2. **Public API pattern** - All types in the package exposed to the app target must be `public` with `public init()`
3. **MVVM pattern** - Service → ViewModel → View separation
4. **SwiftData persistence** - Local storage, CloudKit-ready (see `PersistenceController.swift` to enable)

## Application Flow

### Three-Column Master-Detail Navigation

```
Sidebar (Podcasts)  →  Middle (Episodes)  →  Detail (Transcript/Thumbnail)
     ↓                        ↓                         ↓
    @Query              podcast.episodes         TranscriptView
  (Podcasts)          (sorted by createdAt)      ThumbnailView
```

#### Column 1: Podcast Sidebar
- Displays all podcasts with artwork thumbnails using `@Query`
- Create/Edit/Delete podcast operations
- Persists last selected podcast ID (String) in UserDefaults
- Auto-selects first podcast on launch if no saved selection

#### Column 2: Episode List
- Shows episodes from selected podcast's array (native SwiftData array)
- Create/Edit/Delete episode operations
- Episode number auto-increment suggestion
- Visual indicators for transcript/thumbnail completion

#### Column 3: Detail Pane
- Segmented control for Transcript/Thumbnail tabs
- Episode-scoped editing (all changes auto-save to Core Data)
- Real-time preview for thumbnail generation
- File import/export operations

### Data Flow

```
User Action → ViewModel → SwiftData Model → ModelContext Save → UI Update (automatic)
                ↑                                                    ↓
                └──────────── @Published / objectWillChange ─────────┘
```

## Core Components

### SwiftData Stack

**Models:**
- `Podcast` - @Model with podcast metadata, artwork, default thumbnail settings
- `Episode` - @Model with episode data, transcript text, thumbnail images, settings

**Relationships:**
- `Podcast.episodes: [Episode]` with `@Relationship(deleteRule: .cascade, inverse: \Episode.podcast)`
- `Episode.podcast: Podcast?` (inverse relationship)

**PersistenceController:**
- Singleton pattern for shared SwiftData stack
- `ModelContainer` with local-only storage (CloudKit disabled)
- CloudKit-ready schema - see class documentation for enabling
- Preview support with in-memory store

### Services Layer

#### TranscriptConverter
- Pure business logic (no UI dependencies)
- Auto-detects transcript formats (Zencastr, time-range)
- Converts to YouTube-compatible SRT format
- Regex-based pattern matching for format detection

#### TranslationService
- Wraps macOS Translation API (available macOS 12+)
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

### ViewModels

#### TranscriptViewModel
- Accepts `Episode` and `NSManagedObjectContext` dependencies
- Computed properties read/write directly to Core Data
- Automatic context saving after changes
- File import/export via NSOpenPanel/NSSavePanel
- Translation export with language selection sheet (macOS 12+)

#### ThumbnailViewModel
- Episode-bound with Core Data context
- Lazy-loaded images from Data blobs
- Real-time thumbnail generation on property changes
- Persists generated thumbnails to episode

### Views

#### ContentView (Main Navigation)
- `NavigationSplitView` with three columns
- `@FetchRequest` for podcast list
- Selection binding with UserDefaults persistence
- Empty state placeholders for each column

#### PodcastFormView
- Create/edit podcast metadata
- Image upload with automatic processing
- Default thumbnail settings configuration
- Sheet presentation for modal workflow

#### EpisodeFormView
- Create/edit episode details
- Auto-increment episode number suggestion
- Copies podcast defaults on creation
- Minimal form (title + number only)

#### TranscriptView
- Episode-scoped transcript editing
- Side-by-side input/output layout
- File import/export operations
- Real-time conversion feedback

#### ThumbnailView
- Episode-scoped thumbnail generation
- Three-column layout (controls, preview, export)
- Real-time preview updates
- Image clipboard paste support

## File Organization

```
Models/
├── Podcast.swift                           # @Model definition with all properties
├── Episode.swift                           # @Model definition with custom init
├── TranscriptEntry.swift                   # Legacy model (used for SRT)
└── SRTDocument.swift                       # FileDocument for export

Services/
├── PersistenceController.swift             # Core Data stack management
├── TranscriptConverter.swift               # Format detection & conversion
├── ThumbnailGenerator.swift                # Image compositing
└── ImageUtilities.swift                    # Image processing

ViewModels/
├── TranscriptViewModel.swift               # Transcript conversion state
└── ThumbnailViewModel.swift                # Thumbnail generation state

Views/
├── ContentView.swift                       # Main navigation container
├── PodcastFormView.swift                   # Podcast create/edit form
├── EpisodeFormView.swift                   # Episode create/edit form
├── TranscriptView.swift                    # Transcript editor
└── ThumbnailView.swift                     # Thumbnail generator
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
- Tests for `TranscriptConverter` format detection
- Tests for image processing utilities
- Core Data stack validation

### Preview Support
- `PersistenceController.preview` - In-memory Core Data store
- Sample data generation for SwiftUI previews
- Isolated testing environment

## Future Enhancements

### iCloud Sync (CloudKit-Ready)
- Schema is CloudKit-compatible (String IDs, proper relationships)
- Instructions in `PersistenceController.swift` class documentation
- Container ID prepared: `iCloud.com.refractored.PodcastAssistant`
- Requires: Uncomment config + entitlements + Apple Developer setup

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
