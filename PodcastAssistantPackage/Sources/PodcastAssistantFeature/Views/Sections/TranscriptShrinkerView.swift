import SwiftUI
import SwiftData

/// Transcript Shrinker View - based on TranscriptSummarizer reference implementation
@available(macOS 26.0, *)
public struct TranscriptShrinkerView: View {
    let episode: Episode
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel: TranscriptShrinkerViewModel
    
    public init(episode: Episode) {
        self.episode = episode
        _viewModel = StateObject(wrappedValue: TranscriptShrinkerViewModel(episode: episode))
    }
    
    public var body: some View {
        HStack {
            // Left Column: Original Transcript
            VStack {
                HStack {
                    Text("Original Transcript")
                        .font(.title2)
                    Button {
                        viewModel.summarize()
                    } label: {
                        Label("Summarize", systemImage: "brain.head.profile")
                    }
                    .disabled(viewModel.isSummarizing || viewModel.windows.isEmpty)
                }
                .padding()
                
                TextEditor(text: Binding(
                    get: { viewModel.rawTranscript },
                    set: { newValue in
                        viewModel.rawTranscript = newValue
                        viewModel.updateSegments(from: newValue)
                    }
                ))
                .padding()
                
                Text("\(viewModel.originalSegmentCount) Segments")
                    .font(.title3)
                    .padding()
                
                List(viewModel.originalSegments, id: \.timestamp) { segment in
                    VStack(alignment: .leading) {
                        Text("\(segment.timestamp) - \(segment.speaker)")
                            .bold()
                        Text(segment.text)
                    }
                }
                
                Text("\(viewModel.windowCount) Windows")
                    .font(.title3)
                    .padding()
                
                List {
                    ForEach(viewModel.windows) { window in
                        Section(header: Text("Window at \(window.segments.first?.timestamp ?? "unknown") with \(window.segments.count) segs, \(window.jsonCharCount) chars")) {
                            ForEach(window.segments, id: \.timestamp) { segment in
                                VStack(alignment: .leading) {
                                    Text("\(segment.timestamp) - \(segment.speaker)")
                                        .bold()
                                    Text(segment.text)
                                }
                            }
                        }
                    }
                }
            }
            
            // Right Column: Summarized Transcript
            VStack {
                HStack {
                    Text("Summarized Transcript")
                        .font(.title2)
                    if viewModel.isSummarizing {
                        ProgressView(value: viewModel.summaryProgress)
                    }
                }
                .padding()
                
                if !viewModel.summarizedSegments.isEmpty {
                    HStack {
                        Text("Reduction: \(viewModel.reductionPercent)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                
                List(viewModel.summarizedSegments) { summarized in
                    VStack(alignment: .leading) {
                        Text("From \(summarized.firstSegmentTimestamp):")
                            .bold()
                        Text(summarized.summary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.modelContext = modelContext
            if !viewModel.rawTranscript.isEmpty {
                viewModel.updateSegments(from: viewModel.rawTranscript)
            }
        }
    }
}
