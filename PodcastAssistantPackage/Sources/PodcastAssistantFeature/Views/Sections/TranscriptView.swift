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
    @State private var showDebugInfo: Bool = false
    @State private var debugInfo: ConversionDebugInfo?
    
    private var converter = TranscriptConverter()
    
    public init(episode: Episode, showingTranslation: Binding<Bool>, inputText: Binding<String>, outputText: Binding<String>) {
        self.episode = episode
        self._showingTranslation = showingTranslation
        self._inputText = inputText
        self._outputText = outputText
    }
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Debug info panel (collapsible)
                if showDebugInfo, let info = debugInfo {
                    debugPanel(info: info)
                }
                
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
        }
        .onAppear {
            inputText = episode.transcriptInputText ?? ""
            outputText = episode.srtOutputText ?? ""
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showDebugInfo.toggle()
                } label: {
                    Label("Debug Info", systemImage: showDebugInfo ? "info.circle.fill" : "info.circle")
                }
                .help("Show conversion debug information")
            }
        }
    }
    
    @ViewBuilder
    private func debugPanel(info: ConversionDebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: info.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(info.success ? .green : .red)
                Text("Conversion Debug Info")
                    .font(.headline)
                Spacer()
                Button {
                    showDebugInfo = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                GridRow {
                    Text("Format:")
                        .fontWeight(.semibold)
                        .gridColumnAlignment(.trailing)
                    Text(info.formatDescription)
                }
                
                GridRow {
                    Text("Input:")
                        .fontWeight(.semibold)
                    Text("\(info.inputLines) lines, \(info.inputCharacters) characters")
                }
                
                GridRow {
                    Text("Found:")
                        .fontWeight(.semibold)
                    Text("\(info.timestampsFound) timestamps, \(info.speakersFound) speakers")
                }
                
                GridRow {
                    Text("Generated:")
                        .fontWeight(.semibold)
                    Text("\(info.entriesGenerated) SRT entries")
                }
                
                if let error = info.errorMessage {
                    GridRow {
                        Text("Error:")
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .font(.caption)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}
