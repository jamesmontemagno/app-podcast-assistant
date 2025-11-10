import SwiftUI
import AppKit

// MARK: - Transcript Section

struct TranscriptSection: View {
    let episode: EpisodePOCO
    let store: PodcastLibraryStore
    @Binding var showingTranslation: Bool
    @Binding var inputText: String
    @Binding var outputText: String
    
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let converter = TranscriptConverter()
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 16) {
                // Left pane: Input
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Input Transcript")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !inputText.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                Text("\(inputText.split(separator: " ").count) words")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    ScrollView {
                        TextEditor(text: $inputText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onChange(of: inputText) { _, newValue in
                                episode.transcriptInputText = newValue.isEmpty ? nil : newValue
                            }
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .frame(width: (geometry.size.width - 48) / 2)
                
                // Right pane: Output
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("SRT Output")
                            .font(.headline)
                        
                        Spacer()
                        
                        if !outputText.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                Text("\(outputText.split(separator: " ").count) words")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    
                    ScrollView {
                        TextEditor(text: $outputText)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .frame(width: (geometry.size.width - 48) / 2)
            }
            .padding(16)
        }
        .onAppear {
            inputText = episode.transcriptInputText ?? ""
            outputText = episode.srtOutputText ?? ""
        }
    }
}
