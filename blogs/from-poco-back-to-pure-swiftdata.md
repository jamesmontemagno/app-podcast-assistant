# From POCO Hybrid Back to Pure SwiftData: Lessons from a Friend

A few weeks ago, I wrote about [refactoring Podcast Assistant from SwiftData to a POCO hybrid architecture](./refactoring-podcast-assistant-from-swiftdata-to-poco-architecture.md). The TL;DR was: SwiftData's `@Query` felt unpredictable, relationships were faulting at random times, and the UI wasn't updating when it should. So I built an intermediate POCO (Plain Old Class Object) layer with a `PodcastLibraryStore` bridge to make everything "just work."

And it did work! Butter smooth performance, predictable updates, ~1500 lines of carefully crafted bridge code synchronizing POCOs with SwiftData models. I was proud of it.

Then I showed it to a friend who's been building SwiftData apps since the framework launched. Their reaction?

> "Why did you do all that? Just use `@Query` directly and when in doubt, create a new View. SwiftData reactivity works great when you follow the patterns correctly."

I pushed back: "But the UI updates were inconsistent! Relationships were faulting! Selection binding didn't work!"

They smiled: "Did you add `.tag()` to your List rows? Did you make your models `Hashable`? Did you use external storage for heavy data?"

I had not.

So I spent a weekend **completely removing the POCO layer** and going back to pure SwiftData with `@Query`. The result? **The app works perfectly, it's simpler, and I deleted 1,500 lines of unnecessary code.**

This post is about what I learned, what I got wrong the first time, and why my friend was absolutely right.

---

## What Changed: The Before and After

### Before (POCO Hybrid)

**ContentView.swift** (~150 lines):
```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var store = PodcastLibraryStore()
    
    @State private var selectedPodcast: PodcastPOCO?
    @State private var selectedEpisode: EpisodePOCO?
    
    var body: some View {
        NavigationSplitView {
            List(store.podcasts, selection: $selectedPodcast) { podcast in
                PodcastRow(podcast: podcast)
            }
        } content: {
            if let podcast = selectedPodcast,
               let episodes = store.episodes[podcast.id] {
                List(episodes, selection: $selectedEpisode) { episode in
                    EpisodeRow(episode: episode)
                }
            }
        } detail: {
            if let episode = selectedEpisode {
                EpisodeDetailView(episode: episode, store: store)
            }
        }
        .environmentObject(store)
        .onAppear {
            try? store.loadInitialData(context: modelContext)
        }
    }
}
```

**Supporting Cast:**
- `PodcastPOCO.swift` (~300 lines) - Simple class mirroring Podcast
- `EpisodePOCO.swift` (~400 lines) - Simple class mirroring Episode  
- `PodcastLibraryStore.swift` (~800 lines) - Bridge converting POCOs ↔ SwiftData
- Conversion methods in ViewModels to handle POCOs

**Total:** ~1,500 lines of intermediate layer code

### After (Pure SwiftData)

**ContentView.swift** (~120 lines):
```swift
struct ContentView: View {
    @Query(sort: \Podcast.createdAt, order: .reverse)
    private var podcasts: [Podcast]
    
    @State private var selectedPodcast: Podcast?
    @State private var selectedEpisode: Episode?
    
    var body: some View {
        NavigationSplitView {
            List(podcasts, selection: $selectedPodcast) { podcast in
                PodcastRow(podcast: podcast)
                    .tag(podcast)  // ← This was the missing piece!
            }
        } content: {
            if let podcast = selectedPodcast {
                EpisodeListView(podcast: podcast, selectedEpisode: $selectedEpisode)
            }
        } detail: {
            if let episode = selectedEpisode, let podcast = selectedPodcast {
                EpisodeDetailView(episode: episode, podcast: podcast)
            }
        }
    }
}
```

**Supporting Cast:**
- ✨ Nothing else needed! ✨
- SwiftData models used directly
- `@Query` handles reactivity automatically
- `modelContext.save()` triggers UI updates

**Total:** ~0 lines of intermediate layer code (deleted 1,500 lines!)

---

## The Three Critical Mistakes I Made

### Mistake #1: Not Using `.tag()` for List Selection

**The Problem:**

My original implementation had List selection that looked like this:

```swift
List(podcasts, selection: $selectedPodcast) { podcast in
    PodcastRow(podcast: podcast)
    // Missing: .tag(podcast)
}
```

**What I thought:** "SwiftUI is smart, it'll figure out the binding automatically."

**What actually happened:** Clicking on rows did nothing. Selection state never updated. I could see the podcasts, but couldn't select them.

**What I concluded:** "SwiftData @Query is broken for selection! I need POCOs!"

**What I should have done:**

```swift
List(podcasts, selection: $selectedPodcast) { podcast in
    PodcastRow(podcast: podcast)
        .tag(podcast)  // ← Tell SwiftUI which value to bind!
}
```

**Why it matters:** SwiftUI's List needs `.tag()` to know *which value* should be assigned to the selection binding when you click a row. Without it, the binding doesn't work. This has **nothing to do with SwiftData** - it's a SwiftUI List requirement!

**The fix also requires:**
```swift
extension Podcast: Hashable {
    public static func == (lhs: Podcast, rhs: Podcast) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

Models need `Hashable` conformance for `.tag()` to compare values correctly.

---

### Mistake #2: Not Using External Storage for Heavy Data

**The Problem:**

My original SwiftData schema looked like this:

```swift
@Model
public final class Episode {
    public var id: String
    public var title: String
    public var transcriptData: Data?        // ← 50KB+ transcript blob
    public var thumbnailBackgroundData: Data?  // ← 200KB image blob
    public var thumbnailOutputData: Data?   // ← 300KB generated thumbnail
    // ... 20 more properties
}
```

**What I thought:** "SwiftData will handle large properties efficiently."

**What actually happened:** 
- Loading a podcast's episode list would fetch **all properties** of **all episodes**
- This meant loading hundreds of KB of image data just to display episode titles
- The sidebar would visibly lag when switching between podcasts
- Memory usage ballooned

**What I concluded:** "SwiftData loads too much data! I need POCOs to control what's loaded!"

**What I should have done:**

Split the model into lightweight (always loaded) and heavyweight (loaded on demand):

```swift
// Episode.swift - Lightweight, always loaded
@Model
public final class Episode {
    public var id: String
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

// EpisodeContent.swift - Heavy, loaded on demand
@Model
public final class EpisodeContent {
    @Attribute(.externalStorage) 
    public var transcriptInputText: String?
    
    @Attribute(.externalStorage) 
    public var thumbnailBackgroundData: Data?
    
    @Attribute(.externalStorage)
    public var thumbnailOutputData: Data?
    
    public var episode: Episode?
}
```

**Why it matters:** SwiftData's `.externalStorage` attribute tells the framework to store large blobs in separate files, not in the main database. Combined with the separate `EpisodeContent` model, SwiftData **only loads the heavy data when you actually access it**!

**Result:**
- Episode list queries are lightning fast (only loading title, number, dates)
- Images loaded lazily when you edit an episode
- Memory usage dramatically reduced
- Sidebar navigation is instant

**The lesson:** SwiftData *does* support selective loading - you just have to design your schema correctly!

---

### Mistake #3: Not Creating Dynamic @Query Views

**The Problem:**

My original approach tried to filter episodes in a computed property:

```swift
struct EpisodeListView: View {
    let episodes: [EpisodePOCO]  // Passed from parent
    @State private var searchText = ""
    
    private var filteredEpisodes: [EpisodePOCO] {
        episodes.filter { episode in
            searchText.isEmpty || episode.title.contains(searchText)
        }
    }
    
    var body: some View {
        List(filteredEpisodes) { episode in
            EpisodeRow(episode: episode)
        }
    }
}
```

**What I thought:** "I need to pass data down from parent, then filter/sort locally."

**What actually happened:**
- Parent had to fetch all episodes for all podcasts upfront
- Filtering happened in memory after loading everything
- No reactive updates when episodes were added/deleted in other views

**What I concluded:** "I need a centralized store to manage this data!"

**What I should have done:**

My friend's advice: **"When in doubt, create a new View with its own @Query."**

```swift
struct EpisodeListView: View {
    let podcast: Podcast
    @Binding var selectedEpisode: Episode?
    
    // Dynamic @Query filtered by podcast.id
    @Query private var episodes: [Episode]
    
    @State private var searchText = ""
    @State private var sortOption: SortOption = .newestFirst
    
    public init(podcast: Podcast, selectedEpisode: Binding<Episode?>) {
        self.podcast = podcast
        self._selectedEpisode = selectedEpisode
        
        // Dynamic predicate - only fetch episodes for THIS podcast
        let podcastID = podcast.id
        let predicate = #Predicate<Episode> { episode in
            episode.podcast?.id == podcastID
        }
        
        _episodes = Query(
            filter: predicate,
            sort: [SortDescriptor(\Episode.createdAt, order: .reverse)]
        )
    }
    
    private var filteredEpisodes: [Episode] {
        if searchText.isEmpty {
            return sortedEpisodes
        }
        return sortedEpisodes.filter { episode in
            episode.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack {
            // Search field
            TextField("Search...", text: $searchText)
            
            // Episode list
            List(filteredEpisodes, selection: $selectedEpisode) { episode in
                EpisodeRow(episode: episode)
                    .tag(episode)
            }
        }
    }
}
```

**Why it matters:**
- Each View gets its own `@Query` with a dynamic predicate
- SwiftData only fetches episodes for the selected podcast
- When you add/delete episodes, `@Query` automatically refreshes
- Search/sort happen in memory on the already-filtered list (fast!)

**The pattern:** Instead of passing data down from a centralized store, **create focused Views with their own @Query predicates**. SwiftData handles efficiency automatically.

---

## What I Learned: SwiftData Best Practices

After listening to my friend and rebuilding with pure SwiftData, here's what I learned:

### 1. @Query is Reactive - Trust It

**Old mindset:** "I need to manually trigger UI updates when data changes."

**New understanding:** `@Query` automatically re-runs when the underlying data changes. Just call `modelContext.save()` and SwiftUI refreshes automatically.

**Example:**
```swift
struct PodcastFormView: View {
    let podcast: Podcast?
    @Environment(\.modelContext) private var modelContext
    
    func save() {
        if let podcast = podcast {
            // Update existing - UI updates automatically!
            podcast.name = editedName
            podcast.updatedAt = Date()
        } else {
            // Create new - UI updates automatically!
            let newPodcast = Podcast(name: editedName)
            modelContext.insert(newPodcast)
        }
        
        try? modelContext.save()  // ← This triggers @Query refresh
    }
}
```

No manual refresh needed. No `@Published` arrays. Just save and let SwiftData handle it.

### 2. List Selection Requires .tag() + Hashable

**The pattern:**
```swift
// Model conformance
extension Podcast: Hashable {
    public static func == (lhs: Podcast, rhs: Podcast) -> Bool {
        lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// View usage
List(podcasts, selection: $selectedPodcast) { podcast in
    PodcastRow(podcast: podcast)
        .tag(podcast)  // ← Required!
}
```

**Why:** SwiftUI needs to compare values for selection binding. Without `Hashable`, the comparison fails. Without `.tag()`, SwiftUI doesn't know which value to bind.

### 3. External Storage for Performance

**The pattern:**
- Separate lightweight models from heavy models
- Use `@Attribute(.externalStorage)` for large Data/String
- Access via convenience properties for lazy loading

**Example:**
```swift
// Always loaded
@Model class Episode {
    var title: String
    var content: EpisodeContent?
    
    var transcriptText: String? {
        get { content?.transcriptText }  // Lazy!
        set { 
            if content == nil { content = EpisodeContent() }
            content?.transcriptText = newValue
        }
    }
}

// Loaded on demand
@Model class EpisodeContent {
    @Attribute(.externalStorage) var transcriptText: String?
}
```

**Result:** Episode lists are fast (no blob loading), but editing still has full access to heavy data.

### 4. Create Views with Dynamic @Query

**The pattern:** Instead of passing data down, create new Views with focused queries.

**Before (centralized):**
```swift
@StateObject var store = PodcastLibraryStore()

// Store loads everything, filters in memory
let episodes = store.episodes[podcastID] ?? []
EpisodeListView(episodes: episodes)
```

**After (distributed):**
```swift
// Each view queries only what it needs
EpisodeListView(podcast: selectedPodcast)

// Inside EpisodeListView:
@Query(filter: #Predicate { $0.podcast?.id == podcastID })
private var episodes: [Episode]
```

**Result:** SwiftData optimizes queries automatically, less code, reactive updates work perfectly.

---

## The Performance Results

After removing the POCO layer and following SwiftData best practices:

### Before (POCO Hybrid)
- **Code:** ~1,500 lines of intermediate layer
- **Sidebar lag:** Noticeable when switching podcasts with many episodes
- **Memory:** High (all episodes loaded as POCOs)
- **Reactivity:** Manual synchronization via store updates

### After (Pure SwiftData)
- **Code:** ~0 lines of intermediate layer (deleted POCOs/store!)
- **Sidebar lag:** Completely gone (external storage + selective loading)
- **Memory:** Dramatically reduced (only lightweight properties loaded)
- **Reactivity:** Automatic via @Query

**Performance is identical** - butter smooth in both cases. But the pure SwiftData version has **far less code** and is **much simpler to maintain**.

---

## The Key Insight: I Was Fighting the Framework

Looking back, my POCO refactoring was a solution to problems I created by not understanding SwiftData's patterns:

| Problem I Had | What I Thought | What I Should Have Done |
|---------------|----------------|-------------------------|
| Selection not working | "@Query is broken" | Add `.tag()` + `Hashable` |
| Loading too much data | "SwiftData loads everything" | Use external storage |
| No reactive updates | "I need manual refresh" | Trust `@Query` reactivity |
| Complex data flow | "I need a centralized store" | Create dynamic @Query Views |

**The lesson:** When you're fighting a framework, step back and ask: "Am I following the recommended patterns?"

In my case, I wasn't. My friend showed me the right way, and everything clicked.

---

## When to Use POCOs (and When Not To)

After this experience, here's my updated guidance:

### ✅ Use POCOs When:
- You need Codable for JSON encoding/decoding
- You're working with external APIs
- You need value types (structs) for specific use cases
- You're building preview data for SwiftUI previews

### ❌ Don't Use POCOs When:
- You're already using SwiftData for persistence
- You want reactive UI updates
- You're trying to "fix" SwiftData issues (learn the patterns instead!)
- You think you need a "bridge layer" (you probably don't!)

**Bottom line:** If you're using SwiftData, use it directly. Don't create intermediate layers unless you have a specific, unavoidable reason.

---

## The Refactoring Process

Here's how I removed the POCO layer:

### Step 1: Delete POCO Files
```bash
rm PodcastPOCO.swift
rm EpisodePOCO.swift  
rm PodcastLibraryStore.swift
```

**Result:** Xcode showed ~200 compiler errors. Good! That's what we want.

### Step 2: Update ContentView to Use @Query
```swift
// Before
@StateObject private var store = PodcastLibraryStore()
List(store.podcasts, selection: $selectedPodcast) { ... }

// After  
@Query(sort: \Podcast.createdAt, order: .reverse)
private var podcasts: [Podcast]
List(podcasts, selection: $selectedPodcast) { podcast in
    PodcastRow(podcast: podcast)
        .tag(podcast)  // ← Don't forget!
}
```

### Step 3: Create EpisodeListView with Dynamic @Query
```swift
struct EpisodeListView: View {
    let podcast: Podcast
    
    @Query private var episodes: [Episode]
    
    init(podcast: Podcast, selectedEpisode: Binding<Episode?>) {
        self.podcast = podcast
        self._selectedEpisode = selectedEpisode
        
        let podcastID = podcast.id
        _episodes = Query(filter: #Predicate<Episode> { episode in
            episode.podcast?.id == podcastID
        })
    }
    
    var body: some View {
        List(episodes, selection: $selectedEpisode) { episode in
            EpisodeRow(episode: episode)
                .tag(episode)
        }
    }
}
```

### Step 4: Update Forms to Use ModelContext
```swift
// Before
func save() {
    try? store.updatePodcast(podcast)
}

// After
@Environment(\.modelContext) private var modelContext

func save() {
    podcast.name = editedName
    try? modelContext.save()  // ← That's it!
}
```

### Step 5: Update ViewModels to Accept Models
```swift
// Before
init(episode: EpisodePOCO, store: PodcastLibraryStore) {
    self.episode = episode
    self.store = store
}

// After
init(episode: Episode, modelContext: ModelContext) {
    self.episode = episode
    self.modelContext = modelContext
}
```

### Step 6: Add Hashable to Models
```swift
extension Podcast: Hashable { ... }
extension Episode: Hashable { ... }
```

### Step 7: Build & Test

After fixing all compilation errors, the app built successfully. I tested:
- ✅ Creating/editing/deleting podcasts → Works perfectly
- ✅ Creating/editing/deleting episodes → Works perfectly
- ✅ Selecting podcasts/episodes → Works perfectly (with `.tag()`!)
- ✅ Search and filtering → Works perfectly
- ✅ All detail views (Transcript, Thumbnail, AI) → Work perfectly
- ✅ Performance → Butter smooth!

**Total time:** ~4 hours to remove 1,500 lines of code and simplify everything.

---

## What My Friend Taught Me

The conversation that started this refactoring:

**Me:** "I had to create a POCO layer because SwiftData @Query was too unpredictable."

**Friend:** "Did you follow the recommended patterns?"

**Me:** "What patterns?"

**Friend:** 
1. "Use `.tag()` for List selection"
2. "Make models `Hashable`"
3. "Use external storage for heavy data"
4. "Create new Views with @Query when in doubt"
5. "Trust SwiftData reactivity - just call `save()`"

**Me:** "Oh. I didn't know about any of those."

**Friend:** "That's why you were fighting it. Learn the patterns, and SwiftData just works."

They were absolutely right.

---

## Lessons Learned

### 1. Read the Documentation (Seriously)

I skipped over the SwiftData documentation and jumped straight to coding. Big mistake. The patterns I needed were all documented:
- External storage attributes
- Dynamic predicates
- Relationship management
- Performance optimization

**Lesson:** Spend time learning the framework before building workarounds.

### 2. Ask for Help Early

I spent weeks building the POCO layer before showing it to anyone. If I'd asked my friend earlier, they would have saved me tons of time.

**Lesson:** Get code review early, especially when learning new frameworks.

### 3. Simpler is (Usually) Better

My POCO solution was clever, well-architected, and thoroughly documented. It was also **completely unnecessary**.

**Lesson:** Before adding complexity, ask "Am I solving the right problem?"

### 4. Trust the Framework (After Learning It)

Once I understood the patterns, SwiftData worked beautifully. `@Query` is reactive, external storage is efficient, and dynamic predicates are powerful.

**Lesson:** Frameworks have quirks, but usually there's a recommended way that works well.

---

## The Current Architecture

Here's what the codebase looks like now:

**Models:**
- `Podcast.swift` - SwiftData model (with external storage)
- `Episode.swift` - SwiftData model (lightweight)
- `EpisodeContent.swift` - SwiftData model (heavy data with external storage)

**Views:**
- ContentView uses `@Query` directly
- EpisodeListView uses dynamic `@Query` with predicates
- Forms update models directly via `@Environment(\.modelContext)`
- Detail views accept SwiftData models as parameters

**Total intermediate layer code:** 0 lines

**Reactivity:** Automatic via `@Query`

**Performance:** Excellent (external storage + selective loading)

---

## Conclusion

Sometimes the "clever" solution is the wrong solution. My POCO hybrid architecture worked, but it was solving problems I created by not understanding SwiftData's patterns.

**Key takeaways:**
1. ✅ Learn the framework's recommended patterns first
2. ✅ Use `.tag()` + `Hashable` for List selection
3. ✅ Use external storage for heavy data
4. ✅ Create dynamic @Query Views instead of passing data down
5. ✅ Trust SwiftData reactivity - just call `save()`
6. ✅ When in doubt, create a new View (friend's advice!)

After removing the POCO layer:
- **1,500 lines of code deleted** ✨
- **Zero performance degradation**
- **Simpler, cleaner, more maintainable codebase**
- **Better understanding of SwiftData**

My friend was right. SwiftData @Query works great when you follow the patterns correctly.

---

**Want to see the code?** Check out the [Podcast Assistant repository](https://github.com/jamesmontemagno/app-podcast-assistant) on GitHub. The POCO removal is in the `query-city` branch.

**Have you built SwiftData apps?** I'd love to hear your experiences on [X](https://x.com/jamesmontemagno)!

> This blog was written with VS Code and Claude Sonnet 4.5 after a humbling but enlightening conversation with a friend who actually knows SwiftData. Big thanks to them for teaching me the right way! 🙏
