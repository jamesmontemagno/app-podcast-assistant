# Pure SwiftData Architecture with @Query

## Overview

Podcast Assistant uses **pure SwiftData with @Query reactive binding** for a clean, Apple-recommended approach to data management. This pattern eliminates intermediate layers, reduces code complexity, and leverages SwiftData's reactive features for automatic UI updates.

## Architecture Pattern

### The Direct Binding Model

```
┌─────────────────────────────────────────────────────────┐
│                     User Interface                       │
│         (SwiftUI Views with @Query)                      │
└───────────────────────────┬─────────────────────────────┘
                            │
                            │ Direct binding via @Query
                            ▼
┌─────────────────────────────────────────────────────────┐
│              SwiftData Persistence Layer                 │
│   - @Query(sort: \.createdAt) var podcasts              │
│   - Dynamic predicates for filtering                     │
│   - @Model classes (Podcast, Episode)                   │
└───────────────────────────┬─────────────────────────────┘
                            │
                            │ Persists to
                            ▼
┌─────────────────────────────────────────────────────────┐
│                  SQLite Database                         │
│      ~/Library/Application Support/...                  │
└─────────────────────────────────────────────────────────┘
```

### Why This Pattern?

**Benefits over POCO Hybrid:**
- ✅ **Simpler codebase** - No intermediate POCO classes or bridge layer
- ✅ **Less code** - Eliminated ~1500 lines of POCO/store boilerplate
- ✅ **Reactive by default** - @Query automatically updates views
- ✅ **Apple's recommended approach** - Following SwiftData best practices
- ✅ **Fewer bugs** - No synchronization issues between layers
- ✅ **Better performance** - External storage + selective loading = fast UI

**What We Learned:**
- SwiftData @Query works reliably when used correctly
- `.tag()` modifiers are essential for List selection
- External storage prevents loading large blobs unnecessarily
- Creating new Views with @Query is the right pattern

## Core Components

### 1. SwiftData Models

**Location:** `Models/SwiftData/`

#### Podcast Model
```swift
@Model
public final class Podcast {
    @Attribute(.unique) public var id: String
    public var name: String
    public var podcastDescription: String?
    
    // External storage for large data
    @Attribute(.externalStorage) public var artworkData: Data?
    @Attribute(.externalStorage) public var defaultOverlayData: Data?
    
    // Cascade delete relationship
    @Relationship(deleteRule: .cascade, inverse: \Episode.podcast)
    public var episodes: [Episode] = []
    
    // Timestamps
    public var createdAt: Date
    public var updatedAt: Date
    
    // Thumbnail defaults
    public var defaultFontSize: Double = 72.0
    public var defaultFontName: String = "Helvetica-Bold"
    // ... more defaults
    
    public init(name: String, ...) {
        self.id = UUID().uuidString
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        // ...
    }
}

// Hashable conformance for List selection
extension Podcast: Hashable {
    public static func == (lhs: Podcast, rhs: Podcast) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

#### Episode Model (with External Storage)
```swift
@Model
public final class Episode {
    @Attribute(.unique) public var id: String
    public var title: String
    public var episodeNumber: Int32
    public var episodeDescription: String?
    
    // Parent relationship
    public var podcast: Podcast?
    
    // Heavy content in separate model (external storage)
    @Relationship(deleteRule: .cascade) public var content: EpisodeContent?
    
    // Lightweight properties (always loaded)
    public var fontSize: Double = 72.0
    public var fontName: String = "Helvetica-Bold"
    public var fontColorHex: String?
    
    // Timestamps
    public var createdAt: Date
    public var publishDate: Date
    
    public init(title: String, episodeNumber: Int32, podcast: Podcast?) {
        self.id = UUID().uuidString
        self.title = title
        self.episodeNumber = episodeNumber
        self.podcast = podcast
        self.createdAt = Date()
        self.publishDate = Date()
    }
    
    // Convenience accessors for heavy content (lazy loading)
    public var transcriptInputText: String? {
        get { content?.transcriptInputText }
        set {
            if content == nil {
                content = EpisodeContent()
            }
            content?.transcriptInputText = newValue
        }
    }
    
    public var thumbnailBackgroundData: Data? {
        get { content?.thumbnailBackgroundData }
        set {
            if content == nil {
                content = EpisodeContent()
            }
            content?.thumbnailBackgroundData = newValue
        }
    }
    
    // Computed flag (no heavy data access)
    public var hasTranscriptData: Bool {
        content?.transcriptInputText?.isEmpty == false
    }
}

extension Episode: Hashable {
    public static func == (lhs: Episode, rhs: Episode) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

#### EpisodeContent Model (Heavy Data)
```swift
@Model
public final class EpisodeContent {
    // All heavy BLOBs use external storage
    @Attribute(.externalStorage) public var transcriptInputText: String?
    @Attribute(.externalStorage) public var srtOutputText: String?
    @Attribute(.externalStorage) public var thumbnailBackgroundData: Data?
    @Attribute(.externalStorage) public var thumbnailOverlayData: Data?
    @Attribute(.externalStorage) public var thumbnailOutputData: Data?
    
    // Inverse relationship to episode
    public var episode: Episode?
    
    public init() {}
}
```

**Key Design:**
- **Separate lightweight (Episode) from heavy (EpisodeContent) data**
- **External storage** prevents loading large blobs into memory
- **Convenience accessors** on Episode for easy property access
- **Lazy loading** - EpisodeContent only loaded when accessed

### 2. @Query in Views

#### ContentView (Main Navigation)
```swift
public struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    
    // Direct @Query binding - reactive updates!
    @Query(sort: \Podcast.createdAt, order: .reverse)
    private var podcasts: [Podcast]
    
    @State private var selectedPodcast: Podcast?
    @State private var selectedEpisode: Episode?
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar: Podcast list
            if podcasts.isEmpty {
                ContentUnavailableView(
                    "No Podcasts",
                    systemImage: "mic.slash",
                    description: Text("Create your first podcast to get started")
                )
            } else {
                List(podcasts, selection: $selectedPodcast) { podcast in
                    PodcastRow(podcast: podcast)
                        .tag(podcast)  // CRITICAL for selection!
                        .contextMenu {
                            Button("Edit") { editingPodcast = podcast }
                            Button("Delete", role: .destructive) {
                                deletePodcast(podcast)
                            }
                        }
                }
                .listStyle(.sidebar)
            }
        } content: {
            // Middle: Episode list (dynamic query)
            if let podcast = selectedPodcast {
                EpisodeListView(
                    podcast: podcast,
                    selectedEpisode: $selectedEpisode
                )
            } else {
                ContentUnavailableView(
                    "Select a Podcast",
                    systemImage: "sidebar.left",
                    description: Text("Choose a podcast from the sidebar")
                )
            }
        } detail: {
            // Detail: Episode editor
            if let episode = selectedEpisode, let podcast = selectedPodcast {
                EpisodeDetailView(
                    episode: episode,
                    podcast: podcast,
                    selectedSection: $selectedSection
                )
            } else {
                ContentUnavailableView(
                    "Select an Episode",
                    systemImage: "music.note.list",
                    description: Text("Choose an episode to edit")
                )
            }
        }
    }
    
    private func deletePodcast(_ podcast: Podcast) {
        modelContext.delete(podcast)  // Cascades to episodes!
        try? modelContext.save()
        
        if selectedPodcast?.id == podcast.id {
            selectedPodcast = nil
        }
    }
}
```

**Key Points:**
- `@Query` directly in view - no intermediate layer
- `.tag(podcast)` required for List selection binding
- Delete via `modelContext.delete()` - automatic UI update
- Cascade delete handled by SwiftData relationship

#### EpisodeListView (Dynamic @Query)
```swift
public struct EpisodeListView: View {
    let podcast: Podcast
    @Binding var selectedEpisode: Episode?
    
    @Environment(\.modelContext) private var modelContext
    
    // Dynamic @Query filtered by podcast.id
    @Query private var episodes: [Episode]
    
    @State private var searchText: String = ""
    @State private var sortOption: EpisodeSortOption = .newestFirst
    
    public init(podcast: Podcast, selectedEpisode: Binding<Episode?>) {
        self.podcast = podcast
        self._selectedEpisode = selectedEpisode
        
        // Dynamic predicate based on podcast
        let podcastID = podcast.id
        let predicate = #Predicate<Episode> { episode in
            episode.podcast?.id == podcastID
        }
        
        // Dynamic sort based on state
        let sort = [SortDescriptor(\Episode.createdAt, order: .reverse)]
        
        _episodes = Query(filter: predicate, sort: sort)
    }
    
    private var filteredEpisodes: [Episode] {
        if searchText.isEmpty {
            return sortedEpisodes
        }
        return sortedEpisodes.filter { episode in
            episode.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var sortedEpisodes: [Episode] {
        switch sortOption {
        case .newestFirst:
            return episodes.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst:
            return episodes.sorted { $0.createdAt < $1.createdAt }
        case .episodeNumber:
            return episodes.sorted { $0.episodeNumber < $1.episodeNumber }
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search episodes...", text: $searchText)
            }
            .padding()
            
            // Episode list
            List(filteredEpisodes, selection: $selectedEpisode) { episode in
                EpisodeRow(episode: episode)
                    .tag(episode)  // CRITICAL!
                    .contextMenu {
                        Button("Edit") { editingEpisode = episode }
                        Button("Delete", role: .destructive) {
                            deleteEpisode(episode)
                        }
                    }
            }
        }
    }
    
    private func deleteEpisode(_ episode: Episode) {
        modelContext.delete(episode)
        try? modelContext.save()
        
        if selectedEpisode?.id == episode.id {
            selectedEpisode = nil
        }
    }
}
```

**Key Features:**
- Dynamic `#Predicate` filters by podcast ID
- Search/sort computed in view (lightweight)
- `.tag(episode)` for selection binding
- Delete triggers automatic UI refresh

### 3. Forms with ModelContext

#### PodcastFormView (Create/Edit)
```swift
public struct PodcastFormView: View {
    let podcast: Podcast?  // nil = create, non-nil = edit
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var artworkData: Data?
    
    public init(podcast: Podcast? = nil) {
        self.podcast = podcast
        
        // Pre-populate for editing
        if let podcast = podcast {
            _name = State(initialValue: podcast.name)
            _description = State(initialValue: podcast.podcastDescription ?? "")
            _artworkData = State(initialValue: podcast.artworkData)
        }
    }
    
    public var body: some View {
        Form {
            TextField("Podcast Name", text: $name)
            TextEditor(text: $description)
            // Image picker for artworkData
        }
        .toolbar {
            Button("Cancel") { dismiss() }
            Button("Save") { save() }
                .disabled(name.isEmpty)
        }
    }
    
    private func save() {
        if let podcast = podcast {
            // Update existing
            podcast.name = name
            podcast.podcastDescription = description
            podcast.artworkData = artworkData
            podcast.updatedAt = Date()
        } else {
            // Create new
            let newPodcast = Podcast(
                name: name,
                podcastDescription: description.isEmpty ? nil : description
            )
            newPodcast.artworkData = artworkData
            modelContext.insert(newPodcast)
        }
        
        try? modelContext.save()
        dismiss()
    }
}
```

**Pattern:**
- Accept optional model (nil = create mode)
- Use `@State` for local editing
- Update model properties directly
- Call `modelContext.save()` - UI updates automatically

### 4. ViewModels with ModelContext

#### ThumbnailViewModel (Direct Model Access)
```swift
@MainActor
public class ThumbnailViewModel: ObservableObject {
    @Published public var episode: Episode  // Direct reference!
    
    private let modelContext: ModelContext
    
    @Published public var backgroundImage: NSImage?
    @Published public var generatedThumbnail: NSImage?
    
    public init(episode: Episode, modelContext: ModelContext) {
        self.episode = episode
        self.modelContext = modelContext
    }
    
    public func loadInitialData() {
        // Load background from episode.content (lazy)
        if let data = episode.thumbnailBackgroundData {
            backgroundImage = ImageUtilities.loadImage(from: data)
        }
    }
    
    public func saveToEpisode() {
        guard let thumbnail = generatedThumbnail else { return }
        
        // Save to episode (creates EpisodeContent if needed)
        episode.thumbnailOutputData = ImageUtilities.processImageForStorage(thumbnail)
        episode.fontSize = fontSize
        episode.fontName = selectedFont
        
        // Persist
        do {
            try modelContext.save()
            successMessage = "Thumbnail saved"
        } catch {
            errorMessage = "Failed to save: \(error)"
        }
    }
}
```

**Pattern:**
- Accept Episode model + ModelContext
- Update episode properties directly
- Call `modelContext.save()` to persist
- No intermediate layer needed

## Data Flow

### Startup Flow
```
App Launch
    ↓
ContentView appears
    ↓
@Query executes FetchDescriptor<Podcast>
    ↓
SwiftData fetches from database
    ↓
@Query publishes results to view
    ↓
SwiftUI renders podcast list
```

### User Edit Flow
```
User edits podcast name
    ↓
TextField updates @State variable
    ↓
User clicks "Save"
    ↓
Form updates podcast.name directly
    ↓
modelContext.save()
    ↓
SwiftData persists to database
    ↓
@Query detects change (automatic!)
    ↓
SwiftUI re-renders with new data
```

### Delete Flow
```
User deletes podcast
    ↓
modelContext.delete(podcast)
    ↓
modelContext.save()
    ↓
SwiftData removes from database
    ↓
Cascade delete removes episodes
    ↓
@Query detects change
    ↓
UI updates (podcast removed from list)
```

## Performance Optimization

### External Storage Pattern

**Problem:** Loading all episode data into memory is slow

**Solution:** Separate heavy content into `EpisodeContent` with `.externalStorage`

```swift
// Episode (lightweight - always loaded)
@Model
public final class Episode {
    public var title: String
    public var episodeNumber: Int32
    
    // Relationship to heavy content
    @Relationship(deleteRule: .cascade)
    public var content: EpisodeContent?
    
    // Convenience accessor (lazy loads content)
    public var transcriptInputText: String? {
        get { content?.transcriptInputText }
        set {
            if content == nil {
                content = EpisodeContent()
            }
            content?.transcriptInputText = newValue
        }
    }
}

// EpisodeContent (heavy - loaded on demand)
@Model
public final class EpisodeContent {
    @Attribute(.externalStorage)
    public var transcriptInputText: String?  // 50KB+ transcript
    
    @Attribute(.externalStorage)
    public var thumbnailBackgroundData: Data?  // 200KB image
}
```

**Benefits:**
- Episode list queries only load lightweight properties
- Heavy blobs loaded when actually accessed
- Dramatic memory reduction
- Faster UI rendering

### List Selection Best Practices

**Critical:** Always use `.tag()` for selection binding!

```swift
List(podcasts, selection: $selectedPodcast) { podcast in
    PodcastRow(podcast: podcast)
        .tag(podcast)  // ← REQUIRED!
}
```

**Why:**
- SwiftUI needs to know which value to bind
- Without `.tag()`, selection won't work
- Models must be `Hashable` for tag comparison

## Testing with SwiftData

### In-Memory Testing

```swift
@Test func testPodcastCreation() throws {
    // Create in-memory ModelContainer
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Podcast.self, Episode.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    // Create podcast
    let podcast = Podcast(name: "Test Podcast")
    context.insert(podcast)
    try context.save()
    
    // Fetch and verify
    let descriptor = FetchDescriptor<Podcast>()
    let podcasts = try context.fetch(descriptor)
    
    #expect(podcasts.count == 1)
    #expect(podcasts[0].name == "Test Podcast")
}
```

**Benefits:**
- Real SwiftData behavior in tests
- No mocking needed
- In-memory = fast + isolated

## Migration from POCO

### What Changed

**Removed:**
- ❌ `PodcastPOCO.swift` (~300 lines)
- ❌ `EpisodePOCO.swift` (~400 lines)
- ❌ `PodcastLibraryStore.swift` (~800 lines)
- ❌ All conversion methods
- ❌ Synchronization logic

**Added:**
- ✅ `EpisodeContent.swift` (external storage model)
- ✅ `.tag()` modifiers on List rows
- ✅ `Hashable` conformance on models
- ✅ Convenience accessors for lazy loading

**Net Result:** ~1500 lines of code removed! 🎉

### Before (POCO)
```swift
struct ContentView: View {
    @StateObject private var store = PodcastLibraryStore()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List(store.podcasts) { podcast in
            PodcastRow(podcast: podcast)
        }
        .onAppear {
            try? store.loadInitialData(context: modelContext)
        }
    }
}
```

### After (@Query)
```swift
struct ContentView: View {
    @Query private var podcasts: [Podcast]
    
    var body: some View {
        List(podcasts) { podcast in
            PodcastRow(podcast: podcast)
                .tag(podcast)
        }
    }
}
```

**Simpler, cleaner, reactive! ✨**

## Best Practices

### ✅ Do

1. **Use @Query in views** - Direct binding to SwiftData models
2. **Add .tag() to List rows** - Required for selection binding
3. **Make models Hashable** - Required for .tag() comparison
4. **Use external storage** - For large Data/String properties
5. **Split heavy content** - Separate model for blobs (EpisodeContent pattern)
6. **Create new Views** - When in doubt, new View with @Query (friend's advice!)
7. **Update models directly** - No intermediate layer needed
8. **Use modelContext.save()** - Explicit persistence points

### ❌ Don't

1. **Don't create intermediate POCOs** - Use SwiftData models directly
2. **Don't forget .tag()** - Selection won't work without it
3. **Don't load heavy data unnecessarily** - Use external storage
4. **Don't fight @Query** - Trust reactive updates
5. **Don't over-complicate** - Keep it simple and direct

## Lessons Learned

### What We Discovered

1. **@Query works reliably** - When you follow the patterns correctly
2. **.tag() is critical** - Selection requires explicit tagging
3. **External storage is powerful** - Prevents loading heavy blobs
4. **SwiftData is fast** - With proper schema design
5. **Less code is better** - Removing layers improved clarity

### Common Pitfalls (Solved)

❌ **Problem:** List selection not working  
✅ **Solution:** Add `.tag(model)` to rows + `Hashable` conformance

❌ **Problem:** Loading entire models into memory  
✅ **Solution:** Separate heavy content with `.externalStorage`

❌ **Problem:** UI not updating after changes  
✅ **Solution:** Call `modelContext.save()` - @Query updates automatically

❌ **Problem:** Complex data synchronization  
✅ **Solution:** Remove intermediate layer - use @Query directly

## Summary

The pure SwiftData + @Query architecture provides:
- ✅ **Simplicity** - ~1500 lines of code removed
- ✅ **Reactivity** - Automatic UI updates via @Query
- ✅ **Performance** - External storage + selective loading
- ✅ **Reliability** - No synchronization bugs
- ✅ **Apple's way** - Following SwiftData best practices
- ✅ **Less maintenance** - Fewer layers = fewer bugs

**Bottom line:** When your friend says "use @Query and create new Views," they're right! 🎯
