import SwiftUI
import AppKit

// MARK: - Thumbnail Section

struct ThumbnailView: View {
    let episode: EpisodePOCO
    let podcast: PodcastPOCO
    let store: PodcastLibraryStore
    @Binding var viewModel: ThumbnailViewModel?
    
    @State private var previewZoom: CGFloat = 1.0
    @State private var fitToWindow: Bool = true
    
    init(episode: EpisodePOCO, podcast: PodcastPOCO, store: PodcastLibraryStore, viewModel: Binding<ThumbnailViewModel?>) {
        self.episode = episode
        self.podcast = podcast
        self.store = store
        self._viewModel = viewModel
    }
    
    var body: some View {
        Group {
            if let viewModel = viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        self.viewModel = ThumbnailViewModel(episode: episode, store: store)
                    }
            }
        }
    }
    
    @ViewBuilder
    private func contentView(viewModel: ThumbnailViewModel) -> some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width - 48
            let leftWidth = totalWidth * 0.35
            let rightWidth = totalWidth * 0.65
            
            HStack(spacing: 16) {
                // Left Panel - Controls
                leftPanel(viewModel: viewModel, width: leftWidth)
                
                // Right Panel - Preview
                rightPanel(viewModel: viewModel, width: rightWidth)
            }
            .padding(16)
        }
        .onAppear {
            viewModel.loadInitialData()
        }
    }
    
    @ViewBuilder
    private func leftPanel(viewModel: ThumbnailViewModel, width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                imagesSection(viewModel: viewModel)
                canvasSection(viewModel: viewModel)
                textStylingSection(viewModel: viewModel)
                messagesSection(viewModel: viewModel)
            }
            .padding(20)
        }
        .frame(width: width)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func rightPanel(viewModel: ThumbnailViewModel, width: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preview")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.generatedThumbnail != nil {
                    HStack(spacing: 8) {
                        Button {
                            fitToWindow.toggle()
                            if fitToWindow {
                                previewZoom = 1.0
                            }
                        } label: {
                            Image(systemName: fitToWindow ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        }
                        .buttonStyle(.borderless)
                        .help(fitToWindow ? "Manual zoom" : "Fit to window")
                        
                        if !fitToWindow {
                            Button {
                                previewZoom = max(0.25, previewZoom - 0.25)
                            } label: {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            .buttonStyle(.borderless)
                            
                            Text("\(Int(previewZoom * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button {
                                previewZoom = min(4.0, previewZoom + 0.25)
                            } label: {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    
                    Text("•")
                        .foregroundStyle(.secondary)
                    
                    if let thumbnail = viewModel.generatedThumbnail {
                        Text("\(Int(thumbnail.size.width)) × \(Int(thumbnail.size.height))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Preview content
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Generating thumbnail...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.05))
            } else if let thumbnail = viewModel.generatedThumbnail {
                if fitToWindow {
                    GeometryReader { geo in
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                    .background(Color.black.opacity(0.05))
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .frame(width: thumbnail.size.width * previewZoom, height: thumbnail.size.height * previewZoom)
                    }
                    .background(Color.black.opacity(0.05))
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Generated thumbnail will appear here")
                        .foregroundColor(.secondary)
                    Text("Select a background image and tap Generate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.05))
            }
        }
        .frame(width: width)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private func imagesSection(viewModel: ThumbnailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Images")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Background Image")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Button(action: viewModel.importBackgroundImage) {
                        Label(viewModel.backgroundImage == nil ? "Select" : "Change", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: viewModel.pasteBackgroundFromClipboard) {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                }
                
                if viewModel.backgroundImage != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Background loaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Overlay Image (Optional)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Button(action: viewModel.importOverlayImage) {
                        Label(viewModel.overlayImage == nil ? "Select" : "Change", systemImage: "square.on.square")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: viewModel.pasteOverlayFromClipboard) {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    
                    if viewModel.overlayImage != nil {
                        Button(action: viewModel.removeOverlayImage) {
                            Label("Remove", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                }
                
                if viewModel.overlayImage != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Overlay loaded")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func canvasSection(viewModel: ThumbnailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Canvas")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Resolution", selection: Binding(get: { viewModel.selectedResolution }, set: { viewModel.selectedResolution = $0 })) {
                    ForEach(ThumbnailGenerator.CanvasResolution.allCases) { resolution in
                        Text(resolution.rawValue).tag(resolution)
                    }
                }
                .labelsHidden()
                
                if viewModel.selectedResolution == .custom {
                    HStack(spacing: 8) {
                        TextField("Width", text: Binding(get: { viewModel.customWidth }, set: { viewModel.customWidth = $0 }))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("×")
                            .foregroundStyle(.secondary)
                        TextField("Height", text: Binding(get: { viewModel.customHeight }, set: { viewModel.customHeight = $0 }))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                
                Text("Background Scaling")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Scaling", selection: Binding(get: { viewModel.backgroundScaling }, set: { viewModel.backgroundScaling = $0 })) {
                    ForEach(ThumbnailGenerator.BackgroundScaling.allCases) { scaling in
                        Text(scaling.rawValue).tag(scaling)
                    }
                }
                .labelsHidden()
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func textStylingSection(viewModel: ThumbnailViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text & Styling")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Episode Number")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g., EP 42 or 42", text: Binding(get: { viewModel.episodeNumber }, set: { viewModel.episodeNumber = $0 }))
                        .textFieldStyle(.roundedBorder)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Font", selection: Binding(get: { viewModel.selectedFont }, set: { viewModel.selectedFont = $0 })) {
                        ForEach(viewModel.availableFonts, id: \.self) { font in
                            Text(font.replacingOccurrences(of: "-Bold", with: ""))
                                .tag(font)
                        }
                    }
                    .labelsHidden()
                    
                    HStack {
                        Text("Size")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(viewModel.fontSize))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(get: { viewModel.fontSize }, set: { viewModel.fontSize = $0 }), in: 24...200, step: 4)
                }
                
                Divider()
                
                HStack {
                    Text("Font Color")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ColorPicker("", selection: Binding(get: { viewModel.fontColor }, set: { viewModel.fontColor = $0 }), supportsOpacity: false)
                        .labelsHidden()
                }
                
                Toggle(isOn: Binding(get: { viewModel.outlineEnabled }, set: { viewModel.outlineEnabled = $0 })) {
                    Text("Outline")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if viewModel.outlineEnabled {
                    HStack {
                        Text("Outline Color")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        ColorPicker("", selection: Binding(get: { viewModel.outlineColor }, set: { viewModel.outlineColor = $0 }), supportsOpacity: false)
                            .labelsHidden()
                    }
                    .padding(.leading, 8)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Position", selection: Binding(get: { viewModel.episodeNumberPosition }, set: { viewModel.episodeNumberPosition = $0 })) {
                        ForEach(ThumbnailGenerator.TextPosition.allCases) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .labelsHidden()
                    
                    HStack {
                        Text("H-Padding")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(viewModel.horizontalPadding))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(get: { viewModel.horizontalPadding }, set: { viewModel.horizontalPadding = $0 }), in: 0...200, step: 5)
                    
                    HStack {
                        Text("V-Padding")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(viewModel.verticalPadding))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: Binding(get: { viewModel.verticalPadding }, set: { viewModel.verticalPadding = $0 }), in: 0...200, step: 5)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func messagesSection(viewModel: ThumbnailViewModel) -> some View {
        Group {
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let success = viewModel.successMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(success)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}
