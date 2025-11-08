# Podcast Assistant - Architecture Overview

## System Architecture

Podcast Assistant uses a **workspace + SPM package architecture** for clean code separation and modularity:

```
PodcastAssistant/                          # App shell (minimal)
└── PodcastAssistantApp.swift              # Entry point only

PodcastAssistantPackage/                   # All feature code
└── Sources/PodcastAssistantFeature/
    ├── Models/                            # Core Data entities
    ├── Services/                          # Business logic
    ├── ViewModels/                        # @MainActor state management
    └── Views/                             # SwiftUI views
```

### Key Architectural Principles

1. **Workspace-first development** - Always open `PodcastAssistant.xcworkspace`, never `.xcodeproj`
2. **Public API pattern** - All types in the package exposed to the app target must be `public` with `public init()`
3. **MVVM pattern** - Service → ViewModel → View separation
4. **Core Data persistence** - Local storage with CloudKit-ready schema for future iCloud sync

## Application Flow

### Three-Column Master-Detail Navigation

```
Sidebar (Podcasts)  →  Middle (Episodes)  →  Detail (Transcript/Thumbnail)
     ↓                        ↓                         ↓
 @FetchRequest          episodesArray           TranscriptView
  (Podcasts)          (from selected podcast)   ThumbnailView
```

#### Column 1: Podcast Sidebar
- Displays all podcasts with artwork thumbnails
- Create/Edit/Delete podcast operations
- Persists last selected podcast ID in UserDefaults
- Auto-selects first podcast on launch if no saved selection

#### Column 2: Episode List
- Shows episodes for selected podcast (sorted by creation date)
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
User Action → ViewModel → Core Data Entity → Context Save → UI Update
                ↑                                              ↓
                └──────────── @Published / objectWillChange ──┘
```

## Core Components

### Core Data Stack

**Entities:**
- `Podcast` - Podcast metadata, artwork, default thumbnail settings
- `Episode` - Episode data, transcript text, thumbnail images, settings

**Relationships:**
- `Podcast.episodes` ↔ `Episode.podcast` (one-to-many, cascade delete)

**PersistenceController:**
- Singleton pattern for shared Core Data stack
- Local-only storage with `NSPersistentContainer`
- CloudKit migration path documented in-code
- Preview support with in-memory store

### Services Layer

#### TranscriptConverter
- Pure business logic (no UI dependencies)
- Auto-detects transcript formats (Zencastr, time-range)
- Converts to YouTube-compatible SRT format
- Regex-based pattern matching for format detection

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
├── PodcastAssistant.xcdatamodeld/          # Core Data model definition
├── Podcast+CoreDataClass.swift             # Podcast entity class
├── Podcast+CoreDataProperties.swift        # Podcast properties + helpers
├── Episode+CoreDataClass.swift             # Episode entity class
├── Episode+CoreDataProperties.swift        # Episode properties + helpers
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

### iCloud Sync (Planned)
- Swap `NSPersistentContainer` → `NSPersistentCloudKitContainer`
- Add CloudKit entitlements
- Configure iCloud container identifiers
- Current schema is CloudKit-compatible (no migration needed)

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
