import Foundation

/// Service for cleaning and processing transcripts for AI analysis
public class TranscriptCleaner {
    
    public init() {}
    
    /// Cleans transcript by removing timestamps, speaker names, and extra whitespace
    /// Optimized for maximizing content in LLM context window
    /// - Parameter transcript: Raw transcript text
    /// - Returns: Cleaned transcript with just the dialog content
    public func cleanForAI(_ transcript: String) -> String {
        var lines = transcript.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Remove timestamp lines (various formats)
        lines = lines.filter { line in
            // Skip empty lines
            if line.isEmpty { return false }
            
            // Skip Zencastr timestamps (MM:SS.ss)
            if isZencastrTimestamp(line) { return false }
            
            // Skip time range timestamps (HH:MM:SS - HH:MM:SS)
            if isTimeRangeTimestamp(line) { return false }
            
            // Skip SRT timestamps (HH:MM:SS,mmm --> HH:MM:SS,mmm)
            if isSRTTimestamp(line) { return false }
            
            // Skip SRT sequence numbers (just digits)
            if line.allSatisfy({ $0.isNumber }) { return false }
            
            return true
        }
        
        // Remove speaker names (capitalized words followed by colon)
        lines = lines.map { line in
            // Pattern: "SpeakerName: " or "Speaker Name: " at start of line
            let pattern = #"^[A-Z][a-zA-Z\s]*:\s*"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(line.startIndex..., in: line)
                return regex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
            }
            return line
        }
        
        // Filter out likely speaker name-only lines
        lines = lines.filter { line in
            // Skip very short lines that might be speaker names
            if line.count < 3 { return false }
            
            // Skip lines that are just a name (capitalized, no punctuation, short)
            if line.count < 30 && line.first?.isUppercase == true && 
               !line.contains(".") && !line.contains("?") && !line.contains("!") &&
               line.filter({ $0.isWhitespace }).count <= 1 {
                return false
            }
            
            return true
        }
        
        // Join with spaces and collapse multiple spaces
        let cleaned = lines.joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        return cleaned
    }
    
    /// Light cleaning for chapter generation - only removes speaker names, preserves timecodes and structure
    /// - Parameter transcript: Raw transcript text
    /// - Returns: Transcript with speaker names removed but timecodes and content preserved
    public func cleanForChapters(_ transcript: String) -> String {
        let lines = transcript.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Remove speaker names only (capitalized words followed by colon)
        let cleaned = lines.map { line in
            // Pattern: "SpeakerName: " or "Speaker Name: " at start of line
            let pattern = #"^[A-Z][a-zA-Z\s]*:\s*"#
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(line.startIndex..., in: line)
                return regex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
            }
            return line
        }
        
        // Join with newlines to preserve structure, remove empty lines
        return cleaned.filter { !$0.isEmpty }.joined(separator: "\n")
    }
    
    /// Chunks transcript for chapter generation when it exceeds context window
    /// Preserves original timestamps and structure for accurate chapter extraction
    /// - Parameters:
    ///   - transcript: Original transcript with timestamps
    ///   - maxChunkSize: Maximum characters per chunk (default: 12000)
    /// - Returns: Array of transcript chunks with overlapping context
    public func chunkForChapterGeneration(_ transcript: String, maxChunkSize: Int = 12000) -> [TranscriptChunk] {
        let lines = transcript.components(separatedBy: .newlines)
        
        var chunks: [TranscriptChunk] = []
        var currentChunk: [String] = []
        var currentSize = 0
        var chunkStartIndex = 0
        var lastTimestamp: String?
        
        for (index, line) in lines.enumerated() {
            let lineSize = line.count + 1 // +1 for newline
            
            // Extract timestamp if present
            if let timestamp = extractAnyTimestamp(from: line) {
                lastTimestamp = timestamp
            }
            
            // If adding this line would exceed chunk size and we have content
            if currentSize + lineSize > maxChunkSize && !currentChunk.isEmpty {
                // Create chunk
                let chunkText = currentChunk.joined(separator: "\n")
                let chunk = TranscriptChunk(
                    text: chunkText,
                    startLineIndex: chunkStartIndex,
                    endLineIndex: index - 1,
                    startTimestamp: chunks.last?.endTimestamp ?? extractFirstTimestamp(from: chunkText),
                    endTimestamp: lastTimestamp
                )
                chunks.append(chunk)
                
                // Start new chunk with overlap (last 10 lines)
                let overlapLines = Array(currentChunk.suffix(10))
                currentChunk = overlapLines
                currentSize = overlapLines.joined(separator: "\n").count
                chunkStartIndex = max(0, index - 10)
            }
            
            currentChunk.append(line)
            currentSize += lineSize
        }
        
        // Add final chunk if there's content
        if !currentChunk.isEmpty {
            let chunkText = currentChunk.joined(separator: "\n")
            let chunk = TranscriptChunk(
                text: chunkText,
                startLineIndex: chunkStartIndex,
                endLineIndex: lines.count - 1,
                startTimestamp: chunks.last?.endTimestamp ?? extractFirstTimestamp(from: chunkText),
                endTimestamp: lastTimestamp
            )
            chunks.append(chunk)
        }
        
        return chunks
    }
    
    // MARK: - Private Helpers
    
    private func isZencastrTimestamp(_ line: String) -> Bool {
        let pattern = #"^\d{1,2}:\d{2}\.\d{2}$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(line.startIndex..., in: line)
        return regex.firstMatch(in: line, range: range) != nil
    }
    
    private func isTimeRangeTimestamp(_ line: String) -> Bool {
        let pattern = #"^\d{1,2}:\d{2}:\d{2}\s*[-–>]+\s*\d{1,2}:\d{2}:\d{2}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(line.startIndex..., in: line)
        return regex.firstMatch(in: line, range: range) != nil
    }
    
    private func isSRTTimestamp(_ line: String) -> Bool {
        let pattern = #"^\d{2}:\d{2}:\d{2},\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(line.startIndex..., in: line)
        return regex.firstMatch(in: line, range: range) != nil
    }
    
    private func extractAnyTimestamp(from line: String) -> String? {
        // Try Zencastr format first (MM:SS.ss)
        let zencastrPattern = #"(\d{1,2}:\d{2}\.\d{2})"#
        if let regex = try? NSRegularExpression(pattern: zencastrPattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return String(line[range])
        }
        
        // Try time range format (HH:MM:SS)
        let timePattern = #"(\d{1,2}:\d{2}:\d{2})"#
        if let regex = try? NSRegularExpression(pattern: timePattern),
           let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
           let range = Range(match.range(at: 1), in: line) {
            return String(line[range])
        }
        
        return nil
    }
    
    private func extractFirstTimestamp(from text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            if let timestamp = extractAnyTimestamp(from: line) {
                return timestamp
            }
        }
        return nil
    }
}

/// Represents a chunk of transcript for processing
public struct TranscriptChunk {
    public let text: String
    public let startLineIndex: Int
    public let endLineIndex: Int
    public let startTimestamp: String?
    public let endTimestamp: String?
}
