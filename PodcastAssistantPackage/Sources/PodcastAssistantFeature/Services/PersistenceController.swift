import Foundation
import CoreData

/// Manages the Core Data stack for the Podcast Assistant app.
/// Currently configured for local-only storage, but designed to be CloudKit-ready for future iCloud sync.
@MainActor
public final class PersistenceController {
    
    // MARK: - Singleton
    
    public static let shared = PersistenceController()
    
    // MARK: - Preview Support
    
    /// In-memory persistence controller for SwiftUI previews
    public static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        
        // Create sample data for previews
        let podcast = Podcast(context: context)
        podcast.name = "Sample Podcast"
        podcast.podcastDescription = "A great podcast about technology"
        
        let episode = Episode(context: context)
        episode.title = "Episode 1: Getting Started"
        episode.episodeNumber = 1
        episode.podcast = podcast
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return controller
    }()
    
    // MARK: - Core Data Stack
    
    public let container: NSPersistentContainer
    
    // MARK: - Initialization
    
    /// Initialize the persistence controller
    /// - Parameter inMemory: If true, creates an in-memory store for testing/previews
    public init(inMemory: Bool = false) {
        // Load the Core Data model from the package bundle
        guard let modelURL = Bundle.module.url(forResource: "PodcastAssistant", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load Core Data model from PodcastAssistantFeature package")
        }
        
        // MARK: Local-Only Configuration (Current)
        container = NSPersistentContainer(name: "PodcastAssistant", managedObjectModel: model)
        
        // MARK: iCloud Sync Configuration (Future)
        // To enable iCloud sync in the future, replace the above line with:
        //
        // container = NSPersistentCloudKitContainer(name: "PodcastAssistant", managedObjectModel: model)
        //
        // Then add these entitlements to Config/PodcastAssistant.entitlements:
        // - com.apple.developer.icloud-container-identifiers = ["iCloud.$(CFBundleIdentifier)"]
        // - com.apple.developer.ubiquity-kvstore-identifier = "$(TeamIdentifierPrefix)$(CFBundleIdentifier)"
        // - com.apple.developer.icloud-services = ["CloudKit"]
        //
        // CloudKit schema will be auto-generated from this Core Data model.
        // The current schema is CloudKit-compatible:
        // - All attributes use supported types (String, Int, Double, Date, Binary Data)
        // - Relationships are properly configured with inverse relationships
        // - Binary data uses external storage for large files (images)
        // - No unsupported Core Data features (fetched properties, abstract entities, etc.)
        //
        // Migration considerations:
        // - Users will need to be signed into iCloud
        // - Initial sync may take time depending on data size
        // - Conflict resolution is automatic (last-write-wins by default)
        // - Consider adding CloudKit subscription notifications for real-time updates
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure automatic migration for schema updates
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        container.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        container.loadPersistentStores { description, error in
            if let error = error as NSError? {
                // Replace this implementation with proper error handling in production
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        // Merge policy: prefer in-memory changes over persistent store
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }
    
    // MARK: - Save Context
    
    /// Save the view context if there are changes
    public func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Error saving context: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
