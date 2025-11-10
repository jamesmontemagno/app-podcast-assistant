import SwiftUI

/// Form for creating or editing an episode
public struct EpisodeFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    let episode: EpisodePOCO? // nil for new episode
    let podcast: PodcastPOCO
    let store: PodcastLibraryStore
    
    @State private var title: String = ""
    @State private var episodeNumber: String = ""
    @State private var episodeDescription: String = ""
    @State private var publishDate: Date = Date()
    @State private var errorMessage: String?
    
    public init(episode: EpisodePOCO? = nil, podcast: PodcastPOCO, store: PodcastLibraryStore) {
        self.episode = episode
        self.podcast = podcast
        self.store = store
        
        if let episode = episode {
            // Editing existing episode
            _title = State(initialValue: episode.title)
            _episodeNumber = State(initialValue: "\(episode.episodeNumber)")
            _episodeDescription = State(initialValue: episode.episodeDescription ?? "")
            _publishDate = State(initialValue: episode.publishDate)
        } else {
            // Creating new episode - auto-suggest next episode number
            let existingEpisodes = store.getEpisodes(for: podcast.id)
            if let maxNumber = existingEpisodes.map(\.episodeNumber).max() {
                _episodeNumber = State(initialValue: "\(maxNumber + 1)")
            } else {
                _episodeNumber = State(initialValue: "1")
            }
        }
    }
    
    private var isEditMode: Bool {
        episode != nil
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text(isEditMode ? "Edit Episode" : "New Episode")
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 4) {
                    Text("Podcast:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(podcast.name)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
            
            // Form content
            Form {
                Section {
                    Text("Enter the episode details")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                
                Section {
                    TextField("Episode Title", text: $title, prompt: Text("Episode 1: Introduction"))
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Episode Number", text: $episodeNumber, prompt: Text("1"))
                        .textFieldStyle(.roundedBorder)
                    
                    DatePicker("Release Date", selection: $publishDate, displayedComponents: [.date])
                    
                    TextField("Description (Optional)", text: $episodeDescription, prompt: Text("A brief summary of this episode"), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                } header: {
                    Text("Episode Information")
                } footer: {
                    Text("Episode number is used for sorting and display")
                        .font(.caption)
                }
            }
            .formStyle(.grouped)
            .padding(24)
            
            // Error message
            if let error = errorMessage {
                Divider()
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.callout)
                    Spacer()
                }
                .padding(16)
                .background(Color.red.opacity(0.1))
            }
            
            Divider()
            
            // Bottom buttons
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(isEditMode ? "Save" : "Create") {
                    saveEpisode()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty || episodeNumber.isEmpty)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 450)
    }
    
    private func saveEpisode() {
        guard let number = Int32(episodeNumber) else {
            errorMessage = "Episode number must be a valid number"
            return
        }
        
        do {
            if let existingEpisode = episode {
                // Update existing episode
                let updated = EpisodePOCO(
                    id: existingEpisode.id,
                    podcastID: podcast.id,
                    title: title,
                    episodeNumber: number,
                    podcast: podcast,
                    episodeDescription: episodeDescription.isEmpty ? nil : episodeDescription,
                    transcriptInputText: existingEpisode.transcriptInputText,
                    srtOutputText: existingEpisode.srtOutputText,
                    createdAt: existingEpisode.createdAt,
                    publishDate: publishDate,
                    thumbnailBackgroundData: existingEpisode.thumbnailBackgroundData,
                    thumbnailOverlayData: existingEpisode.thumbnailOverlayData,
                    thumbnailOutputData: existingEpisode.thumbnailOutputData,
                    fontName: existingEpisode.fontName,
                    fontSize: existingEpisode.fontSize,
                    textPositionX: existingEpisode.textPositionX,
                    textPositionY: existingEpisode.textPositionY,
                    horizontalPadding: existingEpisode.horizontalPadding,
                    verticalPadding: existingEpisode.verticalPadding,
                    canvasWidth: existingEpisode.canvasWidth,
                    canvasHeight: existingEpisode.canvasHeight,
                    backgroundScaling: existingEpisode.backgroundScaling,
                    fontColorHex: existingEpisode.fontColorHex,
                    outlineEnabled: existingEpisode.outlineEnabled,
                    outlineColorHex: existingEpisode.outlineColorHex
                )
                try store.updateEpisode(updated)
            } else {
                // Create new episode
                let newEpisode = EpisodePOCO(
                    podcastID: podcast.id,
                    title: title,
                    episodeNumber: number,
                    podcast: podcast,
                    episodeDescription: episodeDescription.isEmpty ? nil : episodeDescription,
                    publishDate: publishDate
                )
                try store.addEpisode(newEpisode, to: podcast)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
