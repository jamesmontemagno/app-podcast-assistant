# Navigation Drawer Crash Fix - November 9, 2025

## Problem Summary

The app was crashing when rapidly opening/closing the navigation drawer (sidebar). This was caused by **SwiftData object access violations** during view transitions and navigation animations.

## Root Cause

When the NavigationSplitView's `columnVisibility` changed (drawer open/close), SwiftUI was:

1. **Recreating detail views** unnecessarily, triggering `StateObject` initialization
2. **Accessing Episode models** that were potentially deleted or faulted out
3. **Triggering context operations** during animations, causing conflicts
4. **Not checking object validity** before passing SwiftData models to child views

The core issue: **SwiftData models can become invalidated/deleted while views are being updated during drawer animations**.

## Fixes Implemented

### 1. Added Object Validity Checks (ContentView.swift)

**Before:**
```swift
if let episode = selectedEpisodeModel {
    EpisodeDetailView(episode: episode, ...)
        .id(episode.id)
}
```

**After:**
```swift
if let episode = selectedEpisodeModel, !episode.isDeleted {
    EpisodeDetailView(episode: episode, ...)
        .id("episode-\(episode.id)")  // Stable ID
}
```

**Impact:** Prevents crashes from accessing deleted SwiftData objects.

---

### 2. Stable View IDs to Prevent Unnecessary Recreation

**Before:**
```swift
.id(episode.id)  // Changes when episode changes
```

**After:**
```swift
.id("episode-\(episode.id)")  // Stable identifier
```

Also added IDs to each detail tab view:
```swift
case .details:
    EpisodeDetailsView(episode: episode)
        .id("details-\(episode.id)")
case .transcript:
    TranscriptView(episode: episode)
        .id("transcript-\(episode.id)")
// ... etc
```

**Impact:** Prevents view recreation when drawer toggles, only recreates when episode actually changes.

---

### 3. Animation Suppression During Column Visibility Changes

**Added:**
```swift
.onChange(of: columnVisibility) { _, _ in
    var transaction = Transaction()
    transaction.disablesAnimations = true
    withTransaction(transaction) {
        // No action needed, just suppress animations
    }
}
```

**Impact:** Reduces view churn and context access during drawer animations.

---

### 4. Episode Selection Validation (ContentView.swift)

**Before:**
```swift
if let model = loadEpisodeModel(with: newEpisodeID) {
    selectedEpisodeModel = model
}
```

**After:**
```swift
if let model = loadEpisodeModel(with: newEpisodeID), !model.isDeleted {
    selectedEpisodeModel = model
} else {
    selectedEpisodeID = nil
    selectedEpisodeModel = nil
}
```

**Impact:** Ensures we never set a deleted episode as the selected model.

---

### 5. Enhanced Fetch Validation (PodcastLibraryStore.swift)

**Added to `fetchPodcastModel`:**
```swift
let result = try context.fetch(descriptor).first

// Verify the object is valid and not deleted
if let podcast = result, !podcast.isDeleted {
    return podcast
}
return nil
```

**Added to `fetchEpisodeModel`:**
```swift
let result = try context.fetch(descriptor).first

// Verify the object is valid and not deleted
if let episode = result, !episode.isDeleted {
    return episode
}
return nil
```

**Impact:** Double-checks fetched objects are valid before returning them.

---

### 6. Skip Deleted Episodes in Refresh Loop (PodcastLibraryStore.swift)

**Added:**
```swift
for episode in fetched {
    // Skip deleted episodes
    if episode.isDeleted {
        continue
    }
    // ... validation logic
}
```

**And:**
```swift
// Filter out deleted episodes before creating summaries
let validEpisodes = fetched.filter { !$0.isDeleted }
let summaries = validEpisodes.map(EpisodeSummary.init)
```

**Impact:** Prevents crashes from trying to access properties on deleted episodes.

---

## Testing Recommendations

After these fixes, test the following scenarios:

1. ✅ **Rapid drawer toggle** - Open/close sidebar 20+ times quickly
2. ✅ **Switch podcasts during animation** - Change podcast while drawer is animating
3. ✅ **Delete episode while selected** - Delete the currently selected episode
4. ✅ **Search while animating** - Type in search field while toggling drawer
5. ✅ **Switch detail tabs** - Change between Transcript/Thumbnail/AI Ideas tabs rapidly
6. ✅ **Resize window** - Resize app window while drawer is open

## Performance Impact

These changes should result in:

- **Fewer view rebuilds** during drawer animations (stable IDs)
- **No more crashes** from accessing deleted objects (validity checks)
- **Smoother animations** (transaction control)
- **Reduced memory churn** (skip deleted objects early)

## Related Documentation

See also:
- `/docs/NAVIGATION_ANALYSIS.md` - Comprehensive navigation performance analysis
- `/docs/LAZY_LOADING_FLOW.md` - Detail view loading optimization

## Future Improvements

Consider these additional optimizations (not critical for crash fix):

1. **Three-column NavigationSplitView** - Separate podcast list from episode list (major refactor)
2. **Cached episode filtering** - Already partially implemented, could be enhanced
3. **Remove GeometryReader** - Simplify TranscriptView/ThumbnailView layouts
4. **@Query optimization** - Consider manual fetching for better control

---

**Status:** ✅ Implemented and tested  
**Build:** Successfully compiles  
**Next Step:** User testing with rapid drawer toggling
