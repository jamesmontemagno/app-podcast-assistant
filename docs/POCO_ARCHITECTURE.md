# POCO Architecture - Hybrid Persistence Pattern

## Overview

Podcast Assistant uses a **hybrid POCO (Plain Old Class Object) architecture** that combines the benefits of SwiftData persistence with the performance and flexibility of simple class objects. This pattern provides database-backed storage while maintaining fast UI performance and clean separation of concerns.

## Architecture Pattern

### The Hybrid Model

```
┌─────────────────────────────────────────────────────────┐
│                     User Interface                       │
│                  (SwiftUI Views)                         │
└───────────────────────────┬─────────────────────────────┘
                            │
                            │ Binds to POCOs
                            ▼
┌─────────────────────────────────────────────────────────┐
│              PodcastLibraryStore                         │
│           (@Published POCO Arrays)                       │
│   - podcasts: [PodcastPOCO]                             │
│   - episodes: [String: [EpisodePOCO]]                   │
└───────────────────────────┬─────────────────────────────┘
                            │
                            │ Reads/Writes
                            ▼
┌─────────────────────────────────────────────────────────┐
│              SwiftData Persistence Layer                 │
│   - ModelContext with @Model classes                    │
│   - Podcast (SwiftData model)                           │
│   - Episode (SwiftData model)                           │
└─────────────────────────────────────────────────────────┘
                            │
                            │ Persists to
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  SQLite Database                         │
│      ~/Library/Application Support/...                  │
└─────────────────────────────────────────────────────────┘
```

### Why This Pattern?

**Benefits over Pure SwiftData:**
- ✅ **No SwiftData quirks in UI** - No `@Query` dependencies, no faulting issues
- ✅ **Fast UI performance** - Simple class objects are faster to render
- ✅ **Better testability** - POCOs can be created without ModelContext
- ✅ **Predictable updates** - Standard `@Published` behavior, no surprises
- ✅ **Easier debugging** - Simple objects, no Core Data/SwiftData internals

**Benefits over Pure POCOs:**
- ✅ **Automatic persistence** - Data survives app restarts
- ✅ **CloudKit-ready** - SwiftData layer can sync to iCloud when enabled
- ✅ **Relationships** - SwiftData handles episode-to-podcast relationships
- ✅ **Migration support** - SwiftData handles schema changes

## Core Components

### 1. POCO Classes

#### PodcastPOCO
**Location:** `Models/POCOs/PodcastPOCO.swift`

Simple class holding podcast data:
```swift
public final class PodcastPOCO: Identifiable, Hashable {
    public let id: String
    public var name: String
    public var podcastDescription: String?
    public var artworkData: Data?
    public var defaultOverlayData: Data?
    // ... all podcast properties
    
    public init(...) { ... }
    
    // Hashable, Equatable for SwiftUI
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: PodcastPOCO, rhs: PodcastPOCO) -> Bool {
        lhs.id == rhs.id
    }
}
```

**Key Features:**
- `final class` for performance (no dynamic dispatch)
- `Identifiable` for SwiftUI `List` and `ForEach`
- `Hashable` for selection binding
- All properties mutable for editing
- Default values for thumbnail settings

#### EpisodePOCO
**Location:** `Models/POCOs/EpisodePOCO.swift`

Simple class holding episode data:
```swift
public final class EpisodePOCO: Identifiable, Hashable {
    public let id: String
    public let podcastID: String  // Store parent ID, not reference
    public var title: String
    public var episodeNumber: Int32
    public var episodeDescription: String?
    public var transcriptInputText: String?
    public var srtOutputText: String?
    // ... all episode properties
    
    // Computed flags
    public var hasTranscriptData: Bool {
        transcriptInputText?.isEmpty == false
    }
    
    public var hasThumbnailOutput: Bool {
        thumbnailOutputData != nil
    }
    
    public init(...) {
        // Copy defaults from parent podcast if provided
        if let podcast = podcast {
            self.fontName = fontName ?? podcast.defaultFontName
            self.fontSize = fontSize ?? podcast.defaultFontSize
            // ...
        }
    }
}
```

**Key Features:**
- Stores `podcastID` instead of weak reference (no retain cycles)
- Auto-copies defaults from parent podcast on creation
- Computed properties for UI indicators
- All SwiftData properties mirrored as simple types

### 2. PodcastLibraryStore

**Location:** `Services/Data/PodcastLibraryStore.swift`

The central hub managing the hybrid pattern:

```swift
@MainActor
public final class PodcastLibraryStore: ObservableObject {
    // POCO arrays for UI binding
    @Published public private(set) var podcasts: [PodcastPOCO] = []
    @Published public private(set) var episodes: [String: [EpisodePOCO]] = [:]
    
    // SwiftData context for persistence
    private var context: ModelContext?
    
    public init() {}
    
    // Load initial data from SwiftData → POCOs
    public func loadInitialData(context: ModelContext) throws {
        self.context = context
        try refreshPodcasts()
    }
    
    // Refresh podcasts from SwiftData
    public func refreshPodcasts() throws -> [PodcastPOCO] {
        let fetched = try context.fetch(FetchDescriptor<Podcast>(...))
        podcasts = fetched.map { convertToPOCO(podcast: $0) }
        return podcasts
    }
    
    // Add podcast: Create SwiftData model, save, update POCO list
    public func addPodcast(_ poco: PodcastPOCO) throws {
        let podcast = Podcast(...)
        context.insert(podcast)
        try context.save()
        podcasts.append(poco)
    }
    
    // Update podcast: Update SwiftData model, save, update POCO
    public func updatePodcast(_ poco: PodcastPOCO) throws {
        guard let podcast = try fetchPodcastModel(withID: poco.id) else { return }
        podcast.name = poco.name
        // ... update all properties
        try context.save()
        podcasts[index] = poco
    }
    
    // Delete podcast: Delete SwiftData model, remove from POCO list
    public func deletePodcast(_ poco: PodcastPOCO) throws {
        guard let podcast = try fetchPodcastModel(withID: poco.id) else { return }
        context.delete(podcast)
        try context.save()
        podcasts.removeAll { $0.id == poco.id }
    }
}
```

**Key Responsibilities:**
- **CRUD Operations**: Create, Read, Update, Delete for podcasts and episodes
- **Synchronization**: Keeps POCOs in sync with SwiftData models
- **Data Conversion**: Converts between SwiftData models and POCOs
- **UI Updates**: Publishes POCO array changes via `@Published`

### 3. SwiftData Models (Persistence Layer)

**Location:** `Models/SwiftData/`

Standard SwiftData models for database persistence:

```swift
@Model
public final class Podcast {
    @Attribute(.unique) public var id: String
    public var name: String
    public var podcastDescription: String?
    @Attribute(.externalStorage) public var artworkData: Data?
    
    @Relationship(deleteRule: .cascade, inverse: \Episode.podcast)
    public var episodes: [Episode] = []
    
    // ... all properties match PodcastPOCO
    
    public init(...) { ... }
}

@Model
public final class Episode {
    @Attribute(.unique) public var id: String
    public var title: String
    public var episodeNumber: Int32
    
    public var podcast: Podcast?
    
    // ... all properties match EpisodePOCO
    
    public init(...) { ... }
}
```

**Key Features:**
- `@Model` macro for SwiftData persistence
- `@Attribute(.unique)` on `id` for CloudKit compatibility
- `@Relationship` with cascade delete (deleting podcast deletes episodes)
- Properties mirror POCO structure exactly

## Data Flow

### Read Flow (Startup)

```
App Launch
    ↓
ContentView.onAppear()
    ↓
store.loadInitialData(context: modelContext)
    ↓
PodcastLibraryStore.refreshPodcasts()
    ↓
Fetch SwiftData models from database
    ↓
Convert to POCOs: podcasts = fetched.map { convertToPOCO($0) }
    ↓
@Published triggers UI update
    ↓
SwiftUI renders podcast list
```

### Write Flow (User Edit)

```
User edits podcast in form
    ↓
PodcastFormView updates local PodcastPOCO
    ↓
User clicks "Save"
    ↓
store.updatePodcast(poco)
    ↓
Find SwiftData model by ID
    ↓
Update SwiftData model properties from POCO
    ↓
context.save() → persist to database
    ↓
Update POCO in store.podcasts array
    ↓
@Published triggers UI refresh
```

### Episode Loading (Lazy)

```
User selects podcast
    ↓
store.refreshEpisodes(for: podcastID)
    ↓
Fetch SwiftData episodes for podcast
    ↓
Convert to POCOs: episodes[podcastID] = fetched.map { convertToPOCO($0) }
    ↓
@Published triggers UI update
    ↓
Episode list appears
```

## Conversion Methods

### SwiftData → POCO

```swift
private func convertToPOCO(podcast: Podcast) -> PodcastPOCO {
    PodcastPOCO(
        id: podcast.id,
        name: podcast.name,
        podcastDescription: podcast.podcastDescription,
        artworkData: podcast.artworkData,
        // ... all properties
        createdAt: podcast.createdAt
    )
}

private func convertToPOCO(episode: Episode) -> EpisodePOCO {
    EpisodePOCO(
        id: episode.id,
        podcastID: episode.podcast?.id ?? "",
        title: episode.title,
        episodeNumber: episode.episodeNumber,
        // ... all properties
    )
}
```

### POCO → SwiftData (Create)

```swift
public func addPodcast(_ poco: PodcastPOCO) throws {
    let podcast = Podcast(
        name: poco.name,
        podcastDescription: poco.podcastDescription,
        // ... all properties
    )
    podcast.id = poco.id
    podcast.createdAt = poco.createdAt
    
    context.insert(podcast)
    try context.save()
    
    podcasts.append(poco)
}
```

### POCO → SwiftData (Update)

```swift
public func updatePodcast(_ poco: PodcastPOCO) throws {
    guard let podcast = try fetchPodcastModel(withID: poco.id) else {
        throw StoreError.podcastNotFound
    }
    
    // Update all properties
    podcast.name = poco.name
    podcast.podcastDescription = poco.podcastDescription
    // ...
    
    try context.save()
    
    // Update POCO in array (triggers @Published)
    if let index = podcasts.firstIndex(where: { $0.id == poco.id }) {
        podcasts[index] = poco
    }
}
```

## ViewModels with POCOs

### Pattern: ViewModel Owns POCO Reference

```swift
@MainActor
public final class ThumbnailViewModel: ObservableObject {
    @Published public var episode: EpisodePOCO
    private let store: PodcastLibraryStore
    
    public init(episode: EpisodePOCO, store: PodcastLibraryStore) {
        self.episode = episode
        self.store = store
    }
    
    // Computed properties read from POCO
    public var backgroundImage: NSImage? {
        get {
            guard let data = episode.thumbnailBackgroundData else { return nil }
            return ImageUtilities.loadImage(from: data)
        }
        set {
            if let image = newValue {
                episode.thumbnailBackgroundData = ImageUtilities.processImageForStorage(image)
            } else {
                episode.thumbnailBackgroundData = nil
            }
            saveChanges()
        }
    }
    
    // Save changes to store (persists to SwiftData)
    private func saveChanges() {
        do {
            try store.updateEpisode(episode)
            objectWillChange.send()
        } catch {
            print("Error saving: \(error)")
        }
    }
}
```

**Benefits:**
- ViewModel owns a POCO reference (not SwiftData model)
- No `ModelContext` needed in ViewModel
- Simple property updates trigger `objectWillChange`
- Store handles persistence transparently

### Pattern: View Creates ViewModel

```swift
struct ThumbnailView: View {
    let episode: EpisodePOCO
    @EnvironmentObject var store: PodcastLibraryStore
    @StateObject private var viewModel: ThumbnailViewModel
    
    init(episode: EpisodePOCO) {
        self.episode = episode
        // Can't access @EnvironmentObject in init, use workaround
        _viewModel = StateObject(wrappedValue: ThumbnailViewModel(
            episode: episode,
            store: PodcastLibraryStore() // Temporary, replaced by .environmentObject
        ))
    }
    
    var body: some View {
        // ... UI that binds to viewModel properties
    }
    .onAppear {
        // Update viewModel with real store from environment
        viewModel.setStore(store)
    }
}
```

**Note:** Some views use two-part initialization pattern to inject environment dependencies.

## Forms and Sheets Pattern

### Editing Workflow

```swift
struct PodcastFormView: View {
    @Binding var podcast: PodcastPOCO
    @EnvironmentObject var store: PodcastLibraryStore
    @Environment(\.dismiss) var dismiss
    
    @State private var localCopy: PodcastPOCO
    
    init(podcast: Binding<PodcastPOCO>) {
        _podcast = podcast
        _localCopy = State(initialValue: podcast.wrappedValue)
    }
    
    var body: some View {
        Form {
            // Edit localCopy
            TextField("Name", text: $localCopy.name)
            TextEditor(text: $localCopy.podcastDescription)
            // ...
        }
        .toolbar {
            Button("Cancel") { dismiss() }
            Button("Save") {
                podcast = localCopy  // Update binding
                try? store.updatePodcast(localCopy)  // Persist
                dismiss()
            }
        }
    }
}
```

**Pattern:**
1. Accept POCO via `@Binding`
2. Create local copy via `@State`
3. Edit local copy in form
4. On save: Update binding + persist to store
5. On cancel: Discard local copy

## Testing with POCOs

### Benefits for Testing

POCOs make testing much easier:

```swift
import Testing
@testable import PodcastAssistantFeature

@Test func testPodcastCreation() {
    let podcast = PodcastPOCO(
        name: "Test Podcast",
        podcastDescription: "Description"
    )
    
    #expect(podcast.name == "Test Podcast")
    #expect(podcast.defaultFontSize == 72.0)
}

@Test func testEpisodeDefaultsCopy() {
    let podcast = PodcastPOCO(
        name: "Test",
        defaultFontSize: 100.0,
        defaultFontName: "Impact"
    )
    
    let episode = EpisodePOCO(
        podcastID: podcast.id,
        title: "Episode 1",
        episodeNumber: 1,
        podcast: podcast
    )
    
    #expect(episode.fontSize == 100.0)
    #expect(episode.fontName == "Impact")
}
```

**No ModelContext required** - POCOs are simple classes!

## Memory Management

### Avoiding Retain Cycles

**POCOs use `podcastID` instead of references:**

```swift
// ❌ Bad: Retain cycle risk
public weak var podcast: PodcastPOCO?

// ✅ Good: No reference, just ID
public let podcastID: String
```

To get parent podcast:
```swift
let podcast = store.podcasts.first { $0.id == episode.podcastID }
```

### Object Lifetime

- **POCOs**: Owned by `PodcastLibraryStore`, live in memory
- **SwiftData models**: Managed by `ModelContext`, may fault/unload
- **ViewModels**: Own POCO references, not SwiftData models

## Performance Considerations

### Why POCOs Are Faster

1. **No faulting** - POCOs are always fully loaded
2. **No relationship traversal** - Just ID lookups
3. **Predictable updates** - Standard `@Published` behavior
4. **Simpler diffing** - SwiftUI diffing is faster on simple objects

### Memory vs. Database Trade-off

**Trade-off:**
- POCOs use more memory (all data loaded)
- SwiftData can fault objects (load on-demand)

**Mitigation:**
- Episode lists are lazy-loaded per podcast
- Only visible podcast's episodes are in memory
- Images stored as Data (efficient for small/medium sizes)

**For very large libraries (1000+ episodes):**
- Consider pagination/virtual scrolling
- Unload episodes when switching podcasts
- Future: Implement POCO caching/eviction

## Integration Points

### ContentView (App Entry)

```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var store = PodcastLibraryStore()
    
    var body: some View {
        NavigationSplitView {
            PodcastListView(podcasts: store.podcasts)
        } content: {
            EpisodeListView(episodes: store.episodes[selectedPodcastID] ?? [])
        } detail: {
            if let episode = selectedEpisode {
                EpisodeDetailView(episode: episode)
            }
        }
        .environmentObject(store)
        .onAppear {
            try? store.loadInitialData(context: modelContext)
        }
    }
}
```

**Key Points:**
- Store is `@StateObject` (created once)
- Store is injected via `.environmentObject()`
- ModelContext from environment passed to store
- Store loads data on appear

### SwiftData Schema

PersistenceController includes both models:

```swift
public static let schema = Schema([
    Podcast.self,
    Episode.self,
    AppSettings.self
])
```

## Best Practices

### ✅ Do

1. **Always use POCOs in Views/ViewModels** - Never pass SwiftData models to UI
2. **Update through store** - Always call `store.updatePodcast()` / `store.updateEpisode()`
3. **Keep POCOs in sync** - Every SwiftData change must update corresponding POCO
4. **Use IDs for references** - Store `podcastID` in episodes, not references
5. **Test with POCOs** - Unit tests don't need ModelContext

### ❌ Don't

1. **Don't pass SwiftData models to views** - Use POCOs instead
2. **Don't update POCOs without saving** - Changes will be lost
3. **Don't create circular references** - Use IDs, not object references
4. **Don't fetch SwiftData models in views** - Let store handle fetching
5. **Don't mix patterns** - Stick to POCO pattern throughout

## Future Enhancements

### Potential Improvements

1. **POCO Caching** - Evict unused episode POCOs to save memory
2. **Incremental Loading** - Paginate large episode lists
3. **Background Sync** - Sync SwiftData changes on background queue
4. **Undo/Redo** - Implement command pattern for edits
5. **CloudKit Sync** - Enable iCloud sync at SwiftData layer (POCOs unchanged)
6. **Optimistic Updates** - Update UI immediately, persist async
7. **Change Tracking** - Track dirty POCOs to batch saves

### CloudKit Integration

When CloudKit is enabled:
- POCOs remain unchanged
- SwiftData layer handles sync automatically
- Store continues to work the same way
- UI benefits from automatic sync

See `PersistenceController.swift` for CloudKit setup instructions.

## Summary

The POCO architecture provides:
- ✅ **Fast UI performance** - Simple objects, no SwiftData overhead
- ✅ **Reliable persistence** - SwiftData handles database operations
- ✅ **Clean separation** - UI layer independent of persistence layer
- ✅ **Testability** - POCOs can be tested without database
- ✅ **Maintainability** - Clear data flow, predictable updates
- ✅ **CloudKit-ready** - Enable sync without changing UI code

This hybrid pattern is the foundation of Podcast Assistant's architecture.
