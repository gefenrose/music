import Foundation
import MediaPlayer

@MainActor
class MusicLibraryManager: ObservableObject {
    static let shared = MusicLibraryManager()

    @Published var songs: [Track] = []
    @Published var albums: [AlbumGroup] = []
    @Published var artists: [ArtistGroup] = []
    @Published var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @Published var isLoading = false

    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static let audioExtensions = Set(["mp3", "m4a", "aac", "wav", "aiff", "aif", "flac"])

    private init() {}

    func requestAuthorization() {
        authorizationStatus = MPMediaLibrary.authorizationStatus()
        guard authorizationStatus == .notDetermined else {
            loadLibrary()
            return
        }
        MPMediaLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                self?.loadLibrary()
            }
        }
    }

    func loadLibrary() {
        isLoading = true
        Task(priority: .userInitiated) {
            var libraryTracks: [Track] = []
            if MPMediaLibrary.authorizationStatus() == .authorized {
                let items = MPMediaQuery.songs().items ?? []
                libraryTracks = items.compactMap { item -> Track? in
                    guard item.assetURL != nil else { return nil }
                    return Track(item: item)
                }
            }

            let localTracks = await Self.scanLocalFiles()

            let allTracks = (libraryTracks + localTracks).sorted { $0.title < $1.title }

            let albumDict = Dictionary(grouping: allTracks, by: { $0.album + "|||" + $0.artist })
            let albumGroups = albumDict.map { key, value -> AlbumGroup in
                AlbumGroup(
                    id: key,
                    title: value.first?.album ?? "Unknown",
                    artist: value.first?.artist ?? "Unknown",
                    tracks: value.sorted { $0.title < $1.title }
                )
            }.sorted { $0.title < $1.title }

            let artistDict = Dictionary(grouping: allTracks, by: { $0.artist })
            let artistGroups = artistDict.map { name, value in
                ArtistGroup(id: name, name: name, tracks: value.sorted { $0.title < $1.title })
            }.sorted { $0.name < $1.name }

            self.songs = allTracks
            self.albums = albumGroups
            self.artists = artistGroups
            self.isLoading = false
        }
    }

    func importFiles(from urls: [URL]) {
        Task(priority: .userInitiated) {
            for url in urls {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                let dest = Self.documentsURL.appendingPathComponent(url.lastPathComponent)
                do {
                    if FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.removeItem(at: dest)
                    }
                    try FileManager.default.copyItem(at: url, to: dest)
                } catch {
                    print("Import failed for \(url.lastPathComponent): \(error)")
                }
            }
            self.loadLibrary()
        }
    }

    func deleteLocalFile(track: Track) {
        guard let url = track.assetURL, track.id.hasPrefix("local:") else { return }
        Task(priority: .userInitiated) {
            try? FileManager.default.removeItem(at: url)
            self.loadLibrary()
        }
    }

    private static func scanLocalFiles() async -> [Track] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )) ?? []
        let audioFiles = files.filter { audioExtensions.contains($0.pathExtension.lowercased()) }
        var tracks: [Track] = []
        for url in audioFiles {
            await tracks.append(Track(fileURL: url))
        }
        return tracks
    }
}
