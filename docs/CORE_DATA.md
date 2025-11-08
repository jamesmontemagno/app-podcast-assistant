# SwiftData Implementation Guide

## Overview

Podcast Assistant uses SwiftData for local persistence with **CloudKit sync enabled** for iCloud synchronization across devices. All podcast and episode data is stored locally in a SQLite database managed by SwiftData, with automatic sync to iCloud when users are signed in.

## Model Definitions

### Podcast Model

SwiftData model representing a podcast with its metadata and default settings for episodes.

**Properties:**
- `id` (String) - Unique identifier with `@Attribute(.unique)` (CloudKit-compatible)
- `name` (String) - Podcast name (required)
- `podcastDescription` (String?) - Optional podcast description
- `artworkData` (Data?) - Podcast artwork (JPEG, max 1024x1024, compressed)
- `defaultOverlayData` (Data?) - Default overlay image for thumbnails
- `defaultFontName` (String?) - Default font for episode numbers
- `defaultFontSize` (Double) - Default font size (default: 72.0)
- `defaultTextPositionX` (Double) - Default X position (0.0-1.0, default: 0.5)
- `defaultTextPositionY` (Double) - Default Y position (0.0-1.0, default: 0.5)
- `createdAt` (Date) - Creation timestamp

**Relationships:**
- `episodes: [Episode]` - Array with `@Relationship(deleteRule: .cascade, inverse: \Episode.podcast)`

**Note:** SwiftData uses native Swift arrays instead of `NSSet`, eliminating the need for computed `episodesArray` property

### Episode Model

SwiftData model representing a podcast episode with transcript and thumbnail data.

**Properties:**
- `id` (String) - Unique identifier with `@Attribute(.unique)` (CloudKit-compatible)
- `title` (String) - Episode title (required)
- `episodeNumber` (Int32) - Episode number
- `transcriptInputText` (String?) - Raw transcript input
- `srtOutputText` (String?) - Generated SRT output
- `thumbnailBackgroundData` (Data?) - Background image
- `thumbnailOverlayData` (Data?) - Overlay image (copied from podcast defaults)
- `thumbnailOutputData` (Data?) - Generated thumbnail
- `fontName` (String?) - Font for episode number (copied from podcast defaults)
- `fontSize` (Double) - Font size (copied from podcast defaults)
- `textPositionX` (Double) - Text X position (copied from podcast defaults)
- `textPositionY` (Double) - Text Y position (copied from podcast defaults)
- `createdAt` (Date) - Creation timestamp

**Relationships:**
- `podcast: Podcast?` - Many-to-one relationship (inverse declared on Podcast side)

**Default Value Inheritance:**
The custom `init(podcast:)` method automatically copies defaults from the parent podcast:
```swift
public init(title: String, episodeNumber: Int32, podcast: Podcast? = nil) {
    // ... initialization
    if let podcast = podcast {
        self.fontName = podcast.defaultFontName
        self.fontSize = podcast.defaultFontSize
        // ... other defaults
    }
}
```

This copy-on-create approach ensures episodes are independent and changes to podcast defaults don't affect existing episodes.

## Data Flow

### Creating a Podcast

```swift
let podcast = Podcast(
    name: "My Podcast",
    podcastDescription: "A great show"
)
modelContext.insert(podcast)

// Process and store artwork
if let image = selectedImage {
    podcast.artworkData = ImageUtilities.processImageForStorage(image)
}

try modelContext.save()
```

### Creating an Episode

```swift
// SwiftData init automatically copies podcast defaults
let episode = Episode(
    title: "Episode 1",
    episodeNumber: 1,
    podcast: podcast
)
modelContext.insert(episode)

// Defaults are copied automatically in init()
// episode.fontName = podcast.defaultFontName (already done)
// episode.fontSize = podcast.defaultFontSize (already done)
// etc.

try modelContext.save()
```

### Updating Episode Data (ViewModels)

ViewModels read/write directly to SwiftData model properties:

```swift
// TranscriptViewModel
public var inputText: String {
    get { episode.transcriptInputText ?? "" }
    set {
        episode.transcriptInputText = newValue.isEmpty ? nil : newValue
        saveContext() // modelContext.save()
    }
}

// ThumbnailViewModel
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
        saveContext() // modelContext.save()
        objectWillChange.send() // Trigger UI update
    }
}
```

## Image Storage Strategy

### Why Binary Data (BLOBs)?

We store images as binary data in SwiftData rather than file URLs for several reasons:

1. **Simplified CloudKit sync** - Data syncs automatically to iCloud
2. **No file management** - No need to track external files or security-scoped bookmarks
3. **Atomic operations** - Image and metadata save together
4. **Size control** - Images are preprocessed to stay under 1MB

### Image Processing Pipeline

```swift
// Before storage
NSImage → ImageUtilities.processImageForStorage() → Data
         ↓
         Resize to max 1024x1024 (aspect ratio maintained)
         ↓
         Compress to JPEG at 0.8 quality
         ↓
         Store in SwiftData model property

// On retrieval
Data → ImageUtilities.loadImage() → NSImage
```

### Large Binary Data Handling

SwiftData automatically optimizes large binary data storage:
- Data is stored efficiently in the SQLite database
- Large blobs are handled transparently
- No manual configuration needed (unlike Core Data's `allowsExternalBinaryDataStorage`)

This keeps the database performant while supporting large images.

## Persistence Controller

### Initialization with CloudKit

```swift
let schema = Schema([Podcast.self, Episode.self])

let configuration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: inMemory,
    allowsSave: true,
    cloudKitDatabase: inMemory ? .none : .private("iCloud.com.refractored.PodcastAssistant")
)

container = try ModelContainer(
    for: schema,
    configurations: [configuration]
)

// Autosave enabled by default
container.mainContext.autosaveEnabled = true
```

### Saving Context

```swift
public func save() {
    let context = container.mainContext
    if context.hasChanges {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}

// Note: SwiftData autosaves by default, so manual saves are often unnecessary
```

## CloudKit Configuration

### Current Status: **DISABLED** (CloudKit-Ready)

CloudKit sync is currently disabled but the schema is fully CloudKit-compatible.

### How to Enable CloudKit Sync

#### 1. Update PersistenceController.swift

Uncomment the CloudKit configuration:

```swift
let configuration = ModelConfiguration(
    schema: Self.schema,
    isStoredInMemoryOnly: inMemory,
    allowsSave: true,
    cloudKitDatabase: inMemory ? .none : .private("iCloud.com.refractored.PodcastAssistant")
)
```

#### 2. Update Entitlements (Config/PodcastAssistant.entitlements)

Uncomment the CloudKit entitlements:

```xml
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.refractored.PodcastAssistant</string>
</array>
```

#### 3. Configure Apple Developer Portal

1. Create CloudKit container in Apple Developer portal
2. Enable iCloud capability for your App ID
3. Generate provisioning profile with iCloud enabled
4. Configure signing in Xcode

#### 4. SwiftData CloudKit Compatibility

SwiftData models are fully CloudKit-compatible:

✅ **Supported:**
- All attribute types (String, Int, Double, Date, Binary Data)
- One-to-many relationships with inverse
- Cascade delete rules
- External binary storage

❌ **Avoid:**
- Fetched properties
- Abstract entities
- Undefined relationships (always set inverse)

#### 4. Migration Considerations

**User Requirements:**
- Must be signed into iCloud
- Sufficient iCloud storage space

**Sync Behavior:**
- First sync may take time (downloads all data)
- Automatic conflict resolution (last-write-wins)
- Changes propagate to all devices

**Testing:**
- Test with multiple devices/simulators
- Verify conflict resolution
- Test offline → online sync
- Monitor CloudKit dashboard for errors

#### 5. Optional: Real-Time Updates

Add CloudKit subscription notifications:

```swift
container.persistentStoreDescriptions.first?.cloudKitContainerOptions?.databaseScope = .private

// Handle remote change notifications
NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
    .sink { _ in
        // Refresh UI
    }
```

## Best Practices

### 1. Always Use ModelContext on Main Thread

```swift
@MainActor
class MyViewModel: ObservableObject {
    private let context: ModelContext
    
    func saveChanges() {
        // This is safe - we're on @MainActor
        try? context.save()
    }
}
```

### 2. Query Macro in Views

```swift
@Query(sort: [SortDescriptor(\Podcast.createdAt)])
private var podcasts: [Podcast]

// With filtering
@Query(filter: #Predicate<Episode> { $0.episodeNumber > 0 })
private var episodes: [Episode]
```

### 3. Cascade Delete Setup

Parent podcast deletion automatically deletes all child episodes:

```swift
// In Core Data model:
Podcast.episodes relationship → Delete Rule: Cascade
```

### 4. Avoid Retain Cycles

```swift
panel.begin { [weak self] response in
    guard let self = self else { return }
    // Safe to use self here
}
```

### 5. Image Processing Off Main Thread (Future)

For very large images, consider background processing:

```swift
Task.detached {
    let processedData = ImageUtilities.processImageForStorage(image)
    await MainActor.run {
        episode.artworkData = processedData
    }
}
```

## Debugging

### View Core Data SQLite File

```bash
# Find the database
~/Library/Containers/[bundle-id]/Data/Library/Application Support/PodcastAssistant.sqlite

# Inspect with sqlite3
sqlite3 PodcastAssistant.sqlite
.tables
.schema ZPODCAST
SELECT * FROM ZPODCAST;
```

### Enable Core Data Logging

Add launch argument in Xcode scheme:
```
-com.apple.CoreData.SQLDebug 1
```

### Check CloudKit Dashboard

When iCloud sync is enabled:
1. Visit https://icloud.developer.apple.com/
2. Select app's CloudKit container
3. View schema, records, and sync errors

## Performance Considerations

### Image Size Limits

- Max dimension: 1024x1024 pixels
- Compression: JPEG 0.8 quality
- Typical size: 100-500KB per image
- External storage: Automatic for >100KB

### Fetch Request Optimization

```swift
// Limit fetch to needed properties
fetchRequest.propertiesToFetch = ["name", "createdAt"]

// Use batch fetching for relationships
fetchRequest.relationshipKeyPathsForPrefetching = ["episodes"]

// Set batch size for large datasets
fetchRequest.fetchBatchSize = 20
```

### Memory Management

Core Data uses faulting to load data on-demand. Avoid:
- Accessing all episodes of all podcasts at once
- Holding references to large image data unnecessarily
- Creating redundant fetch requests

## Schema Versioning

When adding new attributes/entities:

1. Create new model version: Editor → Add Model Version
2. Set current version in model inspector
3. Add migration mapping if needed
4. Test migration with existing data

Core Data supports lightweight migration for:
- Adding attributes (with default values)
- Removing attributes
- Renaming entities/attributes (with mapping)
- Adding relationships
