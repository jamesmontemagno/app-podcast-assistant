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
    
    // Test writing
    let writeConfig = SRTDocument.WriteConfiguration()
    let fileWrapper = try document.fileWrapper(configuration: writeConfig)
    
    #expect(fileWrapper.regularFileContents != nil)
    
    // Test reading
    let readConfig = SRTDocument.ReadConfiguration(file: fileWrapper)
    let readDocument = try SRTDocument(configuration: readConfig)
    
    #expect(readDocument.text == originalText)
}

@Test func testSRTDocumentContentType() async throws {
    let contentTypes = SRTDocument.readableContentTypes
    
    #expect(!contentTypes.isEmpty)
    // Should contain either SRT type or plainText as fallback
    #expect(contentTypes.contains(where: { $0.identifier == "srt" || $0 == .plainText }))
}
