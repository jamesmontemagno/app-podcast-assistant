import SwiftUI
import SwiftData

/// Inline view for viewing and editing episode details
public struct EpisodeDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    let episode: Episode
    
    @State private var title: String = ""
    @State private var episodeNumber: Int = 1
    @State private var description: String = ""
    @State private var hasUnsavedChanges: Bool = false
    @State private var showingSaveConfirmation: Bool = false
    
    public init(episode: Episode) {
        self.episode = episode
    }
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Episode Information")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Edit episode details and metadata")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
                
                // Episode Title
                VStack(alignment: .leading, spacing: 8) {
                    Label("Episode Title", systemImage: "textformat")
                        .font(.headline)
                    
                    TextField("Enter episode title", text: $title, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .onChange(of: title) { _, _ in
                            hasUnsavedChanges = true
                        }
                }
                
                Divider()
                
                // Episode Number
                VStack(alignment: .leading, spacing: 8) {
                    Label("Episode Number", systemImage: "number")
                        .font(.headline)
                    
                    HStack {
                        TextField("Number", value: $episodeNumber, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .onChange(of: episodeNumber) { _, _ in
                                hasUnsavedChanges = true
                            }
                        
                        Stepper("", value: $episodeNumber, in: 1...9999)
                            .labelsHidden()
                        
                        Spacer()
                    }
                }
                
                Divider()
                
                // Episode Description
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Description", systemImage: "doc.text")
                            .font(.headline)
                        
                        Spacer()
                        
                        if let desc = episode.episodeDescription, !desc.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(desc.split(separator: " ").count) words")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    TextEditor(text: $description)
                        .font(.body)
                        .frame(minHeight: 200)
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                        .onChange(of: description) { _, _ in
                            hasUnsavedChanges = true
                        }
                    
                    if description.isEmpty {
                        Text("Add a description for this episode. You can also generate one using AI Ideas.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                // Podcast Association
                if let podcast = episode.podcast {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Podcast", systemImage: "mic")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            if let artworkData = podcast.artworkData,
                               let image = ImageUtilities.loadImage(from: artworkData) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(podcast.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                if let podcastDescription = podcast.podcastDescription {
                                    Text(podcastDescription)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                }
                
                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    Label("Metadata", systemImage: "info.circle")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Created:")
                                .foregroundStyle(.secondary)
                            Text(episode.createdAt, style: .date)
                            Text(episode.createdAt, style: .time)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Has Transcript:")
                                .foregroundStyle(.secondary)
                            Image(systemName: episode.transcriptInputText != nil ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(episode.transcriptInputText != nil ? .green : .secondary)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Has Thumbnail:")
                                .foregroundStyle(.secondary)
                            Image(systemName: episode.thumbnailOutputData != nil ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(episode.thumbnailOutputData != nil ? .green : .secondary)
                        }
                        .font(.caption)
                        
                        HStack {
                            Text("Has AI Description:")
                                .foregroundStyle(.secondary)
                            Image(systemName: episode.episodeDescription != nil ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(episode.episodeDescription != nil ? .green : .secondary)
                        }
                        .font(.caption)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                
                // Save confirmation
                if showingSaveConfirmation {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Changes saved")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding(12)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if hasUnsavedChanges {
                    Button(action: revertChanges) {
                        Label("Revert", systemImage: "arrow.uturn.backward")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .help("Discard changes")
                    
                    Button(action: saveChanges) {
                        Label("Save Changes", systemImage: "checkmark.circle.fill")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glassProminent)
                    .help("Save episode details")
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear {
            loadEpisodeData()
        }
    }
    
    // MARK: - Data Management
    
    private func loadEpisodeData() {
        title = episode.title
        episodeNumber = Int(episode.episodeNumber)
        description = episode.episodeDescription ?? ""
        hasUnsavedChanges = false
    }
    
    private func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        episode.title = trimmedTitle
        episode.episodeNumber = Int32(episodeNumber)
        episode.episodeDescription = description.isEmpty ? nil : description
        
        do {
            try modelContext.save()
            hasUnsavedChanges = false
            
            // Show save confirmation
            showingSaveConfirmation = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                showingSaveConfirmation = false
            }
        } catch {
            print("Error saving episode: \(error)")
        }
    }
    
    private func revertChanges() {
        loadEpisodeData()
    }
}
