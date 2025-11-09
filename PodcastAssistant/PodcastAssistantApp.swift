import SwiftUI
import PodcastAssistantFeature

@main
@available(macOS 26.0, *)
struct PodcastAssistantApp: App {
    // Initialize SwiftData persistence
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(persistenceController.container)
        }
        
        Settings {
            SettingsView()
                .modelContainer(persistenceController.container)
        }
    }
}

