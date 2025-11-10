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
    @State private var publishDate: Date = Date()
    
    // UI state
    @State private var errorMessage: String?
    
    public init(podcast: Podcast, episode: Episode? = nil) {
        self.podcast = podcast
        self.episode = episode
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: episode == nil ? "plus.circle.fill" : "pencil.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                Text(episode == nil ? "New Episode" : "Edit Episode")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(20)
            
            Divider()
            
            // Form content
            Form {
                Section("Episode Information") {
                    TextField("Episode Title", text: $title)
                    
                    HStack {
                        Text("Episode Number")
                        Spacer()
                        TextField("", value: $episodeNumber, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                        Stepper("", value: $episodeNumber, in: 1...9999)
                            .labelsHidden()
                    }
                    
                    DatePicker("Publish Date", selection: $publishDate, displayedComponents: [.date])
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
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            
            // Error message
            if let errorMessage = errorMessage {
                Divider()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.callout)
                    Spacer()
                }
                .padding(16)
                .background(Color.red.opacity(0.1))
            }
            
            // Action buttons at bottom
            Divider()
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    saveEpisode()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 450, idealWidth: 500, minHeight: 350, idealHeight: 400)
        .onAppear {
            loadExistingData()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadExistingData() {
        if let episode = episode {
            title = episode.title
            episodeNumber = Int(episode.episodeNumber)
            publishDate = episode.publishDate
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
        episodeToSave.publishDate = publishDate
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
