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

@available(macOS 14.0, *)
@Test func testSupportedLanguages() async throws {
    // Verify all supported languages are available
    let languages = TranslationService.SupportedLanguage.allCases
    
    #expect(languages.count > 0)
    #expect(languages.contains(.spanish))
    #expect(languages.contains(.french))
    #expect(languages.contains(.german))
}

@available(macOS 14.0, *)
@Test func testLanguageDisplayNames() async throws {
    let spanish = TranslationService.SupportedLanguage.spanish
    #expect(spanish.displayName.contains("Spanish"))
    #expect(spanish.displayName.contains("Español"))
    
    let french = TranslationService.SupportedLanguage.french
    #expect(french.displayName.contains("French"))
}

@available(macOS 14.0, *)
@Test func testLanguageLocales() async throws {
    let spanish = TranslationService.SupportedLanguage.spanish
    #expect(spanish.languageCode.identifier == "es")
    
    let japanese = TranslationService.SupportedLanguage.japanese
    #expect(japanese.languageCode.identifier == "ja")
}

@available(macOS 14.0, *)
@Test func testTranslationServiceInit() async throws {
    let service = TranslationService()
    // Should initialize without errors
    #expect(service != nil)
}

// MARK: - Settings Tests

@Test func testAppSettingsCreation() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: AppSettings.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    let settings = AppSettings()
    context.insert(settings)
    try context.save()
    
    #expect(settings.id == "app-settings")
    #expect(settings.importedFonts.isEmpty)
    #expect(!settings.createdAt.timeIntervalSince1970.isZero)
}

@Test func testAppSettingsFontManagement() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: AppSettings.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    let settings = AppSettings()
    context.insert(settings)
    
    // Add fonts
    settings.importedFonts = ["Helvetica-Bold", "Arial-BoldMT"]
    settings.updatedAt = Date()
    try context.save()
    
    #expect(settings.importedFonts.count == 2)
    #expect(settings.importedFonts.contains("Helvetica-Bold"))
    #expect(settings.importedFonts.contains("Arial-BoldMT"))
}

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

@Test func testAppSettingsThemeManagement() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
        for: AppSettings.self,
        configurations: config
    )
    let context = ModelContext(container)
    
    let settings = AppSettings()
    context.insert(settings)
    
    // Default theme should be system
    #expect(settings.appTheme == .system)
    #expect(settings.theme == "System")
    
    // Change to light theme
    settings.appTheme = .light
    try context.save()
    #expect(settings.appTheme == .light)
    #expect(settings.theme == "Light")
    
    // Change to dark theme
    settings.appTheme = .dark
    try context.save()
    #expect(settings.appTheme == .dark)
    #expect(settings.theme == "Dark")
    
    // Back to system
    settings.appTheme = .system
    try context.save()
    #expect(settings.appTheme == .system)
    #expect(settings.theme == "System")
}
