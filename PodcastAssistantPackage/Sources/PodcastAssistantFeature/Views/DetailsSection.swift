import SwiftUI
import AppKit

// MARK: - Details Section

/// Simple class to expose save/revert methods to parent
class DetailsViewModel {
    var save: () -> Void = {}
    var revert: () -> Void = {}
}

struct DetailsSection: View {
    let episode: EpisodePOCO
    let podcast: PodcastPOCO
    let store: PodcastLibraryStore
    @Binding var hasUnsavedChanges: Bool
    @Binding var viewModel: DetailsViewModel?
    
    @State private var title: String = ""
    @State private var episodeNumber: String = ""
    @State private var description: String = ""
    @State private var publishDate: Date = Date()
    @State private var showingSaveConfirmation: Bool = false
    @State private var isInitialLoad: Bool = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Basic Information Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Basic Information")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    // Episode Title
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Title", systemImage: "textformat")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        TextField("Enter episode title", text: $title, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...4)
                            .onChange(of: title) { oldValue, newValue in
                                if isInitialLoad { return }
                                hasUnsavedChanges = true
                            }
                    }
                    
                    // Episode Number and Release Date (side by side)
                    HStack(spacing: 16) {
                        // Episode Number
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Episode Number", systemImage: "number")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            TextField("Number", text: $episodeNumber)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .onChange(of: episodeNumber) { _, _ in
                                    if isInitialLoad { return }
                                    hasUnsavedChanges = true
                                }
                        }
                        
                        // Release Date
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Release Date", systemImage: "calendar")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            DatePicker("", selection: $publishDate, displayedComponents: [.date])
                                .datePickerStyle(.compact)
                                .onChange(of: publishDate) { _, _ in
                                    if isInitialLoad { return }
                                    hasUnsavedChanges = true
                                }
                        }
                        
                        Spacer()
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                // Episode Description Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Description")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        if !description.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                Text("\(description.split(separator: " ").count) words")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
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
                            if isInitialLoad { return }
                            hasUnsavedChanges = true
                        }
                    
                    if description.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.blue)
                            Text("Add a description for this episode. You can also generate one using the AI Ideas tab.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                // Podcast Association Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Podcast")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        if let artworkData = podcast.artworkData,
                           let image = ImageUtilities.loadImage(from: artworkData) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(podcast.name)
                                .font(.headline)
                            
                            if let podcastDescription = podcast.podcastDescription {
                                Text(podcastDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                // Episode Status Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Episode Status")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 12) {
                        // Status items in a grid-like layout
                        HStack(spacing: 20) {
                            StatusBadge(
                                icon: "doc.text",
                                title: "Transcript",
                                isComplete: episode.hasTranscriptData
                            )
                            
                            StatusBadge(
                                icon: "photo",
                                title: "Thumbnail",
                                isComplete: episode.thumbnailOutputData != nil
                            )
                            
                            StatusBadge(
                                icon: "text.quote",
                                title: "Description",
                                isComplete: episode.episodeDescription != nil && !episode.episodeDescription!.isEmpty
                            )
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Metadata
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            Text("Created:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(episode.createdAt, style: .date)
                                .font(.caption)
                            Text(episode.createdAt, style: .time)
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                // Save confirmation
                if showingSaveConfirmation {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Changes saved successfully")
                            .font(.subheadline)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(16)
        }
        .onAppear {
            loadEpisodeData()
            
            // Register save/revert handlers with parent
            let vm = DetailsViewModel()
            vm.save = saveChanges
            vm.revert = revertChanges
            viewModel = vm
        }
    }
    
    // MARK: - Data Management
    
    private func loadEpisodeData() {
        isInitialLoad = true
        title = episode.title
        episodeNumber = "\(episode.episodeNumber)"
        description = episode.episodeDescription ?? ""
        publishDate = episode.publishDate
        hasUnsavedChanges = false
        
        // Small delay to ensure state is settled before tracking changes
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            isInitialLoad = false
        }
    }
    
    func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        guard let number = Int32(episodeNumber) else {
            return
        }
        
        // Update episode (it's a class, so we can modify directly)
        episode.title = trimmedTitle
        episode.episodeNumber = number
        episode.episodeDescription = description.isEmpty ? nil : description
        episode.publishDate = publishDate
        
        do {
            try store.updateEpisode(episode)
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
    
    func revertChanges() {
        loadEpisodeData()
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let icon: String
    let title: String
    let isComplete: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green.opacity(0.15) : Color(NSColor.separatorColor).opacity(0.3))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .foregroundStyle(isComplete ? .green : .secondary)
                    .font(.title3)
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.caption2)
                        .foregroundStyle(isComplete ? .green : .secondary)
                    Text(isComplete ? "Ready" : "Pending")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 80)
    }
}
