# Core Data Implementation Guide

## Overview

Podcast Assistant uses Core Data for local persistence with a CloudKit-ready schema designed for future iCloud sync. All podcast and episode data is stored locally in a SQLite database managed by Core Data.

## Entity Model

### Podcast Entity

Represents a podcast with its metadata and default settings for episodes.

**Attributes:**
- `id` (UUID) - Unique identifier
- `name` (String) - Podcast name (required)
- `podcastDescription` (String, optional) - Podcast description
- `artworkData` (Binary Data, optional) - Podcast artwork (JPEG, max 1024x1024, compressed)
- `defaultOverlayData` (Binary Data, optional) - Default overlay image for thumbnails
- `defaultFontName` (String, optional) - Default font for episode numbers
- `defaultFontSize` (Double) - Default font size (default: 72.0)
- `defaultTextPositionX` (Double) - Default X position (0.0-1.0, default: 0.5)
- `defaultTextPositionY` (Double) - Default Y position (0.0-1.0, default: 0.5)
- `createdAt` (Date) - Creation timestamp

**Relationships:**
- `episodes` (one-to-many) → `Episode.podcast` (cascade delete)

**Computed Properties:**
- `episodesArray: [Episode]` - Sorted array of episodes by creation date

### Episode Entity

Represents a podcast episode with transcript and thumbnail data.

**Attributes:**
- `id` (UUID) - Unique identifier
- `title` (String) - Episode title (required)
- `episodeNumber` (Int32) - Episode number
- `transcriptInputText` (String, optional) - Raw transcript input
- `srtOutputText` (String, optional) - Generated SRT output
- `thumbnailBackgroundData` (Binary Data, optional) - Background image
- `thumbnailOverlayData` (Binary Data, optional) - Overlay image (copied from podcast defaults)
- `thumbnailOutputData` (Binary Data, optional) - Generated thumbnail
- `fontName` (String, optional) - Font for episode number (copied from podcast defaults)
- `fontSize` (Double) - Font size (copied from podcast defaults)
- `textPositionX` (Double) - Text X position (copied from podcast defaults)
- `textPositionY` (Double) - Text Y position (copied from podcast defaults)
- `createdAt` (Date) - Creation timestamp

**Relationships:**
- `podcast` (many-to-one) → `Podcast.episodes`

**Default Value Inheritance:**
When a new episode is created, default values are copied from the parent podcast:
- Font settings (name, size)
- Text position (X, Y)
- Overlay image (if available)

This copy-on-create approach ensures episodes are independent and changes to podcast defaults don't affect existing episodes.

## Data Flow

### Creating a Podcast

```swift
let podcast = Podcast(context: viewContext)
podcast.name = "My Podcast"
podcast.podcastDescription = "A great show"

// Process and store artwork
if let image = selectedImage {
    podcast.artworkData = ImageUtilities.processImageForStorage(image)
}

try viewContext.save()
```

### Creating an Episode

```swift
let episode = Episode(context: viewContext)
episode.podcast = podcast // Set relationship first
episode.title = "Episode 1"
episode.episodeNumber = 1

// Defaults are copied automatically in awakeFromInsert()
// episode.fontName = podcast.defaultFontName
// episode.fontSize = podcast.defaultFontSize
// etc.

try viewContext.save()
```

### Updating Episode Data (ViewModels)

ViewModels read/write directly to managed object properties:

```swift
// TranscriptViewModel
public var inputText: String {
    get { episode.transcriptInputText ?? "" }
    set {
        episode.transcriptInputText = newValue.isEmpty ? nil : newValue
        saveContext()
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
        saveContext()
    }
}
```

## Image Storage Strategy

### Why Binary Data (BLOBs)?

We store images as binary data in Core Data rather than file URLs for several reasons:

1. **Simplified iCloud sync** - Data syncs automatically with CloudKit
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
         Store in Core Data (external storage enabled)

// On retrieval
Data → ImageUtilities.loadImage() → NSImage
```

### External Binary Storage

Core Data automatically stores large binary data outside the SQLite database when:
- `allowsExternalBinaryDataStorage = YES` (set in model)
- Data size exceeds threshold (~100KB)

This keeps the database file compact while supporting large images.

## Persistence Controller

### Initialization

```swift
let container = NSPersistentContainer(name: "PodcastAssistant", managedObjectModel: model)

// Enable automatic migration
container.persistentStoreDescriptions.first?.setOption(
    true as NSNumber, 
    forKey: NSMigratePersistentStoresAutomaticallyOption
)

// Merge policy for conflicts
container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
container.viewContext.automaticallyMergesChangesFromParent = true
```

### Saving Context

```swift
public func save() {
    let context = container.viewContext
    if context.hasChanges {
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error)")
        }
    }
}
```

## CloudKit Migration Path

### Current Configuration (Local Only)

```swift
container = NSPersistentContainer(name: "PodcastAssistant", managedObjectModel: model)
```

### Future Configuration (iCloud Sync)

To enable iCloud sync:

#### 1. Update PersistenceController.swift

```swift
// Replace NSPersistentContainer with:
container = NSPersistentCloudKitContainer(name: "PodcastAssistant", managedObjectModel: model)
```

#### 2. Add Entitlements (Config/PodcastAssistant.entitlements)

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.$(CFBundleIdentifier)</string>
</array>
<key>com.apple.developer.ubiquity-kvstore-identifier</key>
<string>$(TeamIdentifierPrefix)$(CFBundleIdentifier)</string>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
```

#### 3. CloudKit Schema Compatibility

The current schema is already CloudKit-compatible:

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

### 1. Always Use Managed Object Context on Main Thread

```swift
@MainActor
class MyViewModel: ObservableObject {
    private let context: NSManagedObjectContext
    
    func saveChanges() {
        // This is safe - we're on @MainActor
        try? context.save()
    }
}
```

### 2. Fetch Requests in Views

```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Podcast.createdAt, ascending: true)],
    animation: .default
)
private var podcasts: FetchedResults<Podcast>
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
