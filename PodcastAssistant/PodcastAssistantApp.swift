import SwiftUI
import PodcastAssistantFeature

@main
@available(macOS 26.0, *)
struct PodcastAssistantApp: App {
    // Initialize SwiftData persistence
    let persistenceController = PersistenceController.shared
    
    init() {
        // Register all imported fonts on app launch
        Task { @MainActor in
            let fontManager = FontManager()
            try? fontManager.registerImportedFonts()
        }
    }
    
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

