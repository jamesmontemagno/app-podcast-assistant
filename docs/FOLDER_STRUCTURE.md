# Folder Structure - Organized Code Architecture

## Overview

Podcast Assistant uses a carefully organized folder structure that promotes maintainability, scalability, and clean separation of concerns. This document explains the organization philosophy and where to find (or add) different types of code.

## Complete Structure

```
PodcastAssistantPackage/Sources/PodcastAssistantFeature/
├── ContentView.swift                    # Main app navigation container
│
├── Models/                              # All data models
│   ├── POCOs/                          # Plain Old Class Objects (UI layer)
│   │   ├── EpisodePOCO.swift
│   │   └── PodcastPOCO.swift
│   │
│   ├── SwiftData/                      # Database persistence models
│   │   ├── Episode.swift
│   │   └── Podcast.swift
│   │
│   └── Supporting/                      # Helper models
│       ├── AppSettings.swift           # App-wide settings (@Model)
│       ├── MenuActions.swift           # Menu command actions
│       ├── SRTDocument.swift           # SRT file document type
│       └── TranscriptEntry.swift       # SRT entry model
│
├── Services/                            # Business logic layer
│   ├── Data/                           # Data management services
│   │   ├── PersistenceController.swift # SwiftData stack
│   │   └── PodcastLibraryStore.swift   # POCO/SwiftData bridge
│   │
│   ├── UI/                             # UI-related services
│   │   └── ThumbnailGenerator.swift    # Image composition service
│   │
│   └── Utilities/                       # Utility services
│       ├── ColorExtensions.swift       # Color helper utilities
│       ├── FontManager.swift           # Font import/registration
│       ├── ImageUtilities.swift        # Image processing
│       ├── TranscriptCleaner.swift     # Transcript preprocessing
│       ├── TranscriptConverter.swift   # Format conversion
│       └── TranslationService.swift    # Translation API wrapper
│
├── ViewModels/                          # State management layer
│   ├── AIIdeasViewModel.swift          # AI content generation
│   ├── EpisodeTranslationViewModel.swift # Episode translation
│   ├── SettingsViewModel.swift         # Settings management
│   └── ThumbnailViewModel.swift        # Thumbnail generation
│
└── Views/                               # UI layer
    ├── Forms/                           # Modal forms for create/edit
    │   ├── EpisodeFormView.swift       # Create/edit episode
    │   └── PodcastFormView.swift       # Create/edit podcast
    │
    ├── Sections/                        # Main content sections
    │   ├── AIIdeasView.swift           # AI content generation tab
    │   ├── DetailsView.swift           # Episode details tab
    │   ├── ThumbnailView.swift         # Thumbnail generation tab
    │   └── TranscriptView.swift        # Transcript conversion tab
    │
    ├── Sheets/                          # Popup sheets for actions
    │   ├── EpisodeTranslationSheet.swift # Translate episode
    │   └── TranscriptTranslationSheet.swift # Translate SRT
    │
    ├── EpisodeDetailView.swift         # Episode detail coordinator
    └── SettingsView.swift              # App settings modal
```

## Organization Philosophy

### Models/ - Data Layer

**Purpose:** All data structures, whether for UI, persistence, or supporting operations.

#### POCOs/
**Plain Old Class Objects** - Simple, SwiftUI-friendly classes:
- No `@Model` macro
- Implement `Identifiable`, `Hashable`
- Used in all Views and ViewModels
- Fast, predictable, testable

**When to add here:**
- Creating a new UI-facing data structure
- Need a simple class for view state
- Want to avoid SwiftData complexity in UI

**Example:**
```swift
public final class MyNewPOCO: Identifiable, Hashable {
    public let id: String
    public var someProperty: String
    
    public init(...) { ... }
}
```

#### SwiftData/
**Persistence layer** - Database-backed models:
- Use `@Model` macro
- Define relationships with `@Relationship`
- Mirror POCO structure
- Handle persistence only

**When to add here:**
- Creating a new persistent entity
- Need database relationships
- Want CloudKit sync support

**Example:**
```swift
@Model
public final class MyNewModel {
    @Attribute(.unique) public var id: String
    public var someProperty: String
    
    public init(...) { ... }
}
```

#### Supporting/
**Helper models** - Specialized data structures:
- File document types
- Menu actions
- Temporary data structures
- Configuration objects

**When to add here:**
- Creating a file import/export type
- Defining menu commands
- Need a temporary data container
- App-wide configuration

### Services/ - Business Logic Layer

**Purpose:** All non-UI logic, data processing, and external integrations.

#### Data/
**Data management** - Persistence and data operations:
- SwiftData stack management
- POCO ↔ SwiftData conversion
- CRUD operations
- Data validation

**When to add here:**
- Creating a new data store
- Managing a new persistence layer
- Implementing data sync logic

**Current files:**
- `PersistenceController` - SwiftData setup
- `PodcastLibraryStore` - Hybrid POCO/SwiftData bridge

#### UI/
**UI-related services** - Heavy UI processing:
- Image generation/compositing
- PDF rendering
- Complex drawing operations
- UI utilities that don't fit in views

**When to add here:**
- Creating image processing services
- Implementing complex rendering
- Building UI-related utilities

**Current files:**
- `ThumbnailGenerator` - Image composition

#### Utilities/
**General utilities** - Reusable business logic:
- Text processing
- Format conversion
- External API wrappers
- Helper functions
- Extensions

**When to add here:**
- Creating a format converter
- Wrapping an external API
- Building reusable utilities
- Adding helper extensions

**Current files:**
- `TranscriptConverter` - Text format conversion
- `TranslationService` - macOS Translation API
- `ImageUtilities` - Image processing helpers
- `FontManager` - Font operations
- etc.

### ViewModels/ - State Management Layer

**Purpose:** Manage view state, handle user actions, coordinate between views and services.

**Characteristics:**
- `@MainActor` for UI thread safety
- `ObservableObject` for SwiftUI binding
- `@Published` properties for reactive updates
- Own POCO references (not SwiftData models)
- Call services for business logic
- Update store for persistence

**When to add here:**
- Creating a complex view that needs state management
- Need to coordinate multiple services
- Want to separate business logic from view
- Building reusable view logic

**Example:**
```swift
@MainActor
public final class MyViewModel: ObservableObject {
    @Published public var myData: MyPOCO
    @Published public var isLoading: Bool = false
    
    private let store: PodcastLibraryStore
    
    public init(data: MyPOCO, store: PodcastLibraryStore) {
        self.myData = data
        self.store = store
    }
    
    public func performAction() async {
        isLoading = true
        // Do work...
        try? store.updateMyData(myData)
        isLoading = false
    }
}
```

### Views/ - UI Layer

**Purpose:** SwiftUI views organized by function and presentation pattern.

#### Forms/
**Modal forms** - Create/edit workflows:
- Sheet presentation
- Form layout with sections
- Save/Cancel actions
- Local copy editing pattern

**When to add here:**
- Creating a new create/edit form
- Building a multi-section data entry form
- Need a modal editing workflow

**Pattern:**
```swift
struct MyFormView: View {
    @Binding var item: MyPOCO
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var store: PodcastLibraryStore
    
    @State private var localCopy: MyPOCO
    
    var body: some View {
        Form {
            // Edit localCopy
        }
        .toolbar {
            Button("Save") {
                item = localCopy
                try? store.updateItem(localCopy)
                dismiss()
            }
        }
    }
}
```

#### Sections/
**Main content sections** - Detail pane tabs:
- Large, complex views
- Main app functionality
- Tab content for EpisodeDetailView
- Read/write operations

**When to add here:**
- Creating a new detail pane tab
- Building a main feature view
- Need a large, standalone view

**Current sections:**
- `TranscriptView` - Transcript conversion
- `ThumbnailView` - Thumbnail generation
- `AIIdeasView` - AI content creation
- `DetailsView` - Episode metadata

#### Sheets/
**Action sheets** - Popup workflows:
- Temporary actions
- Quick operations
- Translation workflows
- Export/import dialogs

**When to add here:**
- Creating a quick action popup
- Building a translation/export workflow
- Need a temporary operation view

**Pattern:**
```swift
struct MyActionSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: MyViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with title
            Divider()
            
            // Content
            
            Divider()
            // Bottom buttons
        }
        .frame(width: 500, height: 400)
    }
}
```

#### Root Views
**Top-level views** - App structure:
- `ContentView.swift` - NavigationSplitView container
- `EpisodeDetailView.swift` - Episode detail coordinator
- `SettingsView.swift` - Settings modal

**When to add here:**
- Creating a new top-level navigation structure
- Building an app-wide modal

## File Naming Conventions

### Models
- **POCOs:** `[Name]POCO.swift` (e.g., `EpisodePOCO.swift`)
- **SwiftData:** `[Name].swift` (e.g., `Episode.swift`)
- **Supporting:** Descriptive names (e.g., `AppSettings.swift`, `SRTDocument.swift`)

### Services
- **Descriptive names:** `[What]Manager.swift`, `[What]Service.swift`, `[What]Utilities.swift`
- Examples: `FontManager.swift`, `TranslationService.swift`, `ImageUtilities.swift`

### ViewModels
- **Pattern:** `[Feature]ViewModel.swift`
- Examples: `ThumbnailViewModel.swift`, `AIIdeasViewModel.swift`

### Views
- **Forms:** `[Entity]FormView.swift` (e.g., `PodcastFormView.swift`)
- **Sections:** `[Feature]View.swift` (e.g., `TranscriptView.swift`)
- **Sheets:** `[Action]Sheet.swift` (e.g., `EpisodeTranslationSheet.swift`)

## Adding New Features

### Step-by-Step Guide

**1. Plan the feature:**
- Does it need persistence? → Add SwiftData model
- Does it need UI state? → Create POCO
- Complex logic? → Create Service
- Complex state? → Create ViewModel
- Where in UI? → Choose Forms/Sections/Sheets

**2. Create files in order:**
```
If persistent:
  1. Models/SwiftData/[Name].swift (database model)
  2. Models/POCOs/[Name]POCO.swift (UI model)
  3. Update PodcastLibraryStore with conversion methods

If service needed:
  4. Services/[Category]/[Name]Service.swift

If complex state:
  5. ViewModels/[Name]ViewModel.swift

Finally:
  6. Views/[Category]/[Name]View.swift
```

**3. Wire it up:**
- Add to PersistenceController schema (if SwiftData)
- Add to PodcastLibraryStore (if persistent)
- Inject store via `.environmentObject()` in ContentView
- Create menu/toolbar buttons for access

**4. Test:**
- Unit tests in `Tests/PodcastAssistantFeatureTests/`
- Manual testing with build & run

## Common Patterns

### Pattern 1: New Persistent Entity

```
1. Create Models/SwiftData/MyEntity.swift
2. Create Models/POCOs/MyEntityPOCO.swift
3. Add to PersistenceController.schema
4. Add conversion methods to PodcastLibraryStore
5. Add CRUD methods to PodcastLibraryStore
6. Create ViewModels/MyEntityViewModel.swift
7. Create Views/[Category]/MyEntityView.swift
```

### Pattern 2: New Utility Feature (No Persistence)

```
1. Create Services/Utilities/MyUtility.swift
2. Create ViewModels/MyFeatureViewModel.swift (if needed)
3. Create Views/Sections/MyFeatureView.swift
4. Add to EpisodeDetailView tabs (if detail pane)
```

### Pattern 3: New Form

```
1. Determine what POCO it edits
2. Create Views/Forms/MyEntityFormView.swift
3. Follow local copy editing pattern
4. Add button to open sheet in parent view
```

## Dependencies Between Layers

### Allowed Dependencies
```
Views → ViewModels → Services → Models
  ↓         ↓           ↓
  └─────────┴───────────┴────→ POCOs only

Views can also → Services (for simple utilities)
```

### Forbidden Dependencies
```
❌ Models → Services
❌ Models → ViewModels  
❌ Models → Views
❌ Services → ViewModels
❌ Services → Views
❌ Views → SwiftData models (use POCOs instead)
```

## Public API Requirements

**Critical:** All types in `PodcastAssistantFeature` must be `public` because they're in a Swift Package:

```swift
public final class MyClass { ... }
public struct MyStruct { ... }
public enum MyEnum { ... }

// Especially initializers!
public init(...) { ... }

// And properties!
@Published public var myProperty: String
```

## Build Organization (Xcode)

**Important:** Xcode shows files in **Buildable Folders**, not actual filesystem folders.

**To add a file:**
1. Create in correct filesystem location
2. Xcode auto-detects it (may need to close/reopen Xcode)
3. No need to add to Xcode project manually

**Benefits:**
- Filesystem is source of truth
- No project file conflicts
- Easy to navigate with terminal/editor
- Clean git diffs

## Summary

### Quick Reference

**I need to...**
- Store data in database → `Models/SwiftData/`
- Create UI-facing data → `Models/POCOs/`
- Add business logic → `Services/[Data|UI|Utilities]/`
- Manage view state → `ViewModels/`
- Create a form → `Views/Forms/`
- Add a detail tab → `Views/Sections/`
- Build a popup → `Views/Sheets/`

### Principles

✅ **Do:**
- Group by function (Forms, Sections, Sheets)
- Separate concerns (Models, Services, ViewModels, Views)
- Use clear, descriptive names
- Follow existing patterns
- Keep related files together

❌ **Don't:**
- Mix UI and business logic
- Put everything in root folder
- Use generic names like "Helper" or "Utils" without context
- Create deep nesting (3 levels max)
- Skip the ViewModel layer for complex views

This structure keeps the codebase organized, maintainable, and scalable as new features are added.
