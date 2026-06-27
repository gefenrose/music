import Foundation
import MediaPlayer

// File-level helpers are nonisolated by default — safe to call from any thread
private let _audioExtensions = Set(["mp3", "m4a", "aac", "wav", "aiff", "aif", "flac"])

private var _documentsURL: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
}

private func _buildLibrary() async -> ([Track], [AlbumGroup], [ArtistGroup]) {
    var libraryTracks: [Track] = []
    if MPMediaLibrary.authorizationStatus() == .authorized {
        let items = MPMediaQuery.songs().items ?? []
        libraryTracks = items.compactMap { item -> Track? in
            guard item.assetURL != nil else { return nil }
            return Track(item: item)
        }
    }
    let localTracks = await _scanLocalFiles()
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

    return (allTracks, albumGroups, artistGroups)
}

private func _scanLocalFiles() async -> [Track] {
    let files = (try? FileManager.default.contentsOfDirectory(
        at: _documentsURL,
        includingPropertiesForKeys: nil,
        options: .skipsHiddenFiles
    )) ?? []
    var tracks: [Track] = []
    for url in files where _audioExtensions.contains(url.pathExtension.lowercased()) {
        tracks.append(await Track(fileURL: url))
    }
    return tracks
}

private func _copyFiles(_ urls: [URL]) async {
    for url in urls {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let dest = _documentsURL.appendingPathComponent(url.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: url, to: dest)
        } catch {
            print("Import failed for \(url.lastPathComponent): \(error)")
        }
    }
}

// MARK: -

@MainActor
class MusicLibraryManager: ObservableObject {
    static let shared = MusicLibraryManager()

    @Published var songs: [Track] = []
    @Published var albums: [AlbumGroup] = []
    @Published var artists: [ArtistGroup] = []
    @Published var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @Published var isLoading = false

    private var authorizationRequested = false
    private init() {}

    func requestAuthorization() {
        authorizationStatus = MPMediaLibrary.authorizationStatus()
        guard authorizationStatus == .notDetermined, !authorizationRequested else {
            loadLibrary()
            return
        }
        authorizationRequested = true
        MPMediaLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                self?.loadLibrary()
            }
        }
    }

    func loadLibrary() {
        isLoading = true
        // Task.detached has no actor context → _buildLibrary runs on cooperative thread pool
        let work = Task.detached(priority: .userInitiated) { await _buildLibrary() }
        Task {
            let (songs, albums, artists) = await work.value
            self.songs   = songs
            self.albums  = albums
            self.artists = artists
            self.isLoading = false
        }
    }

    func importFiles(from urls: [URL]) {
        let work = Task.detached(priority: .userInitiated) { await _copyFiles(urls) }
        Task {
            await work.value
            self.loadLibrary()
        }
    }

    func deleteLocalFile(track: Track) {
        guard let url = track.assetURL, track.id.hasPrefix("local:") else { return }
        let work = Task.detached(priority: .userInitiated) {
            try? FileManager.default.removeItem(at: url)
        }
        Task {
            await work.value
            self.loadLibrary()
        }
    }
}
