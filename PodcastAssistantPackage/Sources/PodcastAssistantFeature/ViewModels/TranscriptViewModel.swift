import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SwiftData

/// ViewModel for transcript conversion functionality
/// Binds directly to SwiftData Episode model
@MainActor
public class TranscriptViewModel: ObservableObject {
    @Published public var isProcessing: Bool = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?
    @Published public var showingExporter: Bool = false
    @Published public var showingImporter: Bool = false
    
    private let converter = TranscriptConverter()
    
    // SwiftData episode
    public let episode: Episode
    private let context: ModelContext
    
    // Computed properties that read/write to Core Data
    public var inputText: String {
        get { episode.transcriptInputText ?? "" }
        set {
            episode.transcriptInputText = newValue.isEmpty ? nil : newValue
            saveContext()
        }
    }
    
    public var outputSRT: String {
        get { episode.srtOutputText ?? "" }
        set {
            episode.srtOutputText = newValue.isEmpty ? nil : newValue
            saveContext()
        }
    }
    
    public init(episode: Episode, context: ModelContext) {
        self.episode = episode
        self.context = context
    }
    
    /// Returns an SRTDocument for the current output
    public var srtDocument: SRTDocument {
        SRTDocument(text: outputSRT)
    }
    
    /// Save the SwiftData context
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    /// Triggers the file importer
    public func importFile() {
        showingImporter = true
    }
    
    /// Handles the imported file from fileImporter
    public func handleImportedFile(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Failed to access file: Permission denied"
                return
            }
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            do {
                let content = try String(contentsOf: url, encoding: .utf8)
                episode.transcriptInputText = content
                saveContext()
                objectWillChange.send()
                errorMessage = nil
                successMessage = "File loaded successfully"
            } catch {
                errorMessage = "Failed to read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = "Failed to import file: \(error.localizedDescription)"
        }
    }
    
    /// Converts the input text to SRT format
    public func convertToSRT() {
        guard !inputText.isEmpty else {
            errorMessage = "Please provide input text"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        successMessage = nil
        
        Task { @MainActor in
            do {
                let srt = try converter.convertToSRT(from: inputText)
                self.episode.srtOutputText = srt
                self.saveContext()
                self.objectWillChange.send()
                self.successMessage = "Conversion successful!"
                self.isProcessing = false
            } catch {
                self.errorMessage = "Conversion failed: \(error.localizedDescription)"
                self.isProcessing = false
            }
        }
    }
    
    /// Triggers the file exporter
    public func exportSRT() {
        guard !outputSRT.isEmpty else {
            errorMessage = "No SRT content to export"
            return
        }
        showingExporter = true
    }
    
    /// Handles the export completion from fileExporter
    public func handleExportCompletion(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            successMessage = "SRT file saved successfully to \(url.lastPathComponent)"
            errorMessage = nil
        case .failure(let error):
            errorMessage = "Failed to save file: \(error.localizedDescription)"
        }
    }
    
    /// Clears all fields
    public func clear() {
        episode.transcriptInputText = nil
        episode.srtOutputText = nil
        saveContext()
        objectWillChange.send()
        errorMessage = nil
        successMessage = nil
    }
}
