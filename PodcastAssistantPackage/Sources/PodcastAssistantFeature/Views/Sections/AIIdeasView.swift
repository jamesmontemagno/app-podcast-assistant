import SwiftUI
import SwiftData

// MARK: - AI Ideas Section

@available(macOS 26.0, *)
public struct AIIdeasView: View {
    let episode: Episode
    let podcast: Podcast
    @StateObject private var viewModel: AIIdeasViewModel
    @AppStorage("aiProviderDefault") private var aiProviderDefaultRaw: String = AIProvider.apple.rawValue
    @AppStorage("openAIAPIKey") private var openAIAPIKey: String = ""
    @State private var providerSelection: AIProvider = .apple
    
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
                        providerPickerSection
                        transcriptInfoSection
                        Divider()
                        shrunkTranscriptSection
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
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.blue)
                            Text(viewModel.statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        
                        if !viewModel.progressDetails.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "gearshape.2")
                                    .foregroundStyle(.blue.opacity(0.7))
                                    .font(.caption2)
                                Text(viewModel.progressDetails)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                        }
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
            providerSelection = resolvedProvider
            viewModel.updateProvider(resolvedProvider, openAIKey: openAIAPIKey)
        }
        .onChange(of: providerSelection) { _, newValue in
            episode.aiProviderSelection = newValue
            try? modelContext.save()
            viewModel.updateProvider(newValue, openAIKey: openAIAPIKey)
        }
        .onChange(of: openAIAPIKey) { _, newKey in
            viewModel.updateProvider(providerSelection, openAIKey: newKey)
        }
        .alert("AI Provider Issue", isPresented: Binding(get: { viewModel.modalError != nil }, set: { show in if !show { viewModel.modalError = nil } })) {
            Button("OK", role: .cancel) { viewModel.modalError = nil }
        } message: {
            Text(viewModel.modalError ?? "")
        }
    }

    private var resolvedProvider: AIProvider {
        episode.aiProviderSelection ?? AIProvider(rawValue: aiProviderDefaultRaw) ?? .apple
    }
    
    private var unavailableView: some View {
        ContentUnavailableView {
            Label(providerSelection == .openAI ? "OpenAI Unavailable" : "Apple Intelligence Unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            VStack(spacing: 12) {
                Text(providerSelection == .openAI ? "Add a valid OpenAI API key in Settings" : "AI Ideas requires Apple Intelligence (macOS 26+)")
                    .foregroundStyle(.secondary)
                
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var providerPickerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("AI Provider", systemImage: "switch.2")
                    .font(.headline)
                Spacer()
                Text("Default: \(AIProvider(rawValue: aiProviderDefaultRaw)?.displayName ?? AIProvider.apple.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("Provider", selection: $providerSelection) {
                ForEach(AIProvider.allCases, id: \.self) { provider in
                    Text(provider.displayName).tag(provider)
                }
            }
            .pickerStyle(.segmented)
            
            if providerSelection == .openAI {
                HStack(spacing: 8) {
                    Image(systemName: openAIAPIKey.isEmpty ? "exclamationmark.triangle.fill" : "key.fill")
                        .foregroundStyle(openAIAPIKey.isEmpty ? .orange : .green)
                    Text(openAIAPIKey.isEmpty ? "Enter your OpenAI API key in Settings to enable cloud generation" : "Using OpenAI via saved API key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.blue)
                    Text("On-device Apple Intelligence; fastest and private")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
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
    
    private var shrunkTranscriptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Shrunk Transcript", systemImage: "wand.and.stars")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await viewModel.generateShrunkTranscript() }
                } label: {
                    if viewModel.isGeneratingShrunkTranscript {
                        ProgressView().controlSize(.small)
                        Text("Generating...")
                    } else if viewModel.shrunkTranscript.isEmpty {
                        Label("Generate", systemImage: "sparkles")
                    } else {
                        Label("Regenerate", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isGeneratingShrunkTranscript || viewModel.isGeneratingAll || providerSelection == .openAI)
            }
            if providerSelection == .openAI {
                Text("Transcript shrinker runs on-device only. Switch provider to On-Device to enable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Progress details
            if !viewModel.progressDetails.isEmpty && viewModel.isGeneratingShrunkTranscript {
                Text(viewModel.progressDetails)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Display area
            if viewModel.shrunkTranscript.isEmpty {
                Text("Generate a condensed version of the transcript for better AI content generation")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // Reduction stats
                    if viewModel.shrunkSegmentCount > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Condensed \(viewModel.originalSegmentCount) segments → \(viewModel.shrunkSegmentCount) summaries (\(viewModel.reductionPercentage)% reduction)")
                                .font(.caption)
                                .foregroundStyle(.green)
                            
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("With Timestamps")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 4) {
                                        Text(viewModel.shrunkTranscriptCharCountFormatted)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Text("chars")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Stripped")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 4) {
                                        Text(viewModel.shrunkTranscriptStrippedCharCountFormatted)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.blue)
                                        Text("chars")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Image(systemName: "arrow.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AI-Ready")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 4) {
                                        Text(viewModel.shrunkTranscriptCleanedCharCountFormatted)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.purple)
                                        Text("chars")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    ScrollView {
                        Text(viewModel.shrunkTranscript)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    
                    HStack {
                        Button {
                            viewModel.copyToClipboard(viewModel.shrunkTranscript)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
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
                
                if viewModel.usedShrunkTranscript && !viewModel.titleSuggestions.isEmpty {
                    Image(systemName: "wand.and.stars.inverse")
                        .foregroundStyle(.purple)
                        .help("Generated from condensed transcript")
                }
                
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
                VStack(alignment: .leading, spacing: 8) {
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
                    
                    HStack {
                        Button {
                            if let firstTitle = viewModel.titleSuggestions.first {
                                viewModel.copyToClipboard(firstTitle)
                            }
                        } label: {
                            Label("Copy First", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            viewModel.applyToPodcast()
                        } label: {
                            Label("Apply to Episode", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Apply first title to episode")
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
                
                if viewModel.usedShrunkTranscript && !viewModel.generatedDescription.isEmpty {
                    Image(systemName: "wand.and.stars.inverse")
                        .foregroundStyle(.purple)
                        .help("Generated from condensed transcript")
                }
                
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
                
                if viewModel.usedShrunkTranscript && !viewModel.socialPosts.isEmpty {
                    Image(systemName: "wand.and.stars.inverse")
                        .foregroundStyle(.purple)
                        .help("Generated from condensed transcript")
                }
                
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
