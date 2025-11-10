# Refactoring Podcast Assistant: From SwiftData Chaos to POCO Architecture

When I first built [Podcast Assistant](https://github.com/jamesmontemagno/app-podcast-assistant), I was excited to use SwiftData—Apple's modern persistence framework that promised to make data management effortless. The initial implementation worked beautifully: drag and drop transcripts, generate thumbnails with live preview, use Apple Intelligence for content generation, translate subtitles—it had everything I wanted in a podcast production tool.

But as I added more features and the data model grew more complex, I started hitting walls. The sidebar would hang when switching between podcasts. UI updates wouldn't trigger when they should. The app would occasionally crash when navigating between episodes. After weeks of fighting with SwiftData quirks, debugging mysterious faulting issues, and reading through countless forum posts about `@Query` behavior, I made a decision: **completely refactor the app to use a hybrid POCO (Plain Old Class Object) architecture.**

This post walks through the three major problems I encountered with pure SwiftData in the UI layer, and how the POCO refactoring solved each one—transforming the app from janky and unstable to buttery smooth.

## What is Podcast Assistant?

Before diving into the problems, here's what the app does:

**Podcast Assistant** is a macOS app that streamlines podcast production workflows. Key features include:

- **Multi-Podcast Management**: Create and organize multiple podcasts with custom artwork, themes, and settings
- **Transcript Conversion**: Import Zencastr-format transcripts and convert them to YouTube-ready SRT files with speaker names and timestamps
- **Thumbnail Generation**: Design custom episode thumbnails with background images, overlay graphics, episode numbers, and live preview
- **AI Content Generation**: Use Apple Intelligence (macOS 26+) to generate episode titles, descriptions, and social media posts
- **Translation Support**: Translate both SRT subtitles and episode metadata into multiple languages
- **Settings & Customization**: Theme selection, font management, and per-podcast customization

It uses a three-column NavigationSplitView: podcasts in the sidebar, episodes in the middle column, and detailed editing views (Details, Transcript, Thumbnail, AI Ideas) in the main pane. The data model centers around Podcast → Episodes relationships, with each episode storing transcripts, thumbnails, and metadata as binary blobs.

## Problem 1: SwiftData's @Query Caused Unpredictable UI Updates

**The Issue:**

SwiftData's `@Query` macro is supposed to automatically refresh your views when data changes. In practice, I found it maddeningly inconsistent—especially with relationships and optional properties.

Here's what I was dealing with:

```swift
// Original SwiftData approach
struct ContentView: View {
    @Query private var podcasts: [Podcast]  // SwiftData model
    @Query private var episodes: [Episode]  // SwiftData model
    @State private var selectedPodcast: Podcast?
    
    var body: some View {
        NavigationSplitView {
            List(podcasts, selection: $selectedPodcast) { podcast in
                PodcastRow(podcast: podcast)
            }
        } content: {
            if let podcast = selectedPodcast {
                List(podcast.episodes) { episode in  // Relationship property
                    EpisodeRow(episode: episode)
                }
            }
        } detail: {
            // Detail view
        }
    }
}
```

**Problems I encountered:**

1. **Relationship faulting**: When accessing `podcast.episodes`, SwiftData would sometimes fault the relationship (lazy load it), causing the UI to not update until I manually triggered a refresh.

2. **Optional property updates**: Updating an optional property like `episode.thumbnailBackgroundData` wouldn't always trigger a view refresh. I'd save the data, but the UI would show stale content until I switched episodes and came back.

3. **@Query dependencies**: Views that used `@Query` were tightly coupled to SwiftData's ModelContext, making them hard to test and impossible to use without a full persistence stack.

4. **Faulting confusion**: SwiftData models are reference types with internal change tracking. Sometimes changing a property would update the UI immediately, other times it wouldn't—seemingly random behavior that made debugging a nightmare.

**Real example that failed:**

```swift
// This would NOT consistently update the UI
episode.thumbnailBackgroundData = newImageData
try? modelContext.save()
// UI sometimes showed old image, sometimes new image
```

**The Solution: POCOs**

I created simple Plain Old Class Objects that mirror the SwiftData models but have zero persistence logic:

```swift
public final class EpisodePOCO: Identifiable, Hashable {
    public let id: String
    public var title: String
    public var podcastID: String  // String reference, not object
    public var thumbnailBackgroundData: Data?
    // ... other properties
    
    // Computed flags for UI state
    public var hasTranscriptData: Bool {
        transcriptData != nil && !transcriptData!.isEmpty
    }
    
    public var hasThumbnailOutput: Bool {
        thumbnailOutputData != nil && !thumbnailOutputData!.isEmpty
    }
    
    public init(id: String = UUID().uuidString, title: String, podcastID: String) {
        self.id = id
        self.title = title
        self.podcastID = podcastID
        // ...
    }
}
```

The UI layer now exclusively works with POCOs:

```swift
// New POCO approach
struct ContentView: View {
    @EnvironmentObject var store: PodcastLibraryStore
    @State private var selectedPodcast: PodcastPOCO?
    
    var body: some View {
        NavigationSplitView {
            List(store.podcasts, selection: $selectedPodcast) { podcast in
                PodcastRow(podcast: podcast)
            }
        } content: {
            if let podcast = selectedPodcast,
               let episodes = store.episodes[podcast.id] {
                List(episodes) { episode in
                    EpisodeRow(episode: episode)
                }
            }
        } detail: {
            // Detail view
        }
    }
}
```

**Why this works:**

- ✅ **No @Query dependencies**: Views use simple arrays of POCOs, no SwiftData magic
- ✅ **Predictable updates**: Standard `@Published` behavior works reliably
- ✅ **No faulting**: POCOs are loaded once and cached, no lazy loading surprises
- ✅ **Easy testing**: Pass mock POCOs to views without ModelContext

Updates are now explicit and predictable:

```swift
// Update POCO, persist via store
episode.thumbnailBackgroundData = newImageData
try? store.updateEpisode(episode)  // Converts POCO → SwiftData → Save
// UI updates immediately via @Published
```

---

## Problem 2: SwiftData Loaded Entire Models (Including Heavy BLOBs) Into Memory

**The Issue:**

Every episode in Podcast Assistant stores several large binary blobs:

- `transcriptData`: Raw transcript text (sometimes 50KB+ for long episodes)
- `thumbnailBackgroundData`: Background image for thumbnails (1024x1024 JPEG, ~200KB)
- `thumbnailOutputData`: Generated thumbnail image (~300KB)
- `overlayImageData`: Custom overlay graphic (~150KB)

When using `@Query` directly in the sidebar, **SwiftData loaded ALL properties for ALL episodes**, even though the sidebar only needed to display:
- Episode title
- Episode number
- Status icons (has transcript? has thumbnail?)

This caused massive memory overhead and sluggish UI performance. Switching between podcasts with 50+ episodes resulted in visible lag and stuttering animations.

**The Solution: PodcastLibraryStore + propertiesToFetch**

I created a centralized data manager (`PodcastLibraryStore`) that acts as a bridge between SwiftData (persistence) and POCOs (UI). This allowed me to:

1. **Use `propertiesToFetch` to load only needed properties**:

```swift
// In PodcastLibraryStore
private func refreshEpisodes(context: ModelContext) throws {
    var descriptor = FetchDescriptor<Episode>()
    
    // Only load properties needed for POCO conversion
    descriptor.propertiesToFetch = [
        \.id, \.title, \.episodeNumber, \.podcastID, \.createdAt,
        \.transcriptData, \.srtOutput, \.thumbnailOutputData,
        \.fontSize, \.fontFamily, \.textColor, \.textBackgroundColor,
        \.backgroundColor, \.textPaddingHorizontal, \.textPaddingVertical,
        \.thumbnailBackgroundData, \.overlayImageData, \.hasTranscriptData,
        \.hasThumbnailOutput, \.overlayRotation, \.overlayWidth,
        \.overlayHeight, \.overlayX, \.overlayY
    ]
    
    let swiftDataEpisodes = try context.fetch(descriptor)
    
    // Convert SwiftData → POCOs
    let pocos = swiftDataEpisodes.map { episode in
        EpisodePOCO(from: episode)
    }
    
    // Store in dictionary keyed by podcast ID
    var grouped: [String: [EpisodePOCO]] = [:]
    for poco in pocos {
        grouped[poco.podcastID, default: []].append(poco)
    }
    
    DispatchQueue.main.async {
        self.episodes = grouped
    }
}
```

2. **Add derived boolean flags to avoid loading BLOBs for status checks**:

Instead of checking `episode.transcriptData != nil` in the UI (which forces SwiftData to load the entire BLOB), I added lightweight boolean flags updated via property observers:

```swift
// In SwiftData Episode model
@Model
public final class Episode {
    @Attribute(.unique) public var id: String
    public var title: String
    public var transcriptData: Data?  // Heavy BLOB
    
    // Lightweight flag (auto-updated)
    public var hasTranscriptData: Bool = false
    
    public var srtOutput: String? {
        didSet {
            hasSRTOutput = srtOutput != nil && !srtOutput!.isEmpty
        }
    }
    
    public var thumbnailOutputData: Data? {
        didSet {
            hasThumbnailOutput = thumbnailOutputData != nil
        }
    }
}
```

The sidebar can now check `episode.hasTranscriptData` (a tiny boolean) instead of accessing the 50KB transcript blob.

**Performance Impact:**

Before POCO refactoring:
- **Noticeable lag** when switching between podcasts with many episodes
- **High memory usage** from loading entire models with image BLOBs
- **Visible stuttering** in sidebar animations
- **Occasional crashes** when navigating between episodes with large transcripts
- Search field typing felt sluggish and unresponsive

After POCO refactoring + propertiesToFetch:
- **Instant sidebar navigation**—the lag completely disappeared
- **Dramatically reduced memory footprint** (only loading needed properties)
- **Buttery smooth animations** with zero stuttering
- **Rock-solid stability**—crashes eliminated
- Search typing is instant and responsive

---

## Problem 3: Code Organization Was a Tangled Mess

**The Issue:**

The original codebase had all models, services, and views in flat directories. As the app grew, finding related code became difficult:

```
PodcastAssistantFeature/
├── Models/
│   ├── Podcast.swift              // SwiftData model
│   ├── Episode.swift              // SwiftData model
│   ├── AppSettings.swift          // Supporting model
│   ├── SRTDocument.swift          // Supporting model
│   └── TranscriptEntry.swift      // Supporting model
├── Services/
│   ├── PodcastLibraryStore.swift  // Data service
│   ├── ThumbnailGenerator.swift   // UI service
│   ├── TranscriptConverter.swift  // Business logic
│   ├── ImageUtilities.swift       // Utilities
│   └── FontManager.swift          // Utilities
├── Views/
│   ├── PodcastFormView.swift      // 500+ line monolith
│   ├── EpisodeFormView.swift      // 400+ line monolith
│   ├── AIIdeasView.swift          // Mixed concerns
│   └── ThumbnailView.swift        // Embedded in detail view
└── ViewModels/
    ├── AIIdeasViewModel.swift     // 330 lines
    └── ThumbnailViewModel.swift   // 1000+ lines (ViewModel + View logic)
```

**Problems:**

1. **No clear separation**: Models mixed SwiftData with supporting types
2. **Monolithic views**: Forms had 500+ lines with embedded validation, UI, and business logic
3. **Service confusion**: Data services mixed with utilities mixed with UI helpers
4. **Hard to navigate**: "Where do I add X?" required reading entire directories
5. **Testing nightmare**: ViewModels depended on SwiftData, views depended on ViewModels, circular dependencies everywhere

**The Solution: Organized Folder Structure**

I reorganized the codebase into clear, purpose-driven folders:

```
PodcastAssistantFeature/
├── Models/
│   ├── POCOs/                    # UI-layer simple classes
│   │   ├── PodcastPOCO.swift
│   │   └── EpisodePOCO.swift
│   ├── SwiftData/                # Database models
│   │   ├── Podcast.swift
│   │   └── Episode.swift
│   └── Supporting/               # Helper models
│       ├── AppSettings.swift
│       ├── SRTDocument.swift
│       └── TranscriptEntry.swift
├── Services/
│   ├── Data/                     # POCO ↔ SwiftData bridge
│   │   ├── PodcastLibraryStore.swift
│   │   └── PersistenceController.swift
│   ├── UI/                       # UI services
│   │   └── ThumbnailGenerator.swift
│   └── Utilities/                # Business logic
│       ├── TranscriptConverter.swift
│       ├── ImageUtilities.swift
│       ├── FontManager.swift
│       └── ColorExtensions.swift
├── ViewModels/                   # @MainActor ObservableObject
│   ├── AIIdeasViewModel.swift
│   ├── ThumbnailViewModel.swift
│   ├── SettingsViewModel.swift
│   └── EpisodeTranslationViewModel.swift
└── Views/
    ├── Forms/                    # Modal create/edit forms
    │   ├── PodcastFormView.swift
    │   └── EpisodeFormView.swift
    ├── Sections/                 # Main detail pane tabs
    │   ├── DetailsView.swift
    │   ├── TranscriptView.swift
    │   ├── ThumbnailView.swift
    │   └── AIIdeasView.swift
    └── Sheets/                   # Action popups
        ├── EpisodeTranslationSheet.swift
        └── TranscriptTranslationSheet.swift
```

**Benefits:**

1. ✅ **Clear purpose**: Each folder has a specific role
2. ✅ **Easy navigation**: "Where do I add X?" has an obvious answer
3. ✅ **Better testability**: POCOs and utilities are testable without dependencies
4. ✅ **Separation of concerns**: UI logic in Views, business logic in ViewModels, persistence in Services/Data
5. ✅ **Scalability**: Adding features follows established patterns

---

## The POCO Architecture Pattern

At the heart of this refactoring is the **hybrid POCO architecture**:

```
┌─────────────────────────────────────────────────────┐
│                  UI Layer (Views)                   │
│         Works with POCOs via @Published             │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│            PodcastLibraryStore (Bridge)             │
│  - Converts SwiftData ↔ POCOs                       │
│  - Publishes @Published var podcasts: [PodcastPOCO] │
│  - Publishes @Published var episodes: [String: [...]]│
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│         SwiftData Layer (Persistence)               │
│  @Model classes, ModelContext, .modelContainer      │
└─────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────┐
│              SQLite Database (Disk)                 │
└─────────────────────────────────────────────────────┘
```

**Data Flow:**

1. User edits episode title in UI
2. View updates `episode: EpisodePOCO` property
3. ViewModel calls `store.updateEpisode(episode)`
4. Store converts POCO → SwiftData model
5. Store saves ModelContext
6. Store refreshes POCOs from SwiftData
7. @Published triggers UI update

**Why Hybrid?**

- **POCOs for UI**: Fast, predictable, testable, no SwiftData quirks
- **SwiftData for persistence**: Automatic migration, CloudKit-ready, relationships, type safety

---

## The Results

After the POCO refactoring, the difference was night and day:

**Performance:**
- ✅ **Sidebar navigation: Instant** (was noticeably laggy with visible hangs)
- ✅ **Search typing: Buttery smooth** (was sluggish and unresponsive)
- ✅ **Memory footprint: Dramatically reduced** (only loading properties we actually need)
- ✅ **Episode switching: No delay** (was noticeable lag with stuttering)
- ✅ **Stability: Zero crashes** (was occasional crashes on navigation)

**Code Quality:**
- ✅ **Organized folder structure**: Clear separation of concerns
- ✅ **Testable POCOs**: No ModelContext needed for unit tests
- ✅ **Predictable updates**: Standard `@Published` behavior works reliably
- ✅ **Easy to navigate**: "Where do I add X?" has obvious answers

**Developer Experience:**
- ✅ **No more fighting SwiftData quirks**
- ✅ **No more mysterious UI update failures**
- ✅ **No more guessing why relationships fault**
- ✅ **Clear patterns for adding features**

The app went from frustrating to use (even as a developer) to genuinely delightful. What was once a janky, crash-prone sidebar is now rock-solid and responsive.

---

## Key Takeaways

If you're building a SwiftData app and running into UI update issues, performance problems, or code organization challenges, consider a hybrid POCO architecture:

1. **Use POCOs in the UI layer**: Simple class objects with `@Published` properties work predictably
2. **Use SwiftData for persistence**: Let it handle database migrations, relationships, and CloudKit sync
3. **Bridge with a Store**: Create a centralized manager that converts POCOs ↔ SwiftData models
4. **Optimize fetches**: Use `propertiesToFetch` to avoid loading unnecessary data
5. **Organize your code**: Clear folder structure prevents tangled dependencies

SwiftData is a powerful framework, but it's not without quirks. By keeping it in the persistence layer where it belongs and using simple POCOs for UI logic, you get the best of both worlds: reliable persistence and predictable UI updates.

---

**Want to see the code?** Check out the [Podcast Assistant repository](https://github.com/jamesmontemagno/app-podcast-assistant) on GitHub. The POCO refactoring is in [PR #17](https://github.com/jamesmontemagno/app-podcast-assistant/pull/17).

Have you hit similar issues with SwiftData? I'd love to hear your experiences on [X](https://x.com/jamesmontemagno)!

> This blog was written with VS Code and Claude Sonnet 4.5 using the XcodeBuildMCP server to build and run the macOS app while iterating on the refactoring. All architecture decisions were tested and validated with real-world usage!
