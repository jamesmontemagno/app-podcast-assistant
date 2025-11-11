import SwiftUI
import SwiftData
import AppKit

// MARK: - Transcript Section

public struct TranscriptView: View {
    let episode: Episode
    @Binding var showingTranslation: Bool
    @Binding var inputText: String
    @Binding var outputText: String
    
    @Environment(\.modelContext) private var modelContext
    
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let converter = TranscriptConverter()
    
    public init(episode: Episode, showingTranslation: Binding<Bool>, inputText: Binding<String>, outputText: Binding<String>) {
        self.episode = episode
        self._showingTranslation = showingTranslation
        self._inputText = inputText
        self._outputText = outputText
    }
    
    public var body: some View {
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
                                try? modelContext.save()
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
