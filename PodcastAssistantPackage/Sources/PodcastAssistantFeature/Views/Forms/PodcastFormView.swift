import SwiftUI
import AppKit

/// Form for creating or editing a podcast
public struct PodcastFormView: View {
    @Environment(\.dismiss) private var dismiss
    
    let podcast: PodcastPOCO? // nil for new podcast
    let store: PodcastLibraryStore
    
    @State private var name: String = ""
    @State private var podcastDescription: String = ""
    @State private var artworkImage: NSImage?
    @State private var overlayImage: NSImage?
    @State private var selectedFontName: String?
    @State private var fontSize: Double = 72.0
    @State private var textPositionX: Double = 0.5
    @State private var textPositionY: Double = 0.5
    @State private var horizontalPadding: Double = 40.0
    @State private var verticalPadding: Double = 40.0
    @State private var canvasWidth: Double = 1920.0
    @State private var canvasHeight: Double = 1080.0
    @State private var backgroundScaling: String = "Aspect Fill (Crop)"
    @State private var fontColorHex: String = "#FFFFFF"
    @State private var outlineEnabled: Bool = true
    @State private var outlineColorHex: String = "#000000"
    @State private var errorMessage: String?
    @State private var selectedTab: FormTab = .basic
    
    private enum FormTab {
        case basic
        case artwork
        case thumbnailDefaults
    }
    
    public init(podcast: PodcastPOCO? = nil, store: PodcastLibraryStore) {
        self.podcast = podcast
        self.store = store
        
        // Initialize with existing values if editing
        if let podcast = podcast {
            _name = State(initialValue: podcast.name)
            _podcastDescription = State(initialValue: podcast.podcastDescription ?? "")
            _artworkImage = State(initialValue: podcast.artworkData.flatMap { ImageUtilities.loadImage(from: $0) })
            _overlayImage = State(initialValue: podcast.defaultOverlayData.flatMap { ImageUtilities.loadImage(from: $0) })
            _selectedFontName = State(initialValue: podcast.defaultFontName)
            _fontSize = State(initialValue: podcast.defaultFontSize)
            _textPositionX = State(initialValue: podcast.defaultTextPositionX)
            _textPositionY = State(initialValue: podcast.defaultTextPositionY)
            _horizontalPadding = State(initialValue: podcast.defaultHorizontalPadding)
            _verticalPadding = State(initialValue: podcast.defaultVerticalPadding)
            _canvasWidth = State(initialValue: podcast.defaultCanvasWidth)
            _canvasHeight = State(initialValue: podcast.defaultCanvasHeight)
            _backgroundScaling = State(initialValue: podcast.defaultBackgroundScaling)
            _fontColorHex = State(initialValue: podcast.defaultFontColorHex ?? "#FFFFFF")
            _outlineEnabled = State(initialValue: podcast.defaultOutlineEnabled)
            _outlineColorHex = State(initialValue: podcast.defaultOutlineColorHex ?? "#000000")
        }
    }
    
    private var isEditMode: Bool {
        podcast != nil
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text(isEditMode ? "Edit Podcast" : "New Podcast")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Configure your podcast settings and defaults")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
            
            // Tab selector
            Picker("", selection: $selectedTab) {
                Text("Basic Info").tag(FormTab.basic)
                Text("Artwork").tag(FormTab.artwork)
                Text("Thumbnail Defaults").tag(FormTab.thumbnailDefaults)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding()
            
            Divider()
            
            // Tab content
            ScrollView {
                Group {
                    switch selectedTab {
                    case .basic:
                        basicInfoTab
                    case .artwork:
                        artworkTab
                    case .thumbnailDefaults:
                        thumbnailDefaultsTab
                    }
                }
            }
            
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
                    savePodcast()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 650, height: 600)
    }
    
    // MARK: - Tab Views
    
    private var basicInfoTab: some View {
        Form {
            Section {
                Text("Enter your podcast's basic information")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            
            Section {
                TextField("Podcast Name", text: $name, prompt: Text("My Awesome Podcast"))
                    .textFieldStyle(.roundedBorder)
                
                TextField("Description (Optional)", text: $podcastDescription, prompt: Text("A brief description of your podcast"), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(4...8)
            } header: {
                Text("Basic Information")
            } footer: {
                Text("The podcast name will be used to organize your episodes")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding(24)
    }
    
    private var artworkTab: some View {
        Form {
            Section {
                Text("Add artwork to represent your podcast")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            
            Section {
                VStack(spacing: 16) {
                    if let image = artworkImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 200, height: 200)
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 48))
                                        .foregroundStyle(.secondary)
                                    Text("No Artwork")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    HStack(spacing: 12) {
                        Button("Select Artwork...") {
                            selectArtwork()
                        }
                        .buttonStyle(.bordered)
                        
                        if artworkImage != nil {
                            Button("Remove") {
                                artworkImage = nil
                            }
                            .foregroundStyle(.red)
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            } header: {
                Text("Podcast Artwork")
            } footer: {
                Text("Used for podcast identification. Will be resized and optimized for storage.")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding(24)
    }
    
    private var thumbnailDefaultsTab: some View {
        Form {
            Section {
                Text("Set default thumbnail settings for new episodes")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            
            Section {
                VStack(spacing: 16) {
                    if let image = overlayImage {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200, maxHeight: 200)
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 200, height: 200)
                            .overlay {
                                VStack {
                                    Image(systemName: "square.on.square")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                    Text("No Default Overlay")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                    }
                    
                    HStack(spacing: 12) {
                        Button("Select Default Overlay...") {
                            selectOverlay()
                        }
                        
                        if overlayImage != nil {
                            Button("Remove") {
                                overlayImage = nil
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("Default Thumbnail Overlay")
            } footer: {
                Text("Logo/branding to overlay on episode thumbnails. New episodes will use this by default.")
                    .font(.caption)
            }
            
            Section {
                Picker("Font", selection: $selectedFontName) {
                    Text("System Default").tag(nil as String?)
                    ForEach(NSFontManager.shared.availableFontFamilies.sorted(), id: \.self) { fontFamily in
                        Text(fontFamily).tag(fontFamily as String?)
                    }
                }
                
                LabeledContent("Font Size") {
                    HStack {
                        Slider(value: $fontSize, in: 12...200, step: 1)
                        Text("\(Int(fontSize))")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Text Settings")
            }
            
            Section {
                LabeledContent("Position X") {
                    HStack {
                        Slider(value: $textPositionX, in: 0...1, step: 0.01)
                        Text(String(format: "%.2f", textPositionX))
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
                
                LabeledContent("Position Y") {
                    HStack {
                        Slider(value: $textPositionY, in: 0...1, step: 0.01)
                        Text(String(format: "%.2f", textPositionY))
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Text Position")
            } footer: {
                Text("0.0 = top/left, 1.0 = bottom/right, 0.5 = center")
                    .font(.caption)
            }
            
            Section {
                LabeledContent("Horizontal") {
                    HStack {
                        Slider(value: $horizontalPadding, in: 0...200, step: 1)
                        Text("\(Int(horizontalPadding))")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
                
                LabeledContent("Vertical") {
                    HStack {
                        Slider(value: $verticalPadding, in: 0...200, step: 1)
                        Text("\(Int(verticalPadding))")
                            .frame(width: 40, alignment: .trailing)
                            .monospacedDigit()
                    }
                }
            } header: {
                Text("Text Padding")
            }
            
            Section {
                LabeledContent("Width") {
                    HStack {
                        TextField("Width", value: $canvasWidth, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                
                LabeledContent("Height") {
                    HStack {
                        TextField("Height", value: $canvasHeight, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                
                Picker("Background Scaling", selection: $backgroundScaling) {
                    ForEach(ThumbnailGenerator.BackgroundScaling.allCases) { scaling in
                        Text(scaling.rawValue).tag(scaling.rawValue)
                    }
                }
            } header: {
                Text("Canvas Settings")
            }
            
            Section {
                ColorPicker("Font Color", selection: Binding(
                    get: { Color(hex: fontColorHex) ?? .white },
                    set: { fontColorHex = $0.toHexString() }
                ))
                
                Toggle("Text Outline", isOn: $outlineEnabled)
                
                if outlineEnabled {
                    ColorPicker("Outline Color", selection: Binding(
                        get: { Color(hex: outlineColorHex) ?? .black },
                        set: { outlineColorHex = $0.toHexString() }
                    ))
                }
            } header: {
                Text("Color Settings")
            }
        }
        .formStyle(.grouped)
        .padding(24)
    }
    
    // MARK: - Image Selection
    
    private func selectArtwork() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.message = "Select podcast artwork"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let image = NSImage(contentsOf: url) {
                artworkImage = image
            }
        }
    }
    
    private func selectOverlay() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.message = "Select default thumbnail overlay"
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if let image = NSImage(contentsOf: url) {
                overlayImage = image
            }
        }
    }
    
    // MARK: - Save

    
    
    // MARK: - Save
    
    private func savePodcast() {
        do {
            // Process images
            let artworkData = artworkImage.flatMap { ImageUtilities.processImageForStorage($0) }
            let overlayData = overlayImage.flatMap { ImageUtilities.processImageForStorage($0) }
            
            if let existingPodcast = podcast {
                // Update existing podcast
                let updated = PodcastPOCO(
                    id: existingPodcast.id,
                    name: name,
                    podcastDescription: podcastDescription.isEmpty ? nil : podcastDescription,
                    artworkData: artworkData ?? existingPodcast.artworkData,
                    defaultOverlayData: overlayData ?? existingPodcast.defaultOverlayData,
                    defaultFontName: selectedFontName,
                    defaultFontSize: fontSize,
                    defaultTextPositionX: textPositionX,
                    defaultTextPositionY: textPositionY,
                    defaultHorizontalPadding: horizontalPadding,
                    defaultVerticalPadding: verticalPadding,
                    defaultCanvasWidth: canvasWidth,
                    defaultCanvasHeight: canvasHeight,
                    defaultBackgroundScaling: backgroundScaling,
                    defaultFontColorHex: fontColorHex,
                    defaultOutlineEnabled: outlineEnabled,
                    defaultOutlineColorHex: outlineColorHex,
                    createdAt: existingPodcast.createdAt
                )
                try store.updatePodcast(updated)
            } else {
                // Create new podcast
                let podcast = PodcastPOCO(
                    name: name,
                    podcastDescription: podcastDescription.isEmpty ? nil : podcastDescription,
                    artworkData: artworkData,
                    defaultOverlayData: overlayData,
                    defaultFontName: selectedFontName,
                    defaultFontSize: fontSize,
                    defaultTextPositionX: textPositionX,
                    defaultTextPositionY: textPositionY,
                    defaultHorizontalPadding: horizontalPadding,
                    defaultVerticalPadding: verticalPadding,
                    defaultCanvasWidth: canvasWidth,
                    defaultCanvasHeight: canvasHeight,
                    defaultBackgroundScaling: backgroundScaling,
                    defaultFontColorHex: fontColorHex,
                    defaultOutlineEnabled: outlineEnabled,
                    defaultOutlineColorHex: outlineColorHex
                )
                try store.addPodcast(podcast)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

