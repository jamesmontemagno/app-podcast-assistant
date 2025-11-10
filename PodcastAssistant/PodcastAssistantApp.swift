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
            SaveCommands()
            EpisodeCommands()
        }
        .defaultSize(width: 1200, height: 800)
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// MARK: - File Menu Save Commands

struct SaveCommands: Commands {
    @ObservedObject private var appState = AppState.shared
    
    var body: some Commands {
        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                switch appState.selectedEpisodeSection {
                case .details:
                    appState.episodeDetailActions?.save?()
                case .thumbnail:
                    appState.thumbnailActions?.saveThumbnail()
                default:
                    break
                }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(!canSave)
        }
    }
    
    private var canSave: Bool {
        switch appState.selectedEpisodeSection {
        case .details:
            return appState.episodeDetailActions?.save != nil
        case .thumbnail:
            return appState.thumbnailCapabilities?.canSave == true
        default:
            return false
        }
    }
}

// MARK: - Episode Menu Commands

struct EpisodeCommands: Commands {
    @ObservedObject private var appState = AppState.shared
    
    var body: some Commands {
        CommandMenu("Episode") {
            // Save action (appears for Details section)
            if appState.selectedEpisodeSection == .details {
                Button("Save Episode") {
                    appState.episodeDetailActions?.save?()
                }
                .disabled(appState.episodeDetailActions?.save == nil)
                
                Divider()
            }
            
            // Translate action (appears for Details section on macOS 26+)
            if appState.selectedEpisodeSection == .details {
                Button("Translate Episode...") {
                    appState.episodeDetailActions?.translate?()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(appState.episodeDetailActions?.translate == nil)
                
                Divider()
            }
            
            // Section-specific actions will be added here
            Group {
                switch appState.selectedEpisodeSection {
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
        Button("Import Transcript...") {
            appState.transcriptActions?.importTranscript()
        }
        .keyboardShortcut("i", modifiers: [.command, .shift])
        .disabled(appState.transcriptActions == nil)
        
        Divider()
        
        Button("Convert to SRT") {
            appState.transcriptActions?.convertToSRT()
        }
        .keyboardShortcut("k", modifiers: [.command])
        .disabled(appState.transcriptCapabilities?.canConvert != true)
        
        Button("Export SRT...") {
            appState.transcriptActions?.exportSRT()
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .disabled(appState.transcriptCapabilities?.canExport != true)
        
        Divider()
        
        if #available(macOS 26.0, *) {
            Button("Translate Transcript...") {
                appState.transcriptActions?.exportTranslated()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(appState.transcriptCapabilities?.canExport != true)
            
            Divider()
        }
        
        Button("Clear All Transcript Data...") {
            appState.transcriptActions?.clearTranscript()
        }
        .disabled(appState.transcriptCapabilities?.canClear != true)
    }
    
    @ViewBuilder
    private var thumbnailMenuItems: some View {
        Button("Generate Thumbnail") {
            appState.thumbnailActions?.generateThumbnail()
        }
        .keyboardShortcut("g", modifiers: [.command])
        .disabled(appState.thumbnailCapabilities?.canGenerate != true)
        
        Button("Save Thumbnail") {
            appState.thumbnailActions?.saveThumbnail()
        }
        .disabled(appState.thumbnailCapabilities?.canSave != true)
        
        Button("Export Thumbnail...") {
            appState.thumbnailActions?.exportThumbnail()
        }
        .keyboardShortcut("e", modifiers: [.command, .shift])
        .disabled(appState.thumbnailCapabilities?.canExport != true)
        
        Divider()
        
        Button("Import Background Image...") {
            appState.thumbnailActions?.importBackground()
        }
        .disabled(appState.thumbnailActions == nil)
        
        Button("Import Overlay Image...") {
            appState.thumbnailActions?.importOverlay()
        }
        .disabled(appState.thumbnailActions == nil)
        
        Divider()
        
        Button("Paste Background from Clipboard") {
            appState.thumbnailActions?.pasteBackground()
        }
        .keyboardShortcut("v", modifiers: [.command, .option])
        .disabled(appState.thumbnailActions == nil)
        
        Button("Paste Overlay from Clipboard") {
            appState.thumbnailActions?.pasteOverlay()
        }
        .keyboardShortcut("v", modifiers: [.command, .option, .shift])
        .disabled(appState.thumbnailActions == nil)
        
        Divider()
        
        Button("Reset All Settings...") {
            appState.thumbnailActions?.clearThumbnail()
        }
        .disabled(appState.thumbnailCapabilities?.canClear != true)
    }
    
    @ViewBuilder
    private var aiIdeasMenuItems: some View {
        if #available(macOS 26.0, *) {
            Text("AI Ideas Section")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("Use the AI Ideas tab to generate:")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text("• Title suggestions")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text("• Episode descriptions")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text("• Social media posts")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            Text("• Chapter markers")
                .font(.caption2)
                .foregroundStyle(.secondary)
        } else {
            Text("AI Ideas Require macOS 26+")
                .disabled(true)
        }
    }
}
