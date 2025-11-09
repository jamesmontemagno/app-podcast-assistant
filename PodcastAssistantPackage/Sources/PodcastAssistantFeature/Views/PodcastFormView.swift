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
    @State private var defaultTextPosition: ThumbnailGenerator.TextPosition = .topRight
    @State private var defaultHorizontalPadding: Double = 40.0
    @State private var defaultVerticalPadding: Double = 40.0
    @State private var defaultCanvasResolution: ThumbnailGenerator.CanvasResolution = .hd1080
    @State private var defaultCustomWidth: String = "1920"
    @State private var defaultCustomHeight: String = "1080"
    @State private var defaultBackgroundScaling: ThumbnailGenerator.BackgroundScaling = .aspectFill
    @State private var defaultFontColor: Color = .white
    @State private var defaultOutlineEnabled: Bool = true
    @State private var defaultOutlineColor: Color = .black
    
    // UI state
    @State private var errorMessage: String?
    @State private var selectedTab: FormTab = .basicInfo
    
    private enum FormTab: String, CaseIterable {
        case basicInfo = "Basic Info"
        case thumbnailDefaults = "Thumbnail Defaults"
    }
    
    public init(podcast: Podcast? = nil) {
        self.podcast = podcast
    }
    
    private var isEditMode: Bool {
        podcast != nil
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("", selection: $selectedTab) {
                    ForEach(FormTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                // Tab Content
                Group {
                    switch selectedTab {
                    case .basicInfo:
                        basicInfoTab
                    case .thumbnailDefaults:
                        thumbnailDefaultsTab
                    }
                }
                
                if let errorMessage = errorMessage {
                    Divider()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                }
            }
            .navigationTitle(podcast == nil ? "New Podcast" : "Edit Podcast")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .applyLiquidGlassButtonStyle(prominent: false)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditMode ? "Save" : "Create") {
                        savePodcast()
                    }
                    .applyLiquidGlassButtonStyle(prominent: false)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadExistingData()
            }
        }
        .frame(minWidth: 600, idealWidth: 650, minHeight: 600, idealHeight: 650)
    }
    
    // MARK: - Tab Views
    
    private var basicInfoTab: some View {
        Form {
            Section {
                TextField("Podcast Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Description (optional)", text: $description, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)
            } header: {
                Text("Information")
                    .font(.headline)
            }
            
            Section {
                if let artworkImage = artworkImage {
                    HStack(spacing: 16) {
                        Image(nsImage: artworkImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .cornerRadius(8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Artwork")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Button("Change") {
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
                    }
                } else {
                    Button("Select Artwork Image") {
                        selectArtworkImage()
                    }
                    .applyLiquidGlassButtonStyle(prominent: false)
                }
            } header: {
                Text("Podcast Artwork")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    
    private var thumbnailDefaultsTab: some View {
        Form {
            Section {
                Text("These settings will be copied to new episodes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section {
                if let overlayImage = defaultOverlayImage {
                    HStack(spacing: 16) {
                        Image(nsImage: overlayImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .cornerRadius(6)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Default Overlay")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                Button("Change") {
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
                    }
                } else {
                    Button("Select Default Overlay (Optional)") {
                        selectOverlayImage()
                    }
                    .applyLiquidGlassButtonStyle(prominent: false)
                }
            } header: {
                Text("Images")
                    .font(.headline)
            }
            
            Section {
                Picker("Resolution", selection: $defaultCanvasResolution) {
                    ForEach(ThumbnailGenerator.CanvasResolution.allCases) { resolution in
                        Text(resolution.rawValue).tag(resolution)
                    }
                }
                
                if defaultCanvasResolution == .custom {
                    HStack {
                        TextField("Width", text: $defaultCustomWidth)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                        Text("×")
                        TextField("Height", text: $defaultCustomHeight)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }
                
                Picker("Background Scaling", selection: $defaultBackgroundScaling) {
                    ForEach(ThumbnailGenerator.BackgroundScaling.allCases) { scaling in
                        Text(scaling.rawValue).tag(scaling)
                    }
                }
            } header: {
                Text("Canvas")
                    .font(.headline)
            }
            
            Section {
                Picker("Font", selection: $defaultFontName) {
                    Text("Helvetica Bold").tag("Helvetica-Bold")
                    Text("Arial Bold").tag("Arial-BoldMT")
                    Text("Impact").tag("Impact")
                    Text("Futura Bold").tag("Futura-Bold")
                    Text("Menlo Bold").tag("Menlo-Bold")
                    Text("Avenir Next Bold").tag("AvenirNext-Bold")
                    Text("Gill Sans Bold").tag("GillSans-Bold")
                }
                
                HStack {
                    Text("Size")
                    Spacer()
                    Text("\(Int(defaultFontSize))")
                        .foregroundColor(.secondary)
                    Slider(value: $defaultFontSize, in: 24...200, step: 4)
                        .frame(width: 300)
                }
            } header: {
                Text("Typography")
                    .font(.headline)
            }
            
            Section {
                HStack {
                    Text("Font Color")
                    Spacer()
                    ColorPicker("", selection: $defaultFontColor, supportsOpacity: false)
                        .labelsHidden()
                }
                
                Toggle("Outline", isOn: $defaultOutlineEnabled)
                
                if defaultOutlineEnabled {
                    HStack {
                        Text("Outline Color")
                        Spacer()
                        ColorPicker("", selection: $defaultOutlineColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                    .padding(.leading, 16)
                }
            } header: {
                Text("Colors")
                    .font(.headline)
            }
            
            Section {
                Picker("Position", selection: $defaultTextPosition) {
                    ForEach(ThumbnailGenerator.TextPosition.allCases) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                
                HStack {
                    Text("Horizontal Padding")
                    Spacer()
                    Text("\(Int(defaultHorizontalPadding))")
                        .foregroundColor(.secondary)
                    Slider(value: $defaultHorizontalPadding, in: 0...200, step: 5)
                        .frame(width: 300)
                }
                
                HStack {
                    Text("Vertical Padding")
                    Spacer()
                    Text("\(Int(defaultVerticalPadding))")
                        .foregroundColor(.secondary)
                    Slider(value: $defaultVerticalPadding, in: 0...200, step: 5)
                        .frame(width: 300)
                }
            } header: {
                Text("Layout")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Data Loading
    
    private func loadExistingData() {
        guard let podcast = podcast else { return }
        
        name = podcast.name
        description = podcast.podcastDescription ?? ""
        defaultFontName = podcast.defaultFontName ?? "Helvetica-Bold"
        defaultFontSize = podcast.defaultFontSize
        defaultTextPosition = ThumbnailGenerator.TextPosition.fromRelativePosition(
            x: podcast.defaultTextPositionX,
            y: podcast.defaultTextPositionY
        )
        defaultHorizontalPadding = podcast.defaultHorizontalPadding
        defaultVerticalPadding = podcast.defaultVerticalPadding
        
        // Canvas settings
        let canvasSize = NSSize(width: podcast.defaultCanvasWidth, height: podcast.defaultCanvasHeight)
        if canvasSize == ThumbnailGenerator.CanvasResolution.hd1080.size {
            defaultCanvasResolution = .hd1080
        } else if canvasSize == ThumbnailGenerator.CanvasResolution.hd720.size {
            defaultCanvasResolution = .hd720
        } else if canvasSize == ThumbnailGenerator.CanvasResolution.uhd4k.size {
            defaultCanvasResolution = .uhd4k
        } else if canvasSize == ThumbnailGenerator.CanvasResolution.square1080.size {
            defaultCanvasResolution = .square1080
        } else {
            defaultCanvasResolution = .custom
            defaultCustomWidth = "\(Int(podcast.defaultCanvasWidth))"
            defaultCustomHeight = "\(Int(podcast.defaultCanvasHeight))"
        }
        
        defaultBackgroundScaling = ThumbnailGenerator.BackgroundScaling.allCases.first {
            $0.rawValue == podcast.defaultBackgroundScaling
        } ?? .aspectFill
        
        // Colors
        if let hex = podcast.defaultFontColorHex, let color = Color(hex: hex) {
            defaultFontColor = color
        }
        defaultOutlineEnabled = podcast.defaultOutlineEnabled
        if let hex = podcast.defaultOutlineColorHex, let color = Color(hex: hex) {
            defaultOutlineColor = color
        }
        
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
        podcastToSave.defaultTextPositionX = defaultTextPosition.relativePosition.x
        podcastToSave.defaultTextPositionY = defaultTextPosition.relativePosition.y
        podcastToSave.defaultHorizontalPadding = defaultHorizontalPadding
        podcastToSave.defaultVerticalPadding = defaultVerticalPadding
        
        // Canvas settings
        if defaultCanvasResolution == .custom {
            if let width = Double(defaultCustomWidth), let height = Double(defaultCustomHeight) {
                podcastToSave.defaultCanvasWidth = width
                podcastToSave.defaultCanvasHeight = height
            } else {
                podcastToSave.defaultCanvasWidth = 1920
                podcastToSave.defaultCanvasHeight = 1080
            }
        } else {
            let size = defaultCanvasResolution.size
            podcastToSave.defaultCanvasWidth = size.width
            podcastToSave.defaultCanvasHeight = size.height
        }
        podcastToSave.defaultBackgroundScaling = defaultBackgroundScaling.rawValue
        
        // Colors
        podcastToSave.defaultFontColorHex = defaultFontColor.toHexString()
        podcastToSave.defaultOutlineEnabled = defaultOutlineEnabled
        podcastToSave.defaultOutlineColorHex = defaultOutlineColor.toHexString()
        
        // Process and save artwork
        if let artworkImage = artworkImage {
            podcastToSave.artworkData = ImageUtilities.processImageForStorage(artworkImage)
        } else {
            podcastToSave.artworkData = nil
        }
        
        // Process and save default overlay
        if let overlayImage = defaultOverlayImage {
            // Preserve transparency for overlay images (save as PNG instead of JPEG)
            podcastToSave.defaultOverlayData = ImageUtilities.processImageForStorage(overlayImage, preserveTransparency: true)
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
