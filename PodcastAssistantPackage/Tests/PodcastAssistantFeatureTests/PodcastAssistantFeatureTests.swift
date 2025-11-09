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
