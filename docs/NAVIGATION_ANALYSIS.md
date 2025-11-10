# NavigationSplitView Performance Analysis

**Date:** November 9, 2025  
**Issue:** App slowness and crashes when opening/closing drawer

## Problems Identified

### 1. ❌ Two-Column Masquerading as Three-Column (Critical)

**Current Implementation:**
```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    VStack {
        // Podcast selector dropdown
        // Episode list
    }
} detail: {
    // Episode detail
}
```

**Problem:** You're using a **two-column** layout but trying to create a three-column experience by cramming the podcast selector and episode list into the sidebar. This forces excessive re-rendering.

**Fix:** Use proper **three-column** NavigationSplitView:
```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    // Sidebar: Podcast list (List of podcasts)
} content: {
    // Content: Episode list for selected podcast
} detail: {
    // Detail: Episode detail views
}
```

**Impact:** Major - eliminates cascading rebuilds during drawer animation

---

### 2. ❌ Expensive Computed Property (Critical)

**Current Code:**
```swift
private var selectedPodcast: Podcast? {
    guard let id = selectedPodcastID else { return nil }
    return podcasts.first { $0.id == id }  // Searches array on EVERY render
}
```

**Problem:** This searches the entire `podcasts` array on **every body evaluation**. During drawer animation, this runs 60+ times per second.

**Fix:** Use cached `@State` variable:
```swift
@State private var selectedPodcast: Podcast?

// Update only when selection changes
.onChange(of: selectedPodcastID) { _, newID in
    selectedPodcast = podcasts.first { $0.id == newID }
}
```

**Impact:** Major - eliminates O(n) search during every render

---

### 3. ❌ Filtering Logic in Body (Critical)

**Current Code:**
```swift
let filteredEpisodes = filterAndSortEpisodes(podcast.episodes)

List(selection: $selectedEpisode) {
    ForEach(filteredEpisodes) { episode in
        EpisodeRow(episode: episode)
    }
}
```

**Problem:** `filterAndSortEpisodes()` runs during **every frame** of drawer animation, processing the entire episode array with `localizedCaseInsensitiveContains()` and sorting.

**Fix:** Cache filtered results:
```swift
@State private var filteredEpisodes: [Episode] = []

private func updateFilteredEpisodes() {
    filteredEpisodes = filterAndSortEpisodes(selectedPodcast?.episodes ?? [])
}

.onChange(of: episodeSearchText) { _, _ in updateFilteredEpisodes() }
.onChange(of: episodeSortOption) { _, _ in updateFilteredEpisodes() }
.onChange(of: selectedPodcast?.episodes) { _, _ in updateFilteredEpisodes() }
```

**Impact:** Major - eliminates heavy computation during animation

---

### 4. ❌ ModelContext Usage Pattern (High)

**Current Code:**
```swift
// In view:
@Environment(\.modelContext) private var modelContext

// In StateObject init:
_viewModel = StateObject(wrappedValue: TranscriptViewModel(
    episode: episode,
    context: PersistenceController.shared.container.mainContext  // ⚠️ Direct access
))
```

**Problem:** Mixing `@Environment(\.modelContext)` with direct `PersistenceController.shared.container.mainContext` access can cause context conflicts and unexpected saves/fetches.

**Fix:** Use environment context consistently:
```swift
// In view:
@Environment(\.modelContext) private var modelContext

// Pass environment context:
_viewModel = StateObject(wrappedValue: TranscriptViewModel(
    episode: episode,
    context: modelContext  // ✅ From environment
))
```

**Caveat:** This requires careful handling because `@Environment` isn't available in `init()`. Alternative pattern:
```swift
public init(episode: Episode) {
    self.episode = episode
}

public var body: some View {
    InnerView(episode: episode, context: modelContext)
}

private struct InnerView: View {
    let episode: Episode
    let context: ModelContext
    @StateObject private var viewModel: TranscriptViewModel
    
    init(episode: Episode, context: ModelContext) {
        self.episode = episode
        self.context = context
        _viewModel = StateObject(wrappedValue: TranscriptViewModel(episode: episode, context: context))
    }
}
```

**Impact:** High - prevents context conflicts and improves reliability

---

### 5. ❌ Complex View Hierarchy (Medium)

**Current Code:**
```swift
private struct EpisodeDetailView: View {
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) { ... }
                Divider()
                VStack(spacing: 0) {
                    VStack(spacing: 1) {
                        Button { ... } // 4 buttons
                    }
                }
                Spacer()
            }
            Divider()
            Group {
                switch selectedTab {
                    case .details: EpisodeDetailsView(episode: episode)
                    case .transcript: TranscriptView(episode: episode)
                    case .thumbnail: ThumbnailView(episode: episode)
                    case .aiIdeas: AIIdeasView(episode: episode)
                }
            }
        }
    }
}
```

**Problem:** Deep nesting without explicit view identity causes SwiftUI to rebuild entire tree during state changes.

**Fix:** Extract sub-views and add `.id()` modifiers:
```swift
private struct EpisodeDetailView: View {
    var body: some View {
        HStack(spacing: 0) {
            EpisodeSidebar(episode: episode, selectedTab: $selectedTab)
                .id(episode.id)
            
            Divider()
            
            DetailContentView(episode: episode, selectedTab: selectedTab)
                .id("\(episode.id)-\(selectedTab)")
        }
    }
}
```

**Impact:** Medium - reduces unnecessary view rebuilds

---

### 6. ❌ GeometryReader + HSplitView Nesting (Medium)

**Current Code (TranscriptView, ThumbnailView):**
```swift
GeometryReader { geometry in
    HSplitView {
        VStack { ... }
            .frame(width: geometry.size.width / 2 - 0.5)
    }
}
```

**Problem:** Three levels of layout containers (NavigationSplitView → GeometryReader → HSplitView) compound layout overhead.

**Fix:** Remove GeometryReader, let HSplitView handle sizing naturally:
```swift
HSplitView {
    // Left pane
    VStack { ... }
        .frame(minWidth: 300, idealWidth: 400)
    
    // Right pane
    VStack { ... }
        .frame(minWidth: 300)
}
```

**Impact:** Medium - simplifies layout calculations

---

### 7. ⚠️  @Query Performance (Low-Medium)

**Current Code:**
```swift
@Query(sort: [SortDescriptor(\Podcast.createdAt)])
private var podcasts: [Podcast]
```

**Problem:** SwiftData `@Query` automatically updates on **any** database change, even unrelated ones. Combined with accessing `podcast.episodes`, this triggers cascading fetches.

**Fix:** Consider limiting query scope or using manual fetching for better control:
```swift
// Option 1: Keep @Query but add predicate to limit results
@Query(
    filter: #Predicate<Podcast> { !$0.isDeleted },  // Example filter
    sort: [SortDescriptor(\Podcast.createdAt)]
)
private var podcasts: [Podcast]

// Option 2: Manual fetch with caching
@State private var podcasts: [Podcast] = []

private func fetchPodcasts() {
    let descriptor = FetchDescriptor<Podcast>(
        sortBy: [SortDescriptor(\Podcast.createdAt)]
    )
    do {
        podcasts = try modelContext.fetch(descriptor)
    } catch {
        print("Error fetching podcasts: \(error)")
    }
}
```

**Impact:** Low-Medium - reduces unnecessary database queries

---

## Recommended Implementation Order

1. **Fix #2 (selectedPodcast computed property)** - Immediate impact, small change
2. **Fix #3 (cached filtering)** - Immediate impact, small change  
3. **Fix #1 (three-column layout)** - Major refactor but biggest impact
4. **Fix #4 (ModelContext pattern)** - Improves reliability
5. **Fix #5 (view hierarchy)** - Incremental improvement
6. **Fix #6 (remove GeometryReader)** - Incremental improvement
7. **Fix #7 (@Query optimization)** - Fine-tuning

---

## Testing Checklist

After implementing fixes:

- [ ] Open/close drawer 20+ times rapidly - should stay responsive
- [ ] Switch between podcasts - should be instant
- [ ] Search episodes while drawer is animating - should not lag
- [ ] Resize window while drawer is open - should stay smooth
- [ ] Create/delete episodes - should not cause stuttering
- [ ] Switch between detail tabs - should be instant

---

## Additional Resources

- [TN3154: Adopting SwiftUI navigation split view](https://developer.apple.com/documentation/technotes/tn3154-adopting-swiftui-navigation-split-view/)
- [Migrating to new navigation types](https://developer.apple.com/documentation/swiftui/migrating-to-new-navigation-types)
- [NavigationSplitView Documentation](https://developer.apple.com/documentation/swiftui/navigationsplitview/)

---

## Performance Profiling Tips

Use **Instruments** to verify improvements:

```bash
# Build for profiling
xcodebuild -workspace PodcastAssistant.xcworkspace \
  -scheme PodcastAssistant \
  -configuration Release \
  build

# Then open Instruments and use:
# - Time Profiler: Find hot code paths
# - SwiftUI: View body invocation counts
# - Allocations: Memory churn during animation
```

Focus on:
- **View body invocation count** - should drop significantly
- **Time in filterAndSortEpisodes** - should only run on actual changes
- **SwiftData fetch count** - should minimize during drawer animation
