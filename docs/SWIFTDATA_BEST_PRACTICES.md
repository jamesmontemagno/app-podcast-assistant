# SwiftData Best Practices

**Lessons learned from migrating Podcast Assistant from POCO hybrid to pure SwiftData @Query binding.**

## Core Principles

### 1. "When in Doubt, Create a New View"

**The most important SwiftData pattern**: Instead of passing filtered data down through the view hierarchy, create a new child view with its own `@Query` using dynamic predicates.

```swift
// ❌ DON'T: Filter in parent, pass array down
struct ParentView: View {
    @Query private var allEpisodes: [Episode]
    
    var body: some View {
        let filtered = allEpisodes.filter { $0.podcast?.id == podcastID }
        ChildView(episodes: filtered)  // Breaks reactivity!
    }
}

// ✅ DO: Create new view with its own @Query
struct EpisodeListView: View {
    let podcastID: String
    
    @Query private var episodes: [Episode]
    
    init(podcastID: String) {
        self.podcastID = podcastID
        let predicate = #Predicate<Episode> { episode in
            episode.podcast?.id == podcastID
        }
        _episodes = Query(filter: predicate, sort: \.episodeNumber)
    }
    
    var body: some View {
        List(episodes) { episode in
            EpisodeRow(episode: episode)
        }
    }
}
```

**Why?** SwiftData's `@Query` is reactive - it automatically updates when data changes. Manual filtering breaks this reactivity chain.

### 2. External Storage for Large Data

**Performance critical**: Use `@Attribute(.externalStorage)` for large strings and binary data to prevent memory bloat and improve responsiveness.

```swift
@Model
public final class EpisodeContent {
    // Large text content - store externally
    @Attribute(.externalStorage) public var transcriptInputText: String?
    @Attribute(.externalStorage) public var transcriptSRT: String?
    
    // Large binary data - store externally
    @Attribute(.externalStorage) public var thumbnailBackgroundData: Data?
    @Attribute(.externalStorage) public var thumbnailPreviewData: Data?
    @Attribute(.externalStorage) public var videoData: Data?
    
    // Small metadata - store inline
    public var lastModified: Date = Date()
}
```

**Separate heavy content from lightweight metadata**:
```swift
@Model
public final class Episode: Hashable {
    // Lightweight metadata (always loaded)
    public var id: String
    public var title: String
    public var episodeNumber: Int
    
    // Heavy content (lazy loaded, cascade delete)
    @Relationship(deleteRule: .cascade, inverse: \EpisodeContent.episode)
    public var content: EpisodeContent?
    
    // Convenience accessors for UI
    public var transcriptInputText: String? {
        get { content?.transcriptInputText }
        set { 
            if content == nil { content = EpisodeContent() }
            content?.transcriptInputText = newValue
        }
    }
}
```

**Performance impact**: In Podcast Assistant, this pattern eliminated UI lag when scrolling episode lists with large transcripts.

### 3. List Selection Requires .tag() + Hashable

**Critical for NavigationSplitView**: List selection binding requires both `.tag()` modifiers and `Hashable` conformance.

```swift
@Model
public final class Podcast: Hashable {
    @Attribute(.unique) public var id: String
    public var name: String
    
    // Required for List selection
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Podcast, rhs: Podcast) -> Bool {
        lhs.id == rhs.id
    }
}

// In view:
NavigationSplitView {
    List(podcasts, selection: $selectedPodcast) { podcast in
        PodcastRow(podcast: podcast)
            .tag(podcast)  // ← REQUIRED for selection to work
    }
}
```

**Without .tag()**: Selection appears to work (rows highlight) but `$selectedPodcast` binding never updates. This can waste hours debugging!

### 4. Trust ModelContext.save() for Reactivity

**Don't overthink updates**: Modify SwiftData models directly, call `modelContext.save()`, trust `@Query` to react.

```swift
struct DetailView: View {
    @Bindable var episode: Episode
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        TextField("Title", text: $episode.title)
            .onChange(of: episode.title) { 
                try? modelContext.save()  // That's it! @Query views will update
            }
    }
}
```

**No need for**:
- ❌ `@Published` properties (SwiftData handles change notification)
- ❌ `objectWillChange.send()` (SwiftData models already conform to Observable)
- ❌ Manual array updates (let `@Query` handle it)
- ❌ Bridge layers (POCOs, stores, etc.)

**Why it works**: SwiftData models are `Observable`, ModelContext tracks changes, `@Query` automatically refreshes when `save()` is called.

### 5. Use @Bindable for Two-Way Binding

**For editing SwiftData models in UI**: Use `@Bindable` macro for two-way bindings with TextField, Toggle, Picker, etc.

```swift
struct EditEpisodeView: View {
    @Bindable var episode: Episode
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Form {
            TextField("Title", text: $episode.title)
            TextField("Description", text: $episode.episodeDescription)
            Toggle("Published", isOn: $episode.isPublished)
        }
        .onChange(of: episode) { 
            try? modelContext.save()
        }
    }
}
```

**Pattern**: `@Bindable` on the parameter → use `$property` bindings → save on change.

## Architecture Patterns

### Query-First Design

**Start with @Query at the top level**, create child views with filtered @Query as needed:

```swift
struct ContentView: View {
    @Query(sort: \Podcast.name) private var podcasts: [Podcast]
    @State private var selectedPodcast: Podcast?
    @State private var selectedEpisode: Episode?
    
    var body: some View {
        NavigationSplitView {
            // Sidebar: All podcasts
            List(podcasts, selection: $selectedPodcast) { podcast in
                PodcastRow(podcast: podcast).tag(podcast)
            }
        } content: {
            // Middle: Episodes for selected podcast
            if let podcast = selectedPodcast {
                EpisodeListView(podcastID: podcast.id, selection: $selectedEpisode)
            }
        } detail: {
            // Detail: Show selected episode
            if let episode = selectedEpisode {
                EpisodeDetailView(episode: episode)
            }
        }
    }
}
```

### Dynamic Predicates in Init

**For filtered queries**, build `#Predicate` in `init()`:

```swift
struct EpisodeListView: View {
    let podcastID: String
    @Query private var episodes: [Episode]
    @Binding var selection: Episode?
    
    init(podcastID: String, selection: Binding<Episode?>) {
        self.podcastID = podcastID
        self._selection = selection
        
        // Build dynamic predicate
        let predicate = #Predicate<Episode> { episode in
            episode.podcast?.id == podcastID
        }
        _episodes = Query(filter: predicate, sort: \Episode.episodeNumber)
    }
    
    var body: some View {
        List(episodes, selection: $selection) { episode in
            EpisodeRow(episode: episode).tag(episode)
        }
    }
}
```

**Supports**:
- Multiple conditions: `episode.podcast?.id == podcastID && episode.isPublished`
- String matching: `episode.title.localizedStandardContains(searchText)`
- Sorting: `Query(filter: predicate, sort: \Episode.episodeNumber, order: .reverse)`

### ViewModel Pattern (When Needed)

**For complex business logic**, use ViewModels that work with SwiftData models:

```swift
@MainActor
public class ThumbnailViewModel: ObservableObject {
    @Published public var episode: Episode
    private var modelContext: ModelContext?
    
    public init(episode: Episode, modelContext: ModelContext?) {
        self.episode = episode
        self.modelContext = modelContext
    }
    
    public var fontSize: Double {
        get { episode.fontSize }
        set {
            episode.fontSize = newValue
            try? modelContext?.save()
            objectWillChange.send()  // Notify UI
        }
    }
    
    public func generateThumbnail() async throws {
        // Complex logic here
        let imageData = try await ThumbnailGenerator.generate(...)
        episode.thumbnailPreviewData = imageData
        try? modelContext?.save()
        objectWillChange.send()
    }
}
```

**When to use ViewModels**:
- ✅ Complex business logic (image generation, API calls, async work)
- ✅ Computed properties with side effects
- ✅ Multi-step operations that need coordination
- ❌ Simple CRUD (just use `@Environment(\.modelContext)` in view)

### Pass ModelContext Explicitly

**For services and ViewModels**: Pass `ModelContext` as dependency, don't rely on environment.

```swift
// In View
@Environment(\.modelContext) private var modelContext
@StateObject private var viewModel: ThumbnailViewModel

// Pass to ViewModel
.onAppear {
    viewModel = ThumbnailViewModel(episode: episode, modelContext: modelContext)
}

// ViewModel uses it
private var modelContext: ModelContext?

public func save() {
    try? modelContext?.save()
}
```

**Why?** ViewModels aren't SwiftUI views - they don't have environment. Pass dependencies explicitly.

## Performance Optimization

### 1. Lazy Loading Relationships

**Don't force-load related objects** unless needed:

```swift
// ✅ Good: Optional relationship
@Relationship public var content: EpisodeContent?

// Access lazily
if let content = episode.content {
    // Only loaded if accessed
    let text = content.transcriptInputText
}

// ❌ Bad: Non-optional forces eager loading
@Relationship public var content: EpisodeContent  // Always loaded!
```

### 2. Fetch Only What You Need

**Use projections** for lightweight queries:

```swift
// Just titles and IDs
@Query(sort: \Episode.title) 
private var episodes: [Episode]

var body: some View {
    List(episodes) { episode in
        // Only access properties you need
        Text(episode.title)  // Don't access .content here!
    }
}
```

### 3. Batch Operations

**For bulk updates**, batch them and save once:

```swift
func updateMultipleEpisodes(_ episodes: [Episode]) {
    for episode in episodes {
        episode.isPublished = true
        // Don't save() here!
    }
    try? modelContext.save()  // Save once at end
}
```

## Common Pitfalls

### 1. Forgetting .tag() on List Rows

**Symptom**: List selection binding doesn't update (but rows highlight).

**Fix**: Add `.tag(item)` to each row:
```swift
List(items, selection: $selected) { item in
    Row(item: item).tag(item)  // ← Don't forget!
}
```

### 2. Passing Filtered Arrays Instead of Using @Query

**Symptom**: UI doesn't update when data changes.

**Fix**: Create new view with its own `@Query` (see Principle #1).

### 3. Not Using External Storage for Large Data

**Symptom**: App becomes sluggish with many items, high memory usage.

**Fix**: Add `@Attribute(.externalStorage)` to large properties:
```swift
@Attribute(.externalStorage) public var largeText: String?
@Attribute(.externalStorage) public var imageData: Data?
```

### 4. Missing Hashable Conformance

**Symptom**: List selection doesn't work, compiler errors about Hashable.

**Fix**: Add Hashable conformance to @Model classes:
```swift
@Model
public final class MyModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: MyModel, rhs: MyModel) -> Bool {
        lhs.id == rhs.id
    }
}
```

### 5. Overusing ViewModels

**Symptom**: Complex bridge layers, lots of boilerplate, manual sync logic.

**Fix**: Let SwiftData handle reactivity. Use ViewModels only for complex business logic, not simple CRUD.

## Testing

### Unit Testing SwiftData Models

```swift
import Testing
import SwiftData

@Test func testEpisodeCreation() async throws {
    // Create in-memory container
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Podcast.self, Episode.self, EpisodeContent.self,
        configurations: config
    )
    
    let context = ModelContext(container)
    
    // Test model operations
    let podcast = Podcast(name: "Test Show")
    context.insert(podcast)
    
    let episode = Episode(title: "Episode 1", podcast: podcast)
    context.insert(episode)
    
    try context.save()
    
    // Verify
    let descriptor = FetchDescriptor<Episode>()
    let episodes = try context.fetch(descriptor)
    #expect(episodes.count == 1)
    #expect(episodes[0].title == "Episode 1")
}
```

### UI Testing with PreviewContainer

```swift
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Podcast.self, Episode.self,
        configurations: config
    )
    
    // Create sample data
    let podcast = Podcast(name: "Preview Show")
    container.mainContext.insert(podcast)
    
    return ContentView()
        .modelContainer(container)
}
```

## Migration from POCO/Intermediate Layers

If you have an existing app with POCO or intermediate bridge layers:

### Step 1: Add Hashable to Models

```swift
@Model
public final class YourModel: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: YourModel, rhs: YourModel) -> Bool {
        lhs.id == rhs.id
    }
}
```

### Step 2: Create Filtered Views with @Query

Replace store-based filtering with `@Query` predicates:

```swift
// Before: POCO store
@EnvironmentObject var store: DataStore
var episodes: [EpisodePOCO] { store.episodes[podcastID] }

// After: @Query with predicate
@Query private var episodes: [Episode]

init(podcastID: String) {
    let predicate = #Predicate<Episode> { episode in
        episode.podcast?.id == podcastID
    }
    _episodes = Query(filter: predicate)
}
```

### Step 3: Replace Store Updates with ModelContext

```swift
// Before: Store bridge
store.updateEpisode(episodePOCO)

// After: Direct model update
episode.title = "New Title"
try? modelContext.save()
```

### Step 4: Add .tag() to All Lists

```swift
// Add to every List with selection binding
List(items, selection: $selected) { item in
    Row(item).tag(item)  // ← Add this
}
```

### Step 5: Delete POCO/Store Code

Once everything works, delete:
- ❌ POCO models (PodcastPOCO, EpisodePOCO, etc.)
- ❌ Store classes (PodcastLibraryStore, etc.)
- ❌ Conversion utilities (toPOCO(), toSwiftData(), etc.)

**Result**: Dramatically simpler codebase, same or better performance.

## Summary

**The 5 SwiftData Rules**:

1. **Create views with @Query** - Don't filter and pass arrays
2. **Use external storage** - For large strings and binary data
3. **Add .tag() + Hashable** - For List selection binding
4. **Trust modelContext.save()** - SwiftData handles reactivity
5. **Keep it simple** - Don't over-engineer with bridge layers

**Performance wins**:
- ✅ External storage eliminates memory bloat
- ✅ Lazy relationships load on demand
- ✅ @Query handles reactivity automatically
- ✅ No manual sync between layers

**Code simplicity wins**:
- ✅ ~1,500 lines removed (POCOs + bridge)
- ✅ No conversion utilities needed
- ✅ Direct model binding in views
- ✅ Less state management complexity

**Developer experience wins**:
- ✅ Trust the framework (it works!)
- ✅ Less debugging of sync issues
- ✅ Clearer data flow
- ✅ Easier to reason about changes
