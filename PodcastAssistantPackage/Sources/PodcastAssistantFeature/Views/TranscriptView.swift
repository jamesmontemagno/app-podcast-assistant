import SwiftUI
import UniformTypeIdentifiers
import SwiftData

/// View for converting transcript text files to SRT format
public struct TranscriptView: View {
    @Environment(\.modelContext) private var modelContext
    let episode: Episode
    @StateObject private var viewModel: TranscriptViewModel
    
    public init(episode: Episode) {
        self.episode = episode
        _viewModel = StateObject(wrappedValue: TranscriptViewModel(
            episode: episode,
            context: PersistenceController.shared.container.mainContext
        ))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Content - Side by Side Layout
            VStack(spacing: 0) {
                // Side-by-side editors
                HStack(spacing: 0) {
                    // Input Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Input Transcript")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        TextEditor(text: Binding(
                            get: { viewModel.inputText },
                            set: { viewModel.inputText = $0 }
                        ))
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
                    
                    Divider()
                    
                    // Output Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SRT Output")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        TextEditor(text: .constant(viewModel.outputSRT))
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(NSColor.textBackgroundColor))
                }
                .frame(maxHeight: .infinity)
                
                // Messages at bottom
                if let error = viewModel.errorMessage {
                    Divider()
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                }
                
                if let success = viewModel.successMessage {
                    Divider()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(success)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                }
            }
        }
        .fileImporter(
            isPresented: $viewModel.showingImporter,
            allowedContentTypes: [.plainText, .text],
            onCompletion: viewModel.handleImportedFile
        )
        .fileExporter(
            isPresented: $viewModel.showingExporter,
            document: viewModel.srtDocument,
            contentType: UTType(filenameExtension: "srt") ?? .plainText,
            defaultFilename: "transcript.srt",
            onCompletion: viewModel.handleExportCompletion
        )
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: viewModel.importFile) {
                    Label("Import", systemImage: "doc.badge.plus")
                }
                .labelStyle(.iconOnly)
                .applyLiquidGlassButtonStyle(prominent: true)
                .help("Import transcript file")
                
                Button(action: viewModel.convertToSRT) {
                    Label("Convert", systemImage: "arrow.right.circle.fill")
                }
                .labelStyle(.iconOnly)
                .applyLiquidGlassButtonStyle(prominent: true)
                .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
                .help("Convert transcript to SRT format")
                
                Button(action: viewModel.exportSRT) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .labelStyle(.iconOnly)
                .applyLiquidGlassButtonStyle(prominent: true)
                .disabled(viewModel.outputSRT.isEmpty)
                .help("Export SRT file")
                
                Button(action: viewModel.clear) {
                    Label("Clear", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .applyLiquidGlassButtonStyle(prominent: false)
                .help("Clear all content")
            }
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
