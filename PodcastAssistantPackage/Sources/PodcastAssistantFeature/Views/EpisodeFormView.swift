import SwiftUI
import SwiftData

/// Form view for creating or editing an episode
public struct EpisodeFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Parent podcast (required for new episodes)
    public let podcast: Podcast
    
    // Editing existing episode (nil for new episode)
    public let episode: Episode?
    
    // Form fields
    @State private var title: String = ""
    @State private var episodeNumber: Int = 1
    
    // UI state
    @State private var errorMessage: String?
    
    public init(podcast: Podcast, episode: Episode? = nil) {
        self.podcast = podcast
        self.episode = episode
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Episode Information") {
                    TextField("Episode Title", text: $title)
                    
                    HStack {
                        Text("Episode Number")
                        Spacer()
                        TextField("Number", value: $episodeNumber, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                        Stepper("", value: $episodeNumber, in: 1...9999)
                            .labelsHidden()
                    }
                }
                
                Section {
                    Text("Default thumbnail settings will be copied from '\(podcast.name)'")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        if let fontName = podcast.defaultFontName {
                            Text("Font: \(fontName), Size: \(Int(podcast.defaultFontSize))")
                        }
                        Text("Position: X=\(podcast.defaultTextPositionX, specifier: "%.2f"), Y=\(podcast.defaultTextPositionY, specifier: "%.2f")")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                } header: {
                    Text("Default Settings")
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(episode == nil ? "New Episode" : "Edit Episode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.glass)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEpisode()
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadExistingData()
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    // MARK: - Data Loading
    
    private func loadExistingData() {
        if let episode = episode {
            title = episode.title
            episodeNumber = Int(episode.episodeNumber)
        } else {
            // Suggest next episode number
            let existingEpisodes = podcast.episodes
            if let maxNumber = existingEpisodes.map({ $0.episodeNumber }).max() {
                episodeNumber = Int(maxNumber) + 1
            }
        }
    }
    
    // MARK: - Save
    
    private func saveEpisode() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Episode title is required"
            return
        }
        
        let episodeToSave: Episode
        if let existingEpisode = episode {
            episodeToSave = existingEpisode
        } else {
            // SwiftData init automatically copies defaults from podcast
            episodeToSave = Episode(
                title: trimmedTitle,
                episodeNumber: Int32(episodeNumber),
                podcast: podcast
            )
            modelContext.insert(episodeToSave)
        }
        
        episodeToSave.title = trimmedTitle
        episodeToSave.episodeNumber = Int32(episodeNumber)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
