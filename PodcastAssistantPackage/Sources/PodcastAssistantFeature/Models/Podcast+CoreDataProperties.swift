import Foundation
import CoreData

extension Podcast {
    
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Podcast> {
        return NSFetchRequest<Podcast>(entityName: "Podcast")
    }
    
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var podcastDescription: String?
    @NSManaged public var artworkData: Data?
    @NSManaged public var defaultOverlayData: Data?
    @NSManaged public var defaultFontName: String?
    @NSManaged public var defaultFontSize: Double
    @NSManaged public var defaultTextPositionX: Double
    @NSManaged public var defaultTextPositionY: Double
    @NSManaged public var createdAt: Date
    @NSManaged public var episodes: NSSet?
    
    // MARK: - Computed Properties
    
    public var episodesArray: [Episode] {
        let set = episodes as? Set<Episode> ?? []
        return set.sorted { $0.createdAt < $1.createdAt }
    }
    
    // MARK: - Lifecycle
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        setPrimitiveValue(UUID(), forKey: "id")
        setPrimitiveValue(Date(), forKey: "createdAt")
        setPrimitiveValue(72.0, forKey: "defaultFontSize")
        setPrimitiveValue(0.5, forKey: "defaultTextPositionX")
        setPrimitiveValue(0.5, forKey: "defaultTextPositionY")
    }
}

// MARK: - Generated Accessors for Episodes

extension Podcast {
    
    @objc(addEpisodesObject:)
    @NSManaged public func addToEpisodes(_ value: Episode)
    
    @objc(removeEpisodesObject:)
    @NSManaged public func removeFromEpisodes(_ value: Episode)
    
    @objc(addEpisodes:)
    @NSManaged public func addToEpisodes(_ values: NSSet)
    
    @objc(removeEpisodes:)
    @NSManaged public func removeFromEpisodes(_ values: NSSet)
}

extension Podcast: Identifiable {
    
}
