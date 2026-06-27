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

    // From an imported file — uses the modern async AVAsset load() API (no deprecation warnings).
    init(fileURL: URL) async {
        self.id = "local:" + fileURL.lastPathComponent
        self.assetURL = fileURL
        self.artwork = nil

        let asset = AVURLAsset(url: fileURL)
        var title = fileURL.deletingPathExtension().lastPathComponent
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var artworkImage: UIImage?

        let metadata = (try? await asset.load(.commonMetadata)) ?? []
        for item in metadata {
            guard let key = item.commonKey else { continue }
            switch key {
            case .commonKeyTitle:
                title = (try? await item.load(.stringValue)) ?? title
            case .commonKeyArtist:
                artist = (try? await item.load(.stringValue)) ?? artist
            case .commonKeyAlbumName:
                album = (try? await item.load(.stringValue)) ?? album
            case .commonKeyArtwork:
                if let data = try? await item.load(.dataValue) {
                    artworkImage = UIImage(data: data)
                }
            default:
                break
            }
        }

        self.title = title
        self.artist = artist
        self.album = album

        let cmDuration = try? await asset.load(.duration)
        let d = cmDuration.map { CMTimeGetSeconds($0) } ?? 0
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
