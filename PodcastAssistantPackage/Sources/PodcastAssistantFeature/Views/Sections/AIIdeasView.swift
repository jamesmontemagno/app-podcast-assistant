import SwiftUI
import SwiftData

// MARK: - AI Ideas Section

@available(macOS 26.0, *)
public struct AIIdeasView: View {
    let episode: Episode
    let podcast: Podcast
    @StateObject private var viewModel: AIIdeasViewModel
    
    @Environment(\.modelContext) private var modelContext
    
    public init(episode: Episode, podcast: Podcast) {
        self.episode = episode
        self.podcast = podcast
        // ViewModel initialized without modelContext, will set it in onAppear
        _viewModel = StateObject(wrappedValue: AIIdeasViewModel(episode: episode))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            if !viewModel.modelAvailable {
                unavailableView
            } else if !episode.hasTranscriptData {
                ContentUnavailableView(
                    "No Transcript Available",
                    systemImage: "doc.text.fill.badge.questionmark",
                    description: Text("Add a transcript to this episode first to generate AI content ideas.")
                )
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        transcriptInfoSection
                        Divider()
                        titleSuggestionsSection
                        Divider()
                        descriptionSection
                        Divider()
                        socialPostsSection
                        Divider()
                        chaptersSection
                    }
                    .padding(20)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .padding(16)
                }
                
                // Status message bar
                if !viewModel.statusMessage.isEmpty {
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.blue)
                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                }
                
                if let error = viewModel.errorMessage {
                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                }
            }
        }
        .onAppear {
            viewModel.modelContext = modelContext
        }
    }
    
    private var unavailableView: some View {
        ContentUnavailableView {
            Label("Apple Intelligence Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: 12) {
                Text("AI Ideas requires Apple Intelligence (macOS 26+)")
                    .foregroundStyle(.secondary)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var transcriptInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Transcript Analysis", systemImage: "doc.text.magnifyingglass")
                .font(.headline)
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original Length")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(viewModel.transcriptLengthFormatted)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        Text("chars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cleaned Length")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text(viewModel.cleanedTranscriptLengthFormatted)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                        Text("chars")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Reduction")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if viewModel.transcriptLength > 0 {
                        let reduction = Double(viewModel.transcriptLength - viewModel.cleanedTranscriptLength) / Double(viewModel.transcriptLength) * 100
                        Text(String(format: "%.0f%%", reduction))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    } else {
                        Text("–")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
    
    private var titleSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Title Suggestions", systemImage: "textformat.size")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await viewModel.generateTitles() }
                } label: {
                    if viewModel.isGeneratingTitles {
                        ProgressView().controlSize(.small)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isGeneratingTitles || viewModel.isGeneratingAll)
            }
            
            if viewModel.titleSuggestions.isEmpty {
                Text("Generate 5 creative title suggestions for this episode")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.titleSuggestions.enumerated()), id: \.offset) { index, title in
                        HStack(spacing: 12) {
                            Text("\(index + 1).")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            
                            Text(title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Spacer()
                            
                            Button {
                                viewModel.applyTitle(title)
                            } label: {
                                Label("Apply", systemImage: "checkmark.circle.fill")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.bordered)
                            .help("Apply this title to episode")
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Episode Description", systemImage: "doc.text")
                    .font(.headline)
                Spacer()
                Picker("Length", selection: $viewModel.descriptionLength) {
                    ForEach(DescriptionGenerationService.DescriptionLength.allCases, id: \.self) { length in
                        Text(length.rawValue).tag(length)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                Button {
                    Task { await viewModel.generateDescription() }
                } label: {
                    if viewModel.isGeneratingDescription {
                        ProgressView().controlSize(.small)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isGeneratingDescription || viewModel.isGeneratingAll)
            }
            
            if viewModel.generatedDescription.isEmpty {
                Text("Generate a compelling episode description")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView {
                        Text(viewModel.generatedDescription)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    
                    HStack {
                        Button {
                            viewModel.copyToClipboard(viewModel.generatedDescription)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            viewModel.applyDescription()
                        } label: {
                            Label("Apply to Episode", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
    
    private var socialPostsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Social Media Posts", systemImage: "megaphone")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await viewModel.generateSocialPosts() }
                } label: {
                    if viewModel.isGeneratingSocial {
                        ProgressView().controlSize(.small)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isGeneratingSocial || viewModel.isGeneratingAll)
            }
            
            if viewModel.socialPosts.isEmpty {
                Text("Generate platform-specific social media posts")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.socialPosts) { post in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: post.platform.rawValue == "Twitter/X" ? "xmark" : post.platform.rawValue == "LinkedIn" ? "briefcase" : "photo")
                                    .foregroundStyle(.blue)
                                Text(post.platform.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                                Button {
                                    viewModel.copyToClipboard(post.content)
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.borderless)
                            }
                            
                            Text(post.content)
                                .font(.body)
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(6)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Chapter Markers", systemImage: "list.number")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await viewModel.generateChapters() }
                } label: {
                    if viewModel.isGeneratingChapters {
                        ProgressView().controlSize(.small)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isGeneratingChapters || viewModel.isGeneratingAll)
            }
            
            if viewModel.chapterMarkers.isEmpty {
                Text("Auto-detect chapter breaks with timestamps and descriptions")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.chapterMarkers.enumerated()), id: \.offset) { index, chapter in
                        HStack(alignment: .top, spacing: 12) {
                            Text(chapter.timestamp)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(chapter.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    
                    Button {
                        viewModel.copyChaptersAsYouTube()
                    } label: {
                        Label("Copy as YouTube Chapters", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}
