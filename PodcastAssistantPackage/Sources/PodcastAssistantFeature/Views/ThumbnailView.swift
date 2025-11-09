import SwiftUI
import SwiftData

/// View for generating podcast thumbnails
public struct ThumbnailView: View {
    @Environment(\.modelContext) private var modelContext
    let episode: Episode
    @StateObject private var viewModel: ThumbnailViewModel
    @State private var previewZoom: CGFloat = 1.0
    @State private var fitToWindow: Bool = true
    
    public init(episode: Episode) {
        self.episode = episode
        _viewModel = StateObject(wrappedValue: ThumbnailViewModel(
            episode: episode,
            context: PersistenceController.shared.container.mainContext
        ))
    }
    
    public var body: some View {
        GeometryReader { geometry in
            HSplitView {
                // Left Panel - Controls (30% of width, min 280, max 350)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Images Section
                        GroupBox(label: Label("Images", systemImage: "photo")) {
                            VStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Background Image")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack(spacing: 6) {
                                        Button(action: viewModel.importBackgroundImage) {
                                            Label(viewModel.backgroundImage == nil ? "Select" : "Change", systemImage: "photo")
                                        }
                                        .buttonStyle(.glass)
                                        
                                        Button(action: viewModel.pasteBackgroundFromClipboard) {
                                            Label("Paste", systemImage: "doc.on.clipboard")
                                        }
                                        .buttonStyle(.glass)
                                    }
                                    
                                    if viewModel.backgroundImage != nil {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Background loaded")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Overlay Image (Optional)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack(spacing: 6) {
                                        Button(action: viewModel.importOverlayImage) {
                                            Label(viewModel.overlayImage == nil ? "Select" : "Change", systemImage: "square.on.square")
                                        }
                                        .buttonStyle(.glass)
                                        
                                        Button(action: viewModel.pasteOverlayFromClipboard) {
                                            Label("Paste", systemImage: "doc.on.clipboard")
                                        }
                                        .buttonStyle(.glass)
                                        
                                        if viewModel.overlayImage != nil {
                                            Button(action: viewModel.removeOverlayImage) {
                                                Label("Remove", systemImage: "trash")
                                            }
                                            .buttonStyle(.glass)
                                            .foregroundColor(.red)
                                        }
                                    }
                                    
                                    if viewModel.overlayImage != nil {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Overlay loaded")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        
                        // Canvas Settings Section
                        GroupBox(label: Label("Canvas", systemImage: "rectangle.dashed")) {
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Resolution")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Picker("Resolution", selection: $viewModel.selectedResolution) {
                                        ForEach(ThumbnailGenerator.CanvasResolution.allCases) { resolution in
                                            Text(resolution.rawValue).tag(resolution)
                                        }
                                    }
                                    .labelsHidden()
                                }
                                
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
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Background Scaling")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Picker("Scaling", selection: $viewModel.backgroundScaling) {
                                        ForEach(ThumbnailGenerator.BackgroundScaling.allCases) { scaling in
                                            Text(scaling.rawValue).tag(scaling)
                                        }
                                    }
                                    .labelsHidden()
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        
                        // Text & Styling Section
                        GroupBox(label: Label("Text & Styling", systemImage: "textformat")) {
                            VStack(alignment: .leading, spacing: 12) {
                                // Episode Number
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Episode Number")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("e.g., EP 42 or 42", text: $viewModel.episodeNumber)
                                        .textFieldStyle(.roundedBorder)
                                }
                                
                                Divider()
                                
                                // Typography Section
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Typography")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Font")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Picker("Font", selection: $viewModel.selectedFont) {
                                            ForEach(viewModel.availableFonts, id: \.self) { font in
                                                Text(font.replacingOccurrences(of: "-Bold", with: ""))
                                                    .tag(font)
                                            }
                                        }
                                        .labelsHidden()
                                        
                                        Button(action: viewModel.loadCustomFont) {
                                            Label("Load Custom Font", systemImage: "plus.circle")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.glass)
                                        .help("Load a custom .ttf or .otf font file")
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Size")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text("\(Int(viewModel.fontSize))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Slider(value: $viewModel.fontSize, in: 24...200, step: 4)
                                    }
                                }
                                
                                Divider()
                                
                                // Colors Section
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Colors")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                    
                                    HStack {
                                        Text("Font Color")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        ColorPicker("", selection: $viewModel.fontColor, supportsOpacity: false)
                                            .labelsHidden()
                                    }
                                    
                                    HStack {
                                        Toggle(isOn: $viewModel.outlineEnabled) {
                                            Text("Outline")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        .toggleStyle(.switch)
                                    }
                                    
                                    if viewModel.outlineEnabled {
                                        HStack {
                                            Text("Outline Color")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Spacer()
                                            ColorPicker("", selection: $viewModel.outlineColor, supportsOpacity: false)
                                                .labelsHidden()
                                        }
                                        .padding(.leading, 8)
                                    }
                                }
                                
                                Divider()
                                
                                // Layout Section
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Layout")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textCase(.uppercase)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Position")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Picker("Position", selection: $viewModel.episodeNumberPosition) {
                                            ForEach(ThumbnailGenerator.TextPosition.allCases) { position in
                                                Text(position.rawValue).tag(position)
                                            }
                                        }
                                        .labelsHidden()
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("H-Padding")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text("\(Int(viewModel.horizontalPadding))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Slider(value: $viewModel.horizontalPadding, in: 0...200, step: 5)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("V-Padding")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Spacer()
                                            Text("\(Int(viewModel.verticalPadding))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Slider(value: $viewModel.verticalPadding, in: 0...200, step: 5)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        
                        // Messages (compact)
                        if let error = viewModel.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        if let success = viewModel.successMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(success)
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                }
                .frame(minWidth: 280, idealWidth: 320, maxWidth: 350)
                .background(Color(NSColor.controlBackgroundColor))
                
                // Right Panel - Preview (70% of width, flexible)
                VStack(spacing: 0) {
                    // Header with zoom controls
                    HStack {
                        Text("Preview")
                            .font(.headline)
                        
                        Spacer()
                        
                        if viewModel.generatedThumbnail != nil {
                            // Zoom controls
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
                                    .disabled(previewZoom <= 0.25)
                                    .help("Zoom out")
                                    
                                    Text("\(Int(previewZoom * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(minWidth: 40)
                                    
                                    Button {
                                        previewZoom = min(4.0, previewZoom + 0.25)
                                    } label: {
                                        Image(systemName: "plus.magnifyingglass")
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(previewZoom >= 4.0)
                                    .help("Zoom in")
                                    
                                    Button {
                                        previewZoom = 1.0
                                    } label: {
                                        Image(systemName: "arrow.counterclockwise")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Reset zoom")
                                }
                            }
                            
                            Text("•")
                                .foregroundStyle(.secondary)
                            
                            if let thumbnail = viewModel.generatedThumbnail {
                                Text("\(Int(thumbnail.size.width)) × \(Int(thumbnail.size.height))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    
                    Divider()
                    
                    // Preview content
                    if viewModel.isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text("Generating thumbnail...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.textBackgroundColor).opacity(0.3))
                    } else if let thumbnail = viewModel.generatedThumbnail {
                        if fitToWindow {
                            // Fit to window mode - fills available space
                            GeometryReader { geometry in
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            }
                            .background(Color.black.opacity(0.05))
                        } else {
                            // Manual zoom mode - scrollable with zoom control
                            ScrollView([.horizontal, .vertical]) {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(previewZoom)
                                    .padding()
                            }
                            .background(Color.black.opacity(0.05))
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 64))
                                .foregroundColor(.secondary)
                            
                            Text("Generated thumbnail will appear here")
                                .foregroundColor(.secondary)
                            
                            Text("Select a background image and tap Generate")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.textBackgroundColor).opacity(0.3))
                    }
                }
                .frame(minWidth: 400)
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: viewModel.generateThumbnail) {
                    Label("Generate", systemImage: "wand.and.stars")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .disabled(viewModel.backgroundImage == nil)
                .help("Generate thumbnail")
            }
            
            ToolbarItem {
                Button(action: viewModel.exportThumbnail) {
                    Label("Export", systemImage: "arrow.up.doc")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .disabled(viewModel.generatedThumbnail == nil)
                .help("Export thumbnail")
            }
            
            ToolbarItem {
                Button(action: viewModel.clear) {
                    Label("Clear", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .help("Clear all")
            }
        }
        .onAppear {
            // Trigger initial generation with delay when view appears
            viewModel.performInitialGeneration()
        }
    }
}
