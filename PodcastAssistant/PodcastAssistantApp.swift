import SwiftUI
import PodcastAssistantFeature

@main
@available(macOS 26.0, *)
struct PodcastAssistantApp: App {
    // Initialize SwiftData persistence
    let persistenceController = PersistenceController.shared
    
    // Environment for focused values
    @FocusedValue(\.selectedEpisode) private var selectedEpisode
    @FocusedValue(\.canPerformTranscriptActions) private var canPerformTranscriptActions
    @FocusedValue(\.canPerformThumbnailActions) private var canPerformThumbnailActions
    @FocusedValue(\.transcriptActions) private var transcriptActions
    @FocusedValue(\.thumbnailActions) private var thumbnailActions
    @FocusedValue(\.aiActions) private var aiActions
    @FocusedValue(\.podcastActions) private var podcastActions
    @FocusedValue(\.episodeActions) private var episodeActions
    
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
        .commands {
            // File Menu
            CommandGroup(after: .newItem) {
                Button("New Podcast...") {
                    podcastActions?.createPodcast()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                .disabled(podcastActions == nil)
                
                Button("New Episode...") {
                    episodeActions?.createEpisode()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(episodeActions == nil)
            }
            
            // Edit Menu
            CommandGroup(after: .pasteboard) {
                Divider()
                
                Button("Paste as Background Image") {
                    thumbnailActions?.pasteBackground()
                }
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .disabled(selectedEpisode == nil)
                
                Button("Paste as Overlay Image") {
                    thumbnailActions?.pasteOverlay()
                }
                .keyboardShortcut("v", modifiers: [.command, .option])
                .disabled(selectedEpisode == nil)
            }
            
            // Episode Menu
            CommandMenu("Episode") {
                Button("Edit Episode Details...") {
                    episodeActions?.editEpisode()
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(selectedEpisode == nil)
                
                Menu("Import") {
                    Button("Import Transcript...") {
                        transcriptActions?.importTranscript()
                    }
                    .keyboardShortcut("i", modifiers: [.command])
                    .disabled(selectedEpisode == nil)
                    
                    Button("Import Thumbnail Background...") {
                        thumbnailActions?.importBackground()
                    }
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                    .disabled(selectedEpisode == nil)
                    
                    Button("Import Thumbnail Overlay...") {
                        thumbnailActions?.importOverlay()
                    }
                    .disabled(selectedEpisode == nil)
                }
                
                Menu("Export") {
                    Button("Export SRT...") {
                        transcriptActions?.exportSRT()
                    }
                    .keyboardShortcut("e", modifiers: [.command, .shift])
                    .disabled(selectedEpisode == nil || canPerformTranscriptActions?.canExport != true)
                    
                    Button("Export Translated SRT...") {
                        transcriptActions?.exportTranslated()
                    }
                    .disabled(selectedEpisode == nil || canPerformTranscriptActions?.canExport != true)
                    
                    Button("Export Thumbnail...") {
                        thumbnailActions?.exportThumbnail()
                    }
                    .keyboardShortcut("s", modifiers: [.command, .option])
                    .disabled(selectedEpisode == nil || canPerformThumbnailActions?.canExport != true)
                }
                
                Divider()
                
                Button("Convert Transcript to SRT") {
                    transcriptActions?.convertToSRT()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(selectedEpisode == nil || canPerformTranscriptActions?.canConvert != true)
                
                Button("Clear Transcript") {
                    transcriptActions?.clearTranscript()
                }
                .disabled(selectedEpisode == nil || canPerformTranscriptActions?.canClear != true)
                
                Divider()
                
                Button("Generate Thumbnail") {
                    thumbnailActions?.generateThumbnail()
                }
                .keyboardShortcut("g", modifiers: [.command])
                .disabled(selectedEpisode == nil || canPerformThumbnailActions?.canGenerate != true)
                
                Button("Clear Thumbnail") {
                    thumbnailActions?.clearThumbnail()
                }
                .disabled(selectedEpisode == nil || canPerformThumbnailActions?.canClear != true)
                
                Divider()
                
                Button("Generate All AI Ideas") {
                    Task {
                        await aiActions?.generateAll()
                    }
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
                .disabled(selectedEpisode == nil || aiActions == nil)
                
                Divider()
                
                Button("Delete Episode") {
                    episodeActions?.deleteEpisode()
                }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(selectedEpisode == nil || episodeActions == nil)
            }
            
            // View Menu additions
            CommandGroup(after: .sidebar) {
                Button("Details") {
                    episodeActions?.showDetails()
                }
                .keyboardShortcut("1", modifiers: [.command])
                .disabled(selectedEpisode == nil)
                
                Button("Transcript") {
                    episodeActions?.showTranscript()
                }
                .keyboardShortcut("2", modifiers: [.command])
                .disabled(selectedEpisode == nil)
                
                Button("Thumbnail") {
                    episodeActions?.showThumbnail()
                }
                .keyboardShortcut("3", modifiers: [.command])
                .disabled(selectedEpisode == nil)
                
                Button("AI Ideas") {
                    episodeActions?.showAIIdeas()
                }
                .keyboardShortcut("4", modifiers: [.command])
                .disabled(selectedEpisode == nil)
            }
        }
        
        Settings {
            SettingsView()
                .modelContainer(persistenceController.container)
        }
    }
}
