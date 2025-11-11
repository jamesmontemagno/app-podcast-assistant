import Foundation
import SwiftData

/// Manages the SwiftData model container for the Podcast Assistant app.
/// Currently configured for local-only storage.
/// 
/// ## Enabling iCloud Sync
/// To enable CloudKit sync:
/// 1. Uncomment the CloudKit configuration in `init(inMemory:)` below
/// 2. Add CloudKit entitlements to `Config/PodcastAssistant.entitlements`:
///    ```xml
///    <key>com.apple.developer.icloud-services</key>
///    <array>
///        <string>CloudKit</string>
///    </array>
///    <key>com.apple.developer.icloud-container-identifiers</key>
///    <array>
///        <string>iCloud.com.refractored.PodcastAssistant</string>
///    </array>
///    ```
/// 3. Configure CloudKit container in Apple Developer portal
/// 4. Sign the app with a valid provisioning profile
@MainActor
public final class PersistenceController {
    
    // MARK: - Singleton
    
    public static let shared = PersistenceController()
    
    // MARK: - Preview Support
    
    /// In-memory persistence controller for SwiftUI previews
    public static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.mainContext
        
        // Create sample data for previews
        let podcast = Podcast(
            name: "Sample Podcast",
            podcastDescription: "A great podcast about technology"
        )
        context.insert(podcast)
        
        let episode = Episode(
            title: "Episode 1: Getting Started",
            episodeNumber: 1,
            podcast: podcast
        )
        context.insert(episode)
        
        do {
            try context.save()
        } catch {
            fatalError("Preview data creation failed: \(error)")
        }
        
        return controller
    }()
    
    // MARK: - SwiftData Container
    
    public let container: ModelContainer
    
    // MARK: - Schema
    
    private static let schema = Schema([
        Podcast.self,
        Episode.self,
        EpisodeContent.self,
        AppSettings.self
    ])
    
    // MARK: - Initialization
    
    /// Initialize the persistence controller
    /// - Parameter inMemory: If true, creates an in-memory store for testing/previews
    public init(inMemory: Bool = false) {
        do {
            let configuration = ModelConfiguration(
                schema: Self.schema,
                isStoredInMemoryOnly: inMemory,
                allowsSave: true
                // CloudKit sync disabled - see class documentation for enabling instructions
                // cloudKitDatabase: inMemory ? .none : .private("iCloud.com.refractored.PodcastAssistant")
            )
            
            container = try ModelContainer(
                for: Self.schema,
                configurations: [configuration]
            )
            
            // Enable autosave (default behavior in SwiftData)
            container.mainContext.autosaveEnabled = true
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    // MARK: - Save Context
    
    /// Save the main context if there are changes
    /// Note: SwiftData autosaves by default, but this method is provided for explicit saves
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
}
