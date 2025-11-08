import SwiftUI
import AppKit
import SwiftData

/// Form view for creating or editing a podcast
public struct PodcastFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Editing existing podcast (nil for new podcast)
    public let podcast: Podcast?
    
    // Form fields
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var artworkImage: NSImage?
    @State private var defaultOverlayImage: NSImage?
    @State private var defaultFontName: String = "Helvetica-Bold"
    @State private var defaultFontSize: Double = 72.0
    @State private var defaultTextPositionX: Double = 0.5
    @State private var defaultTextPositionY: Double = 0.5
    
    // UI state
    @State private var errorMessage: String?
    
    public init(podcast: Podcast? = nil) {
        self.podcast = podcast
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Podcast Name", text: $name)
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Artwork") {
                    if let artworkImage = artworkImage {
                        HStack {
                            Image(nsImage: artworkImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Artwork")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("Change Image") {
                                    selectArtworkImage()
                                }
                                .applyLiquidGlassButtonStyle(prominent: false)
                                Button("Remove") {
                                    self.artworkImage = nil
                                }
                                .applyLiquidGlassButtonStyle(prominent: false)
                                .foregroundColor(.red)
                            }
                        }
                    } else {
                        Button("Select Artwork Image") {
                            selectArtworkImage()
                        }
                        .applyLiquidGlassButtonStyle(prominent: false)
                    }
                }
                
                Section("Default Thumbnail Settings") {
                    Text("These settings will be copied to new episodes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let overlayImage = defaultOverlayImage {
                        HStack {
                            Image(nsImage: overlayImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Default Overlay")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button("Change Overlay") {
                                    selectOverlayImage()
                                }
                                .applyLiquidGlassButtonStyle(prominent: false)
                                Button("Remove") {
                                    self.defaultOverlayImage = nil
                                }
                                .applyLiquidGlassButtonStyle(prominent: false)
                                .foregroundColor(.red)
                            }
                        }
                    } else {
                        Button("Select Default Overlay (Optional)") {
                            selectOverlayImage()
                        }
                        .applyLiquidGlassButtonStyle(prominent: false)
                    }
                    
                    Picker("Default Font", selection: $defaultFontName) {
                        Text("Helvetica Bold").tag("Helvetica-Bold")
                        Text("Arial Bold").tag("Arial-BoldMT")
                        Text("Impact").tag("Impact")
                        Text("Futura Bold").tag("Futura-Bold")
                    }
                    
                    HStack {
                        Text("Font Size")
                        Spacer()
                        TextField("Size", value: $defaultFontSize, format: .number)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                        Stepper("", value: $defaultFontSize, in: 12...200, step: 4)
                            .labelsHidden()
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Text Position (X: \(defaultTextPositionX, specifier: "%.2f"), Y: \(defaultTextPositionY, specifier: "%.2f"))")
                        HStack {
                            Text("X:")
                            Slider(value: $defaultTextPositionX, in: 0...1)
                        }
                        HStack {
                            Text("Y:")
                            Slider(value: $defaultTextPositionY, in: 0...1)
                        }
                    }
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
            .navigationTitle(podcast == nil ? "New Podcast" : "Edit Podcast")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .applyLiquidGlassButtonStyle(prominent: false)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePodcast()
                    }
                    .applyLiquidGlassButtonStyle(prominent: true)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadExistingData()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    // MARK: - Data Loading
    
    private func loadExistingData() {
        guard let podcast = podcast else { return }
        
        name = podcast.name
        description = podcast.podcastDescription ?? ""
        defaultFontName = podcast.defaultFontName ?? "Helvetica-Bold"
        defaultFontSize = podcast.defaultFontSize
        defaultTextPositionX = podcast.defaultTextPositionX
        defaultTextPositionY = podcast.defaultTextPositionY
        
        if let artworkData = podcast.artworkData {
            artworkImage = ImageUtilities.loadImage(from: artworkData)
        }
        
        if let overlayData = podcast.defaultOverlayData {
            defaultOverlayImage = ImageUtilities.loadImage(from: overlayData)
        }
    }
    
    // MARK: - Image Selection
    
    private func selectArtworkImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Select podcast artwork"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let image = NSImage(contentsOf: url) {
                    self.artworkImage = image
                }
            }
        }
    }
    
    private func selectOverlayImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = "Select default overlay image"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                if let image = NSImage(contentsOf: url) {
                    self.defaultOverlayImage = image
                }
            }
        }
    }
    
    // MARK: - Save
    
    private func savePodcast() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Podcast name is required"
            return
        }
        
        let podcastToSave: Podcast
        if let existingPodcast = podcast {
            podcastToSave = existingPodcast
        } else {
            podcastToSave = Podcast(name: trimmedName)
            modelContext.insert(podcastToSave)
        }
        
        podcastToSave.name = trimmedName
        podcastToSave.podcastDescription = description.isEmpty ? nil : description
        podcastToSave.defaultFontName = defaultFontName
        podcastToSave.defaultFontSize = defaultFontSize
        podcastToSave.defaultTextPositionX = defaultTextPositionX
        podcastToSave.defaultTextPositionY = defaultTextPositionY
        
        // Process and save artwork
        if let artworkImage = artworkImage {
            podcastToSave.artworkData = ImageUtilities.processImageForStorage(artworkImage)
        } else {
            podcastToSave.artworkData = nil
        }
        
        // Process and save default overlay
        if let overlayImage = defaultOverlayImage {
            podcastToSave.defaultOverlayData = ImageUtilities.processImageForStorage(overlayImage)
        } else {
            podcastToSave.defaultOverlayData = nil
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

private extension View {
    @ViewBuilder
    func applyLiquidGlassButtonStyle(prominent: Bool) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent)
            } else {
                self.buttonStyle(.glass)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent)
            } else {
                self.buttonStyle(.bordered)
            }
        }
    }
}
