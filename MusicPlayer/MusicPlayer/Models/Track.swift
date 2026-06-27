import Foundation
import MediaPlayer
import UIKit

struct Track: Identifiable, Equatable {
    let id: MPMediaEntityPersistentID
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let assetURL: URL?
    let artwork: MPMediaItemArtwork?

    init(item: MPMediaItem) {
        self.id = item.persistentID
        self.title = item.title ?? "Unknown Title"
        self.artist = item.artist ?? "Unknown Artist"
        self.album = item.albumTitle ?? "Unknown Album"
        self.duration = item.playbackDuration
        self.assetURL = item.assetURL
        self.artwork = item.artwork
    }

    func artworkImage(size: CGSize) -> UIImage? {
        artwork?.image(at: size)
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

struct AlbumGroup: Identifiable {
    let id: String
    let title: String
    let artist: String
    let tracks: [Track]
    var artwork: MPMediaItemArtwork? { tracks.first?.artwork }
}

struct ArtistGroup: Identifiable {
    let id: String
    let name: String
    let tracks: [Track]
}
