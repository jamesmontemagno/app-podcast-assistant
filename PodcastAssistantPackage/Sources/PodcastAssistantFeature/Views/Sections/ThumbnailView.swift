import SwiftUI
import SwiftData
import AppKit

// MARK: - Thumbnail Section

public struct ThumbnailView: View {
    let episode: Episode
    let podcast: Podcast
    @Binding var viewModel: ThumbnailViewModel?
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var previewZoom: CGFloat = 1.0
    @State private var fitToWindow: Bool = true
    
    public init(episode: Episode, podcast: Podcast, viewModel: Binding<ThumbnailViewModel?>) {
        self.episode = episode
        self.podcast = podcast
        self._viewModel = viewModel
    }
    
    public var body: some View {
        Group {
            if let viewModel = viewModel {
                contentView(viewModel: viewModel)
            } else {
                ProgressView("Loading...")
                    .onAppear {
                        self.viewModel = ThumbnailViewModel(episode: episode, modelContext: modelContext)
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
        LeftPanelContent(viewModel: viewModel, width: width)
    }
    
    @ViewBuilder
    private func rightPanel(viewModel: ThumbnailViewModel, width: CGFloat) -> some View {
        RightPanelContent(viewModel: viewModel, width: width, previewZoom: $previewZoom, fitToWindow: $fitToWindow)
    }
}

// MARK: - Left Panel Content
private struct LeftPanelContent: View {
    @ObservedObject var viewModel: ThumbnailViewModel
    let width: CGFloat
    @State private var showRemoveOverlayConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                imagesSection
                canvasSection
                textStylingSection
                messagesSection
            }
            .padding(20)
        }
        .frame(width: width)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var imagesSection: some View {
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
                        Button {
                            showRemoveOverlayConfirmation = true
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        .confirmationDialog(
                            "Are you sure you want to remove the overlay image?",
                            isPresented: $showRemoveOverlayConfirmation,
                            titleVisibility: .visible
                        ) {
                            Button("Remove Overlay", role: .destructive) {
                                viewModel.removeOverlayImage()
                            }
                            Button("Cancel", role: .cancel) { }
                        }
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
    private var canvasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Canvas")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Resolution", selection: $viewModel.selectedResolution) {
                    ForEach(ThumbnailGenerator.CanvasResolution.allCases) { resolution in
                        Text(resolution.rawValue).tag(resolution)
                    }
                }
                .labelsHidden()
                
                if viewModel.selectedResolution == .custom {
                    HStack(spacing: 8) {
                        TextField("Width", text: $viewModel.customWidth)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        Text("×")
                            .foregroundStyle(.secondary)
                        TextField("Height", text: $viewModel.customHeight)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                }
                
                Text("Background Scaling")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Scaling", selection: $viewModel.backgroundScaling) {
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
    private var textStylingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Text & Styling")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Episode Number")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("e.g., EP 42 or 42", text: $viewModel.episodeNumber)
                        .textFieldStyle(.roundedBorder)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Font", selection: $viewModel.selectedFont) {
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
                    Slider(value: $viewModel.fontSize, in: 24...200, step: 4, onEditingChanged: { editing in
                        if !editing {
                            viewModel.onSliderEditingEnded()
                        }
                    })
                }
                
                Divider()
                
                HStack {
                    Text("Font Color")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    ColorPicker("", selection: $viewModel.fontColor, supportsOpacity: false)
                        .labelsHidden()
                }
                
                Toggle(isOn: $viewModel.outlineEnabled) {
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
                        ColorPicker("", selection: $viewModel.outlineColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                    .padding(.leading, 8)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Position", selection: $viewModel.episodeNumberPosition) {
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
                    Slider(value: $viewModel.horizontalPadding, in: 0...200, step: 5, onEditingChanged: { editing in
                        if !editing {
                            viewModel.onSliderEditingEnded()
                        }
                    })
                    
                    HStack {
                        Text("V-Padding")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(viewModel.verticalPadding))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $viewModel.verticalPadding, in: 0...200, step: 5, onEditingChanged: { editing in
                        if !editing {
                            viewModel.onSliderEditingEnded()
                        }
                    })
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private var messagesSection: some View {
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

// MARK: - Right Panel Content
private struct RightPanelContent: View {
    @ObservedObject var viewModel: ThumbnailViewModel
    let width: CGFloat
    @Binding var previewZoom: CGFloat
    @Binding var fitToWindow: Bool
    
    var body: some View {
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
}
