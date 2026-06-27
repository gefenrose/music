import Foundation
import MediaPlayer
import AVFoundation
import UIKit

struct Track: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let assetURL: URL?
    let artwork: MPMediaItemArtwork?   // media library tracks
    let localArtwork: UIImage?          // imported file tracks

    // From the system music library
    init(item: MPMediaItem) {
        self.id = String(item.persistentID)
        self.title = item.title ?? "Unknown Title"
        self.artist = item.artist ?? "Unknown Artist"
        self.album = item.albumTitle ?? "Unknown Album"
        self.duration = item.playbackDuration
        self.assetURL = item.assetURL
        self.artwork = item.artwork
        self.localArtwork = nil
    }

    // From an imported file in the Documents directory
    // Must be called on a background thread (AVAsset loads synchronously).
    init(fileURL: URL) {
        self.id = "local:" + fileURL.lastPathComponent
        self.assetURL = fileURL
        self.artwork = nil

        let asset = AVURLAsset(url: fileURL)
        var title = fileURL.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var artworkImage: UIImage?

        for item in asset.commonMetadata {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                if let v = item.value as? String { title = v }
            case .commonKeyArtist:
                if let v = item.value as? String { artist = v }
            case .commonKeyAlbumName:
                if let v = item.value as? String { album = v }
            case .commonKeyArtwork:
                if let data = item.value as? Data { artworkImage = UIImage(data: data) }
            default:
                break
            }
        }

        self.title = title
        self.artist = artist
        self.album = album
        let d = asset.duration.seconds
        self.duration = d.isFinite && d > 0 ? d : 0
        self.localArtwork = artworkImage
    }

    func artworkImage(size: CGSize) -> UIImage? {
        artwork?.image(at: size) ?? localArtwork
    }

    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }
}

struct AlbumGroup: Identifiable {
    let id: String
    let title: String
    let artist: String
    let tracks: [Track]

    func artworkImage(size: CGSize) -> UIImage? {
        tracks.first?.artworkImage(size: size)
    }
}

struct ArtistGroup: Identifiable {
    let id: String
    let name: String
    let tracks: [Track]
}
