import SwiftUI
import SwiftData

/// View for AI-powered content generation from episode transcripts
public struct AIIdeasView: View {
    @Environment(\.modelContext) private var modelContext
    let episode: Episode
    @StateObject private var viewModel: AIIdeasViewModel
    
    public init(episode: Episode) {
        self.episode = episode
        _viewModel = StateObject(wrappedValue: AIIdeasViewModel(
            episode: episode,
            context: PersistenceController.shared.container.mainContext
        ))
    }
    
    public var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if !viewModel.modelAvailable {
                    // Show unavailable message
                    unavailableView
                } else if episode.transcriptInputText == nil || episode.transcriptInputText?.isEmpty == true {
                    // Show no transcript message
                    ContentUnavailableView(
                        "No Transcript Available",
                        systemImage: "doc.text.fill.badge.questionmark",
                        description: Text("Add a transcript to this episode first to generate AI content ideas.")
                    )
                } else {
                    // Main content
                    ScrollView {
                        VStack(spacing: 16) {
                            // Title Suggestions Section
                            titleSuggestionsSection
                            
                            Divider()
                            
                            // Description Generator Section
                            descriptionSection
                            
                            Divider()
                            
                            // Social Posts Section
                            socialPostsSection
                            
                            Divider()
                            
                            // Chapter Markers Section
                            chaptersSection
                        }
                        .padding()
                    }
                    .frame(maxHeight: .infinity)
                    
                    // Error/Status Messages at bottom
                    if let error = viewModel.errorMessage {
                        Divider()
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.callout)
                                .foregroundColor(.red)
                            Spacer()
                            Button("Dismiss") {
                                viewModel.errorMessage = nil
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                    }
                }
            }
        }
        .toolbar {
            if viewModel.modelAvailable && episode.transcriptInputText != nil && !episode.transcriptInputText!.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task {
                            await viewModel.generateAll()
                        }
                    }) {
                        Label("Generate All", systemImage: "sparkles.rectangle.stack")
                    }
                    .labelStyle(.iconOnly)
                    .applyLiquidGlassButtonStyle(prominent: false)
                    .disabled(viewModel.isGeneratingAll)
                    .help("Generate all AI content suggestions")
                }
            }
        }
    }
    
    // MARK: - Unavailable View
    
    private var unavailableView: some View {
        ContentUnavailableView {
            Label("Apple Intelligence Required", systemImage: "cpu.fill")
        } description: {
            VStack(spacing: 16) {
                Text("AI Ideas requires Apple Intelligence to be enabled on your Mac.")
                    .multilineTextAlignment(.center)
                
                Text("Requirements:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Mac with M1 chip or later")
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("macOS 26.0 (Sequoia) or later")
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Apple Intelligence enabled in System Settings")
                    }
                }
                .font(.subheadline)
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
        } actions: {
            Link(destination: URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!) {
                Text("Open System Settings")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Title Suggestions Section
    
    private var titleSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Title Suggestions", systemImage: "text.quote")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task {
                        await viewModel.generateTitles()
                    }
                }) {
                    if viewModel.isGeneratingTitles {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .applyLiquidGlassButtonStyle(prominent: true)
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
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .trailing)
                            
                            Text(title)
                                .font(.body)
                            
                            Spacer()
                            
                            Button(action: {
                                viewModel.applyTitle(title)
                            }) {
                                Label("Apply", systemImage: "checkmark.circle")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.bordered)
                            .help("Use this as episode title")
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Episode Description", systemImage: "doc.text")
                    .font(.headline)
                
                Spacer()
                
                Picker("Length", selection: $viewModel.descriptionLength) {
                    ForEach(AIIdeasViewModel.DescriptionLength.allCases, id: \.self) { length in
                        Text(length.rawValue).tag(length)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .disabled(viewModel.isGeneratingDescription || viewModel.isGeneratingAll)
                
                Button(action: {
                    Task {
                        await viewModel.generateDescription()
                    }
                }) {
                    if viewModel.isGeneratingDescription {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .applyLiquidGlassButtonStyle(prominent: true)
                .disabled(viewModel.isGeneratingDescription || viewModel.isGeneratingAll)
            }
            
            if viewModel.generatedDescription.isEmpty {
                Text("Generate a compelling episode description")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: .constant(viewModel.generatedDescription))
                        .font(.body)
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                    
                    HStack {
                        Text("\(viewModel.generatedDescription.split(separator: " ").count) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.applyDescription()
                        }) {
                            Label("Apply to Episode", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
    
    // MARK: - Social Posts Section
    
    private var socialPostsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Social Media Posts", systemImage: "megaphone")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task {
                        await viewModel.generateSocialPosts()
                    }
                }) {
                    if viewModel.isGeneratingSocial {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .applyLiquidGlassButtonStyle(prominent: true)
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
                                Label(post.platform.rawValue, systemImage: post.platform.icon)
                                    .font(.subheadline.bold())
                                
                                Spacer()
                                
                                Text("\(post.content.count) chars")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Button(action: {
                                    viewModel.applySocialPost(post)
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.bordered)
                                .help("Copy to clipboard")
                            }
                            
                            Text(post.content)
                                .font(.body)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(NSColor.textBackgroundColor))
                                .cornerRadius(8)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // MARK: - Chapters Section
    
    private var chaptersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Chapter Markers", systemImage: "list.bullet.indent")
                    .font(.headline)
                Spacer()
                Button(action: {
                    Task {
                        await viewModel.generateChapters()
                    }
                }) {
                    if viewModel.isGeneratingChapters {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                        Text("Generating...")
                    } else {
                        Label("Generate", systemImage: "sparkles")
                    }
                }
                .applyLiquidGlassButtonStyle(prominent: true)
                .disabled(viewModel.isGeneratingChapters || viewModel.isGeneratingAll)
            }
            
            if viewModel.chapterMarkers.isEmpty {
                Text("Generate chapter markers with timestamps for major topic changes")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.chapterMarkers) { marker in
                        HStack(alignment: .top, spacing: 12) {
                            // Timestamp
                            Text(marker.timestamp)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(marker.title)
                                    .font(.body.bold())
                                
                                Text(marker.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    
                    // Apply button
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.applyChaptersToDescription()
                        }) {
                            Label("Apply to Description", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .help("Append chapter markers to episode description")
                    }
                    .padding(.top, 8)
                }
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
