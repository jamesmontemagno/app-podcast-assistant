import Testing
import Foundation
import SwiftData
@testable import PodcastAssistantFeature

// MARK: - SwiftData Model Tests

@Test func testPodcastCreation() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Podcast.self, Episode.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    let podcast = Podcast(
        name: "Test Podcast",
        podcastDescription: "A test podcast"
    )
    context.insert(podcast)
    try context.save()
    
    #expect(podcast.name == "Test Podcast")
    #expect(podcast.podcastDescription == "A test podcast")
    #expect(!podcast.id.isEmpty)
    #expect(podcast.episodes.isEmpty)
    #expect(podcast.defaultFontSize == 72.0)
}

@Test func testEpisodeCreation() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Podcast.self, Episode.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    let podcast = Podcast(name: "Test Podcast")
    context.insert(podcast)
    
    let episode = Episode(
        title: "Episode 1",
        episodeNumber: 1,
        podcast: podcast
    )
    context.insert(episode)
    try context.save()
    
    #expect(episode.title == "Episode 1")
    #expect(episode.episodeNumber == 1)
    #expect(episode.podcast?.name == "Test Podcast")
    #expect(!episode.id.isEmpty)
}

@Test func testEpisodeDefaultsCopiedFromPodcast() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Podcast.self, Episode.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    // Create podcast with custom defaults
    let podcast = Podcast(
        name: "Test Podcast",
        defaultFontName: "Impact",
        defaultFontSize: 96.0,
        defaultTextPositionX: 0.3,
        defaultTextPositionY: 0.7
    )
    context.insert(podcast)
    
    // Create episode associated with podcast
    let episode = Episode(
        title: "Episode 1",
        episodeNumber: 1,
        podcast: podcast
    )
    context.insert(episode)
    try context.save()
    
    // Verify defaults were copied
    #expect(episode.fontName == "Impact")
    #expect(episode.fontSize == 96.0)
    #expect(episode.textPositionX == 0.3)
    #expect(episode.textPositionY == 0.7)
}

@Test func testThumbnailSettingsAutoPersist() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Podcast.self, Episode.self, EpisodeContent.self,
        configurations: config
    )
    let context = ModelContext(container)

    let podcast = Podcast(name: "Test Podcast")
    context.insert(podcast)

    let episode = Episode(
        title: "Episode 1",
        episodeNumber: 1,
        podcast: podcast
    )
    context.insert(episode)
    try context.save()

    let viewModel = await MainActor.run {
        ThumbnailViewModel(episode: episode, modelContext: context)
    }

    await MainActor.run {
        viewModel.loadInitialData()
    }
    try await Task.sleep(nanoseconds: 150_000_000)

    await MainActor.run {
        viewModel.selectedFont = "Impact"
        viewModel.fontSize = 88
        viewModel.horizontalPadding = 72
    }

    try await Task.sleep(nanoseconds: 500_000_000)

    #expect(episode.fontName == "Impact")
    #expect(episode.fontSize == 88)
    #expect(episode.horizontalPadding == 72)
}

@Test func testCascadeDelete() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Podcast.self, Episode.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    let podcast = Podcast(name: "Test Podcast")
    context.insert(podcast)
    
    let episode1 = Episode(title: "Episode 1", episodeNumber: 1, podcast: podcast)
    let episode2 = Episode(title: "Episode 2", episodeNumber: 2, podcast: podcast)
    context.insert(episode1)
    context.insert(episode2)
    try context.save()
    
    #expect(podcast.episodes.count == 2)
    
    // Delete podcast
    context.delete(podcast)
    try context.save()
    
    // Fetch all episodes - should be empty due to cascade delete
    let descriptor = FetchDescriptor<Episode>()
    let remainingEpisodes = try context.fetch(descriptor)
    #expect(remainingEpisodes.isEmpty)
}

@Test func testImageStorageAndRetrieval() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Podcast.self, Episode.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    // Create test image data
    let testData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header
    
    let podcast = Podcast(
        name: "Test Podcast",
        artworkData: testData
    )
    context.insert(podcast)
    try context.save()
    
    #expect(podcast.artworkData == testData)
}

@Test func testRelationshipBidirectional() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Podcast.self, Episode.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    let podcast = Podcast(name: "Test Podcast")
    context.insert(podcast)
    
    let episode = Episode(title: "Episode 1", episodeNumber: 1, podcast: podcast)
    context.insert(episode)
    try context.save()
    
    // Check relationship from both sides
    #expect(episode.podcast?.id == podcast.id)
    #expect(podcast.episodes.contains(where: { $0.id == episode.id }))
}

// MARK: - Transcript Conversion Tests

@Test func testZencastrFormatConversion() async throws {
    let converter = TranscriptConverter()
    
    let zencastrInput = """
00:00.29
James
Welcome back everyone to Merge Conflict, your weekly developer podcast.

00:08.36
Frank
I am the other host. Hi, everyone.

00:19.69
Frank
But we got more GitHub Octo stuff to talk about.
"""
    
    let result = try converter.convertToSRT(from: zencastrInput)
    
    // Verify it's not empty
    #expect(!result.isEmpty)
    
    // Verify it contains SRT format elements
    #expect(result.contains("-->"))
    #expect(result.contains("James:"))
    #expect(result.contains("Frank:"))
    #expect(result.contains("Welcome back everyone"))
}

@Test func testTimeRangeFormatConversion() async throws {
    let converter = TranscriptConverter()
    
    let timeRangeInput = """
00:00:00 - 00:00:05 Welcome to the show
00:00:05 - 00:00:10 Today we're talking about podcasts
"""
    
    let result = try converter.convertToSRT(from: timeRangeInput)
    
    // Verify it's not empty
    #expect(!result.isEmpty)
    
    // Verify it contains SRT format
    #expect(result.contains("-->"))
    #expect(result.contains("Welcome to the show"))
}

@Test func testEmptyInputThrows() async throws {
    let converter = TranscriptConverter()
    
    #expect(throws: TranscriptConverter.ConversionError.self) {
        try converter.convertToSRT(from: "")
    }
}

@Test func testSRTDocumentInit() async throws {
    let text = "Test SRT content"
    let document = SRTDocument(text: text)
    
    #expect(document.text == text)
}

@Test func testSRTDocumentWriteAndRead() async throws {
    let originalText = """
1
00:00:00,000 --> 00:00:05,000
Welcome to the show

2
00:00:05,000 --> 00:00:10,000
Today we're talking about podcasts
"""
    
    let document = SRTDocument(text: originalText)
    
    #expect(document.text == originalText)
    
    // Note: FileDocument Write/ReadConfiguration cannot be initialized directly in tests
    // This test verifies the document stores text correctly
}

@Test func testSRTDocumentContentType() async throws {
    let contentTypes = SRTDocument.readableContentTypes
    
    // Should have at least one content type defined
    #expect(!contentTypes.isEmpty)
}

// MARK: - Translation Service Tests

@available(macOS 26.0, *)
@Test func testAvailableLanguageIdentifierIncludesRegion() async throws {
    let language = Locale.Language(
        languageCode: Locale.LanguageCode("es"),
        script: nil,
        region: Locale.Region("ES")
    )
    let available = AvailableLanguage(language: language, status: .installed)
    #expect(available.id.contains("es"))
    #expect(available.id.contains("ES") || available.id == "es")
}

@available(macOS 26.0, *)
@Test func testTranslationServiceReturnsUniqueLanguages() async throws {
    let service = TranslationService()
    let languages = await service.getAvailableLanguages()
    let identifiers = languages.map { $0.id }
    #expect(Set(identifiers).count == identifiers.count)
}

// MARK: - Settings Tests

@Test func testFontManagerAvailableFonts() async throws {
    let fontManager = FontManager()
    
    let fonts = fontManager.getAllAvailableFonts()
    
    // Should have system fonts available
    #expect(!fonts.isEmpty)
    #expect(fonts.contains("Helvetica"))
}

@Test func testFontManagerDisplayName() async throws {
    let fontManager = FontManager()
    
    // Test with a known system font
    let displayName = fontManager.getDisplayName(for: "Helvetica")
    
    #expect(!displayName.isEmpty)
}

@Test func testAppThemeEnum() async throws {
    // Test all theme cases
    #expect(AppTheme.system.rawValue == "System")
    #expect(AppTheme.light.rawValue == "Light")
    #expect(AppTheme.dark.rawValue == "Dark")
    
    // Test all cases are present
    #expect(AppTheme.allCases.count == 3)
    
    // Test display names
    #expect(AppTheme.system.displayName == "System")
    #expect(AppTheme.light.displayName == "Light")
    #expect(AppTheme.dark.displayName == "Dark")
}

@available(macOS 26.0, *)
@MainActor
@Test func testTitlePromptIncludesStyleGuidance() async throws {
    let transcript = "Episode transcript sample"
    let style = TitleStyle.professional

    let applePrompt = TitleGenerationService.buildTitlePrompt(
        processedTranscript: transcript,
        transcriptNote: "",
        styleGuidance: style.promptGuidance
    )
    #expect(applePrompt.contains(style.promptGuidance))

    let openAIPrompt = OpenAIContentService.buildTitlePrompt(
        processedTranscript: transcript,
        styleGuidance: style.promptGuidance
    )
    #expect(openAIPrompt.contains(style.promptGuidance))
}

@available(macOS 26.0, *)
@MainActor
@Test func testAIIdeasViewModelLoadsPersistedStyleAndSuggestions() async throws {
    UserDefaults.standard.set(TitleStyle.professional.rawValue, forKey: "aiTitleStyle")
    defer { UserDefaults.standard.removeObject(forKey: "aiTitleStyle") }

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Podcast.self, Episode.self, EpisodeContent.self,
        configurations: config
    )
    let context = ModelContext(container)

    let podcast = Podcast(name: "Test Podcast")
    let episode = Episode(title: "Episode", episodeNumber: 1, podcast: podcast)
    episode.aiTitleSuggestions = ["Title 1", "Title 2"]
    episode.aiSocialPosts = [StoredAISocialPost(platform: "future-platform", content: "Persisted post")]

    context.insert(podcast)
    context.insert(episode)
    try context.save()

    let viewModel = AIIdeasViewModel(episode: episode, modelContext: context)

    #expect(viewModel.titleStyle == .professional)
    #expect(viewModel.titleSuggestions == ["Title 1", "Title 2"])
    #expect(viewModel.socialPosts.count == 1)
    #expect(viewModel.socialPosts.first?.platform == AIIdeasViewModel.SocialPlatform.unknown)
}

@available(macOS 26.0, *)
@MainActor
@Test func testAIIdeasViewModelSanitizesInvalidStoredTitleStyle() async throws {
    UserDefaults.standard.set("invalid-style", forKey: "aiTitleStyle")
    defer { UserDefaults.standard.removeObject(forKey: "aiTitleStyle") }

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: Podcast.self, Episode.self, EpisodeContent.self,
        configurations: config
    )
    let context = ModelContext(container)

    let podcast = Podcast(name: "Test Podcast")
    let episode = Episode(title: "Episode", episodeNumber: 1, podcast: podcast)

    context.insert(podcast)
    context.insert(episode)
    try context.save()

    let viewModel = AIIdeasViewModel(episode: episode, modelContext: context)

    #expect(viewModel.titleStyle == .default)
    #expect(UserDefaults.standard.string(forKey: "aiTitleStyle") == TitleStyle.default.rawValue)
}
