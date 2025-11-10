import SwiftUI
import PodcastAssistantFeature

@main
@available(macOS 26.0, *)
struct PodcastAssistantApp: App {
    // Hybrid Architecture: SwiftData for persistence, POCOs for UI binding
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
    }
}
