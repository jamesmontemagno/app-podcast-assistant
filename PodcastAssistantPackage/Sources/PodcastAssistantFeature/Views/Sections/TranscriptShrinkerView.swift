import SwiftUI
import SwiftData

/// Debug UI for testing transcript shrinking functionality
@available(macOS 26.0, *)
public struct TranscriptShrinkerView: View {
    let episode: Episode
    @StateObject private var viewModel: TranscriptShrinkerViewModel
    @Environment(\.modelContext) private var modelContext
    
    public init(episode: Episode) {
        self.episode = episode
        _viewModel = StateObject(wrappedValue: TranscriptShrinkerViewModel(episode: episode))
    }
    
    public var body: some View {
        Group {
            if !viewModel.hasTranscript {
                ContentUnavailableView(
                    "No Transcript Available",
                    systemImage: "doc.text",
                    description: Text("Add a transcript in the Transcript tab first")
                )
            } else {
                GeometryReader { geometry in
                    HStack(spacing: 16) {
                        // Left Column: Original Segments
                        originalSegmentsColumn
                            .frame(width: (geometry.size.width - 48) / 3)
                        
                        // Middle Column: Controls
                        controlsColumn
                            .frame(width: (geometry.size.width - 48) / 3)
                        
                        // Right Column: Refined Segments
                        refinedSegmentsColumn
                            .frame(width: (geometry.size.width - 48) / 3)
                    }
                    .padding(16)
                }
            }
        }
        .onAppear {
            viewModel.modelContext = modelContext
        }
    }
    
    // MARK: - Left Column: Original Segments
    
    private var originalSegmentsColumn: some View {
        VStack(spacing: 12) {
            // Header
            Text("Original Segments")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Stats Card
            if viewModel.originalSegments.isEmpty {
                // Show raw transcript stats before parsing
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text("Characters: \(viewModel.rawTranscriptLength)")
                    }
                    
                    HStack {
                        Image(systemName: "text.alignleft")
                            .foregroundStyle(.secondary)
                        Text("Lines: \(viewModel.rawTranscriptLines)")
                    }
                    
                    HStack {
                        Image(systemName: "text.word.spacing")
                            .foregroundStyle(.secondary)
                        Text("~\(viewModel.rawWordCount) words")
                    }
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("Click Parse to extract segments")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                // Show parsed segments stats
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.secondary)
                        Text("Segments: \(viewModel.originalSegmentCount)")
                    }
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Duration: \(viewModel.totalDuration)")
                    }
                    
                    HStack {
                        Image(systemName: "text.word.spacing")
                            .foregroundStyle(.secondary)
                        Text("~\(viewModel.estimatedWordCount) words")
                    }
                }
                .font(.subheadline)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            Divider()
            
            // Parse Button or Segments List
            if viewModel.originalSegments.isEmpty {
                Spacer()
                
                VStack(spacing: 16) {
                    if viewModel.isParsing {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Parsing transcript...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            Task {
                                await viewModel.parseTranscript()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "wand.and.stars")
                                Text("Parse Transcript")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        
                        Text("Extract timestamped segments from raw transcript")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
                
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.originalSegments) { segment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(segment.timestamp)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                
                                Text(segment.text.prefix(120) + (segment.text.count > 120 ? "..." : ""))
                                    .font(.caption)
                                    .lineLimit(3)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Middle Column: Controls
    
    private var controlsColumn: some View {
        VStack(spacing: 12) {
            // Header
            Text("Configuration")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Config Sliders
            VStack(alignment: .leading, spacing: 16) {
                configSlider(
                    title: "Window Size",
                    value: $viewModel.windowSize,
                    range: 20...60,
                    step: 5,
                    format: "%.0f segments"
                )
                
                configSlider(
                    title: "Overlap",
                    value: $viewModel.overlapPercent,
                    range: 20...50,
                    step: 5,
                    format: "%.0f%%"
                )
                
                configSlider(
                    title: "Target Segments",
                    value: $viewModel.targetCount,
                    range: 15...40,
                    step: 5,
                    format: "%.0f"
                )
                
                configSlider(
                    title: "Similarity Threshold",
                    value: $viewModel.similarityThreshold,
                    range: 0.5...0.9,
                    step: 0.05,
                    format: "%.2f"
                )
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Shrink Button
            Button {
                Task {
                    await viewModel.shrinkTranscript()
                }
            } label: {
                HStack {
                    if viewModel.isShrinking {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text("🔬 Shrink Transcript")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isShrinking || viewModel.originalSegments.isEmpty)
            
            Divider()
            
            // Processing Log
            VStack(alignment: .leading, spacing: 8) {
                Text("Processing Log")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        if viewModel.processingLog.isEmpty {
                            Text("No activity yet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(viewModel.processingLog.indices, id: \.self) { index in
                                Text(viewModel.processingLog[index])
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            
            // Error Message
            if let error = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }
    
    private func configSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        format: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(String(format: format, value.wrappedValue))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Slider(value: value, in: range, step: step)
                .disabled(viewModel.isShrinking)
        }
    }
    
    // MARK: - Right Column: Refined Segments
    
    private var refinedSegmentsColumn: some View {
        VStack(spacing: 12) {
            // Header
            Text("Refined Segments")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Stats Card
            if let stats = viewModel.stats {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Refined: \(stats.refinedCount) segments")
                    }
                    
                    HStack {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .foregroundStyle(.blue)
                        Text("Reduction: \(stats.reductionPercentFormatted)")
                    }
                    
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(.secondary)
                        Text("Time: \(stats.processingTimeFormatted)")
                    }
                    
                    HStack {
                        Image(systemName: "square.grid.3x3")
                            .foregroundStyle(.secondary)
                        Text("Windows: \(stats.windowsProcessed)")
                    }
                }
                .font(.subheadline)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No results yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Click 'Shrink Transcript' to process")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            
            Divider()
            
            // Refined Segments List
            if viewModel.refinedSegments.isEmpty {
                Spacer()
                if viewModel.isShrinking {
                    VStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Processing...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView(
                        "No Refined Segments",
                        systemImage: "sparkles",
                        description: Text("Run the shrinking process first")
                    )
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.refinedSegments) { segment in
                            VStack(alignment: .leading, spacing: 8) {
                                // Time Range Header
                                HStack {
                                    Image(systemName: "clock")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                    Text(segment.timeRange)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.blue)
                                }
                                
                                // Summary
                                Text(segment.summary)
                                    .font(.subheadline)
                                
                                // Coverage Badge
                                HStack {
                                    Image(systemName: "square.stack.3d.up")
                                        .font(.caption2)
                                    Text("Covers \(segment.segmentsCovered) segments")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
                
                // Export Button
                Button {
                    viewModel.exportRefinedSegments()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Refined Segments")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
