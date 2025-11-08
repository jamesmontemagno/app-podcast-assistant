import Testing
@testable import PodcastAssistantFeature

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
