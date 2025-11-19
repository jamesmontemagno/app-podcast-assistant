import Foundation
import SwiftData

/// EpisodeContent model for storing heavy binary data separate from Episode metadata
/// This allows list views to query lightweight Episode objects without loading large blobs
@Model
public final class EpisodeContent {
    @Attribute(.unique) public var id: String
    
    // Heavy data with external storage
    @Attribute(.externalStorage)
    public var transcriptInputText: String?
    
    @Attribute(.externalStorage)
    public var srtOutputText: String?
    
    @Attribute(.externalStorage)
    public var thumbnailBackgroundData: Data?
    
    @Attribute(.externalStorage)
    public var thumbnailOverlayData: Data?
    
    @Attribute(.externalStorage)
    public var thumbnailOutputData: Data?
    
    @Attribute(.externalStorage)
    public var shrunkTranscript: String?
    
    // Relationship back to episode
    public var episode: Episode?
    
    // MARK: - Initialization
    
    public init(
        transcriptInputText: String? = nil,
        srtOutputText: String? = nil,
        thumbnailBackgroundData: Data? = nil,
        thumbnailOverlayData: Data? = nil,
        thumbnailOutputData: Data? = nil,
        shrunkTranscript: String? = nil
    ) {
        self.id = UUID().uuidString
        self.transcriptInputText = transcriptInputText
        self.srtOutputText = srtOutputText
        self.thumbnailBackgroundData = thumbnailBackgroundData
        self.thumbnailOverlayData = thumbnailOverlayData
        self.thumbnailOutputData = thumbnailOutputData
        self.shrunkTranscript = shrunkTranscript
    }
}

extension EpisodeContent: Identifiable {}
