import SwiftUI
import SwiftData

/// View for generating podcast thumbnails
public struct ThumbnailView: View {
    @Environment(\.modelContext) private var modelContext
    let episode: Episode
    @StateObject private var viewModel: ThumbnailViewModel
    
    public init(episode: Episode) {
        self.episode = episode
        _viewModel = StateObject(wrappedValue: ThumbnailViewModel(
            episode: episode,
            context: PersistenceController.shared.container.mainContext
        ))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                HStack(alignment: .top, spacing: 20) {
                    // Left Panel - Controls
                    VStack(alignment: .leading, spacing: 20) {
                        // Images Section
                        GroupBox(label: Label("Images", systemImage: "photo")) {
                            VStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Background Image")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack(spacing: 8) {
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
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Overlay Image (Optional)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    HStack(spacing: 8) {
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
                            .padding(.vertical, 8)
                        }
                        
                        // Episode Details Section
                        GroupBox(label: Label("Episode Details", systemImage: "number")) {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Episode Number")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    TextField("e.g., EP 42 or 42", text: $viewModel.episodeNumber)
                                        .textFieldStyle(.roundedBorder)
                                }

                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Font")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    HStack(spacing: 8) {
                                        Picker("Font", selection: $viewModel.selectedFont) {
                                            ForEach(viewModel.availableFonts, id: \.self) { font in
                                                Text(font.replacingOccurrences(of: "-Bold", with: ""))
                                                    .tag(font)
                                            }
                                        }
                                        .labelsHidden()
                                        
                                        Button(action: viewModel.loadCustomFont) {
                                            Label("Load Font", systemImage: "plus.circle")
                                        }
                                        .buttonStyle(.glass)
                                        .help("Load a custom .ttf or .otf font file")
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Font Size")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("\(Int(viewModel.fontSize))")
                                            .foregroundColor(.secondary)
                                    }
                                    Slider(value: $viewModel.fontSize, in: 24...120, step: 4)
                                }
                                
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
                                        Text("Horizontal Padding")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("\(Int(viewModel.horizontalPadding))")
                                            .foregroundColor(.secondary)
                                    }
                                    Slider(value: $viewModel.horizontalPadding, in: 0...200, step: 5)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Vertical Padding")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("\(Int(viewModel.verticalPadding))")
                                            .foregroundColor(.secondary)
                                    }
                                    Slider(value: $viewModel.verticalPadding, in: 0...200, step: 5)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Messages
                        if let error = viewModel.errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        if let success = viewModel.successMessage {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(success)
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        Spacer()
                    }
                    .frame(width: 380)
                    
                    Divider()
                    
                    // Right Panel - Preview
                    VStack {
                        Text("Preview")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let thumbnail = viewModel.generatedThumbnail {
                            Image(nsImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.opacity(0.1))
                                .cornerRadius(8)
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 64))
                                    .foregroundColor(.secondary)
                                
                                Text("Generated thumbnail will appear here")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: viewModel.generateThumbnail) {
                    Label("Generate", systemImage: "wand.and.stars")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .disabled(viewModel.backgroundImage == nil)
                .help("Generate thumbnail")
                
                Button(action: viewModel.exportThumbnail) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glassProminent)
                .disabled(viewModel.generatedThumbnail == nil)
                .help("Export thumbnail")
                
                Button(action: viewModel.clear) {
                    Label("Clear", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .help("Clear all")
            }
        }
    }
}
