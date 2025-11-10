import SwiftUI
import PodcastAssistantFeature

@main
@available(macOS 26.0, *)
struct PodcastAssistantApp: App {
    // Hybrid Architecture: SwiftData for persistence, POCOs for UI binding
    let persistenceController = PersistenceController.shared
    
    // Settings view model for theme management
    @StateObject private var settingsViewModel = SettingsViewModel()
    
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
                .environmentObject(settingsViewModel)
                .onAppear {
                    // Apply saved theme after the app is fully initialized
                    settingsViewModel.applyCurrentTheme()
                }
        }
        .commands {
            EpisodeCommands()
        }
    }
}

// MARK: - Episode Menu Commands

struct EpisodeCommands: Commands {
    @FocusedValue(\.selectedEpisodeSection) private var selectedSection
    @FocusedValue(\.episodeDetailActions) private var episodeDetailActions
    
    var body: some Commands {
        CommandMenu("Episode") {
            // Save action (appears for Details section)
            if selectedSection == .details {
                Button("Save Episode") {
                    episodeDetailActions?.save?()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(episodeDetailActions?.save == nil)
                
                Divider()
            }
            
            // Translate action (appears for Details section on macOS 26+)
            if selectedSection == .details {
                Button("Translate Episode...") {
                    episodeDetailActions?.translate?()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(episodeDetailActions?.translate == nil)
                
                Divider()
            }
            
            // Section-specific actions will be added here
            Group {
                switch selectedSection {
                case .details:
                    detailsMenuItems
                case .transcript:
                    transcriptMenuItems
                case .thumbnail:
                    thumbnailMenuItems
                case .aiIdeas:
                    aiIdeasMenuItems
                case .none:
                    Text("No Episode Selected")
                        .disabled(true)
                }
            }
        }
    }
    
    @ViewBuilder
    private var detailsMenuItems: some View {
        EmptyView()
    }
    
    @ViewBuilder
    private var transcriptMenuItems: some View {
        Text("Transcript Actions Coming Soon")
            .disabled(true)
    }
    
    @ViewBuilder
    private var thumbnailMenuItems: some View {
        Text("Thumbnail Actions Coming Soon")
            .disabled(true)
    }
    
    @ViewBuilder
    private var aiIdeasMenuItems: some View {
        Text("AI Ideas Actions Coming Soon")
            .disabled(true)
    }
}
