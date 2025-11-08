import SwiftUI
import UniformTypeIdentifiers

/// View for converting transcript text files to SRT format
public struct TranscriptView: View {
    @StateObject private var viewModel = TranscriptViewModel()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Transcript to SRT Converter")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Convert your transcript text file to YouTube-compatible SRT format")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content - Side by Side Layout
            VStack(spacing: 0) {
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: viewModel.importFile) {
                        Label("Import File", systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                    
                    Button(action: viewModel.clear) {
                        Label("Clear", systemImage: "trash")
                    }
                    
                    Button(action: viewModel.convertToSRT) {
                        Label("Convert to SRT", systemImage: "arrow.right.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
                    
                    Button(action: viewModel.exportSRT) {
                        Label("Export SRT", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.outputSRT.isEmpty)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                
                Divider()
                
                // Side-by-side editors
                HStack(spacing: 0) {
                    // Input Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Input Transcript")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        TextEditor(text: $viewModel.inputText)
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
        .frame(minWidth: 800, minHeight: 700)
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
    }
}
