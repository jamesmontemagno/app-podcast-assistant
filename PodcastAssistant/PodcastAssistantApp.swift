import SwiftUI
import PodcastAssistantFeature

@main
@available(macOS 26.0, *)
struct PodcastAssistantApp: App {
    // Initialize Core Data persistence
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

