import Foundation

/// Service responsible for converting text transcripts to SRT format
public class TranscriptConverter {
    
    public init() {}
    
    /// Debug information from the last conversion
    public private(set) var lastDebugInfo: ConversionDebugInfo?
    
    /// Converts a text file content to SRT format
    /// - Parameter textContent: The raw text content from the transcript file
    /// - Returns: SRT formatted string ready for YouTube
    /// - Throws: ConversionError if the format is invalid
    public func convertToSRT(from textContent: String) throws -> String {
        // Detect format and convert accordingly
        let format = detectFormat(textContent)
        
        var debugInfo = ConversionDebugInfo()
        debugInfo.detectedFormat = format
        debugInfo.inputLines = textContent.components(separatedBy: .newlines).count
        debugInfo.inputCharacters = textContent.count
        
        let result: String
        do {
            switch format {
            case .zencastr:
                result = try convertZencastrFormat(textContent, debugInfo: &debugInfo)
            case .timeRange:
                result = try convertTimeRangeFormat(textContent)
            case .unknown:
                debugInfo.errorMessage = "Could not detect format. Expected Zencastr (MM:SS.ss) or Time Range (HH:MM:SS - HH:MM:SS) format."
                throw ConversionError.invalidFormat
            }
            
            debugInfo.outputEntries = result.components(separatedBy: "\n\n").filter { !$0.isEmpty }.count
            debugInfo.success = true
            lastDebugInfo = debugInfo
            return result
        } catch {
            debugInfo.success = false
            debugInfo.errorMessage = error.localizedDescription
            lastDebugInfo = debugInfo
            throw error
        }
    }
    
    /// Detects the transcript format
    private func detectFormat(_ content: String) -> TranscriptFormat {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Check for Zencastr format: MM:SS.ss or HH:MM:SS.ss on its own line
        let zencastrShortPattern = #"^\d{1,2}:\d{2}\.\d{2}$"#  // MM:SS.ss
        let zencastrLongPattern = #"^\d{1,2}:\d{2}:\d{2}\.\d{2}$"#  // HH:MM:SS.ss
        let zencastrShortRegex = try? NSRegularExpression(pattern: zencastrShortPattern)
        let zencastrLongRegex = try? NSRegularExpression(pattern: zencastrLongPattern)
        
        // Check for time range format: HH:MM:SS - HH:MM:SS
        let timeRangePattern = #"\d{1,2}:\d{2}:\d{2}\s*[-–>]+\s*\d{1,2}:\d{2}:\d{2}"#
        let timeRangeRegex = try? NSRegularExpression(pattern: timeRangePattern)
        
        var zencastrMatches = 0
        var timeRangeMatches = 0
        
        for line in lines.prefix(50) {
            // Check both Zencastr patterns
            if let regex = zencastrShortRegex {
                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, options: [], range: range) != nil {
                    zencastrMatches += 1
                }
            }
            
            if let regex = zencastrLongRegex {
                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, options: [], range: range) != nil {
                    zencastrMatches += 1
                }
            }
            
            if let regex = timeRangeRegex {
                let range = NSRange(line.startIndex..., in: line)
                if regex.firstMatch(in: line, options: [], range: range) != nil {
                    timeRangeMatches += 1
                }
            }
        }
        
        if zencastrMatches > timeRangeMatches && zencastrMatches > 2 {
            return .zencastr
        } else if timeRangeMatches > 0 {
            return .timeRange
        }
        
        return .unknown
    }
    
    /// Converts Zencastr format (MM:SS.ss timestamp, speaker name, text)
    private func convertZencastrFormat(_ content: String, debugInfo: inout ConversionDebugInfo) throws -> String {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        var srtOutput = ""
        var index = 1
        var i = 0
        
        var currentTimestamp: String?
        var currentSpeaker: String?
        var currentText: [String] = []
        var timestampCount = 0
        var speakerCount = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // Skip empty lines
            if line.isEmpty {
                i += 1
                continue
            }
            
            // Check if this is a timestamp (MM:SS.ss format)
            if let timestamp = parseZencastrTimestamp(line) {
                timestampCount += 1
                
                // If we have accumulated content, write it out
                if let ts = currentTimestamp, !currentText.isEmpty {
                    let combinedText = currentText.joined(separator: " ")
                    let speakerPrefix = currentSpeaker.map { "\($0): " } ?? ""
                    
                    srtOutput += "\(index)\n"
                    srtOutput += "\(ts)\n"
                    srtOutput += "\(speakerPrefix)\(combinedText)\n\n"
                    index += 1
                }
                
                // Start new entry
                currentTimestamp = timestamp
                currentSpeaker = nil
                currentText = []
                
                // Next line might be speaker name
                if i + 1 < lines.count {
                    i += 1
                    let nextLine = lines[i].trimmingCharacters(in: .whitespaces)
                    
                    // If next line is not empty and not a timestamp, it's likely a speaker name
                    if !nextLine.isEmpty && parseZencastrTimestamp(nextLine) == nil {
                        // Check if it looks like a name (single word or short phrase, capitalized)
                        // Zencastr format: timestamp then speaker name (short, no punctuation)
                        let words = nextLine.components(separatedBy: .whitespaces)
                        if words.count <= 2 && nextLine.count < 30 && nextLine.first?.isUppercase == true && !nextLine.contains(".") && !nextLine.contains(",") {
                            currentSpeaker = nextLine
                            speakerCount += 1
                        } else {
                            // This is actually the text content
                            currentText.append(nextLine)
                        }
                    } else {
                        // Go back one line if empty or another timestamp
                        i -= 1
                    }
                }
            } else {
                // This is dialog text - accumulate it
                if !line.isEmpty {
                    currentText.append(line)
                }
            }
            
            i += 1
        }
        
        // Write out the last entry
        if let ts = currentTimestamp, !currentText.isEmpty {
            let combinedText = currentText.joined(separator: " ")
            let speakerPrefix = currentSpeaker.map { "\($0): " } ?? ""
            
            srtOutput += "\(index)\n"
            srtOutput += "\(ts)\n"
            srtOutput += "\(speakerPrefix)\(combinedText)\n\n"
        }
        
        // Store debug info
        debugInfo.timestampsFound = timestampCount
        debugInfo.speakersFound = speakerCount
        debugInfo.entriesGenerated = index - 1
        
        if srtOutput.isEmpty {
            debugInfo.errorMessage = "No valid entries generated. Found \(timestampCount) timestamps but couldn't create SRT entries."
            throw ConversionError.noTimestampsFound
        }
        
        return srtOutput
    }
    
    /// Parses Zencastr timestamp (MM:SS.ss or HH:MM:SS.ss) and creates end time
    private func parseZencastrTimestamp(_ line: String) -> String? {
        // Try HH:MM:SS.ss format first (for longer episodes)
        let longPattern = #"^(\d{1,2}):(\d{2}):(\d{2})\.(\d{2})$"#
        if let regex = try? NSRegularExpression(pattern: longPattern),
           let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)),
           let hoursRange = Range(match.range(at: 1), in: line),
           let minutesRange = Range(match.range(at: 2), in: line),
           let secondsRange = Range(match.range(at: 3), in: line),
           let centisecondsRange = Range(match.range(at: 4), in: line),
           let hours = Int(line[hoursRange]),
           let minutes = Int(line[minutesRange]),
           let seconds = Int(line[secondsRange]),
           let centiseconds = Int(line[centisecondsRange]) {
            
            // Convert to total centiseconds
            let totalCentiseconds = (hours * 3600 * 100) + (minutes * 60 * 100) + (seconds * 100) + centiseconds
            
            // Create end time (5 seconds later by default)
            let endCentiseconds = totalCentiseconds + 500
            
            // Format as SRT timestamps
            let startTime = formatSRTTimestamp(centiseconds: totalCentiseconds)
            let endTime = formatSRTTimestamp(centiseconds: endCentiseconds)
            
            return "\(startTime) --> \(endTime)"
        }
        
        // Try MM:SS.ss format (for shorter episodes)
        let shortPattern = #"^(\d{1,2}):(\d{2})\.(\d{2})$"#
        if let regex = try? NSRegularExpression(pattern: shortPattern),
           let match = regex.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)),
           let minutesRange = Range(match.range(at: 1), in: line),
           let secondsRange = Range(match.range(at: 2), in: line),
           let centisecondsRange = Range(match.range(at: 3), in: line),
           let minutes = Int(line[minutesRange]),
           let seconds = Int(line[secondsRange]),
           let centiseconds = Int(line[centisecondsRange]) {
            
            // Convert to total centiseconds
            let totalCentiseconds = (minutes * 60 * 100) + (seconds * 100) + centiseconds
            
            // Create end time (5 seconds later by default)
            let endCentiseconds = totalCentiseconds + 500
            
            // Format as SRT timestamps
            let startTime = formatSRTTimestamp(centiseconds: totalCentiseconds)
            let endTime = formatSRTTimestamp(centiseconds: endCentiseconds)
            
            return "\(startTime) --> \(endTime)"
        }
        
        return nil
    }
    
    /// Formats centiseconds as SRT timestamp (HH:MM:SS,mmm)
    private func formatSRTTimestamp(centiseconds: Int) -> String {
        let hours = centiseconds / 360000
        let minutes = (centiseconds % 360000) / 6000
        let seconds = (centiseconds % 6000) / 100
        let milliseconds = (centiseconds % 100) * 10
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
    
    /// Converts time range format (HH:MM:SS - HH:MM:SS text)
    private func convertTimeRangeFormat(_ content: String) throws -> String {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var srtOutput = ""
        var index = 1
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            
            // Check if this line contains a timestamp pattern
            if let timeRange = extractTimeRange(from: line) {
                // This is a timestamp line
                let timestamp = timeRange
                
                // Get the text (could be on same line or next line)
                var text = ""
                let remainingText = line.replacingOccurrences(of: extractTimeRangeOriginal(from: line) ?? "", with: "").trimmingCharacters(in: .whitespaces)
                
                if !remainingText.isEmpty {
                    text = remainingText
                } else if i + 1 < lines.count {
                    // Text is on the next line
                    i += 1
                    text = lines[i]
                }
                
                // Format as SRT entry
                srtOutput += "\(index)\n"
                srtOutput += "\(timestamp)\n"
                srtOutput += "\(text)\n\n"
                
                index += 1
            }
            
            i += 1
        }
        
        if srtOutput.isEmpty {
            throw ConversionError.noTimestampsFound
        }
        
        return srtOutput
    }
    
    /// Extracts time range from a line and returns original string
    private func extractTimeRangeOriginal(from line: String) -> String? {
        let pattern = #"\d{1,2}:\d{2}:\d{2}\s*[-–>]+\s*\d{1,2}:\d{2}:\d{2}"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let range = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              let matchRange = Range(match.range, in: line) else {
            return nil
        }
        
        return String(line[matchRange])
    }
    
    /// Extracts time range from a line (e.g., "00:00:00 - 00:00:05" or "00:00:00 --> 00:00:05")
    private func extractTimeRange(from line: String) -> String? {
        guard let original = extractTimeRangeOriginal(from: line) else { return nil }
        
        // Convert to SRT format with " --> " and proper comma separators
        let converted = original.replacingOccurrences(of: #"\s*[-–]+\s*"#, with: " --> ", options: .regularExpression)
        
        // Convert colons to commas for milliseconds if needed (SRT uses comma for milliseconds)
        // HH:MM:SS.mmm -> HH:MM:SS,mmm
        return converted.replacingOccurrences(of: #"(\d{2}:\d{2}:\d{2})\.(\d{3})"#, with: "$1,$2", options: .regularExpression)
    }
    
    public enum TranscriptFormat {
        case zencastr    // MM:SS.ss or HH:MM:SS.ss format with speaker names
        case timeRange   // HH:MM:SS - HH:MM:SS format
        case unknown
    }
    
    public enum ConversionError: LocalizedError {
        case invalidFormat
        case noTimestampsFound
        
        public var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Invalid transcript format. Unable to detect a supported format."
            case .noTimestampsFound:
                return "No timestamps found in the transcript."
            }
        }
    }
}

/// Debug information from transcript conversion
public struct ConversionDebugInfo {
    public var detectedFormat: TranscriptConverter.TranscriptFormat = .unknown
    public var inputLines: Int = 0
    public var inputCharacters: Int = 0
    public var timestampsFound: Int = 0
    public var speakersFound: Int = 0
    public var entriesGenerated: Int = 0
    public var outputEntries: Int = 0
    public var success: Bool = false
    public var errorMessage: String?
    
    public var formatDescription: String {
        switch detectedFormat {
        case .zencastr:
            return "Zencastr Format (MM:SS.ss or HH:MM:SS.ss)"
        case .timeRange:
            return "Time Range Format (HH:MM:SS - HH:MM:SS)"
        case .unknown:
            return "Unknown Format"
        }
    }
}

extension TranscriptConverter.TranscriptFormat {
    var description: String {
        switch self {
        case .zencastr:
            return "Zencastr"
        case .timeRange:
            return "TimeRange"
        case .unknown:
            return "Unknown"
        }
    }
}
