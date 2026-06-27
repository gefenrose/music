import Foundation
import MediaPlayer

class MusicLibraryManager: ObservableObject {
    static let shared = MusicLibraryManager()

    @Published var songs: [Track] = []
    @Published var albums: [AlbumGroup] = []
    @Published var artists: [ArtistGroup] = []
    @Published var authorizationStatus: MPMediaLibraryAuthorizationStatus = .notDetermined
    @Published var isLoading = false

    private init() {}

    func requestAuthorization() {
        authorizationStatus = MPMediaLibrary.authorizationStatus()
        guard authorizationStatus == .notDetermined else {
            if authorizationStatus == .authorized { loadLibrary() }
            return
        }
        MPMediaLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                if status == .authorized { self?.loadLibrary() }
            }
        }
    }

    func loadLibrary() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let query = MPMediaQuery.songs()
            let items = query.items ?? []
            let tracks = items.compactMap { item -> Track? in
                guard item.assetURL != nil else { return nil }
                return Track(item: item)
            }.sorted { $0.title < $1.title }

            let albumDict = Dictionary(grouping: tracks, by: { $0.album + "|||" + $0.artist })
            let albumGroups = albumDict.map { key, value -> AlbumGroup in
                let parts = key.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
                return AlbumGroup(
                    id: key,
                    title: value.first?.album ?? "Unknown",
                    artist: value.first?.artist ?? "Unknown",
                    tracks: value.sorted { $0.title < $1.title }
                )
            }.sorted { $0.title < $1.title }

            let artistDict = Dictionary(grouping: tracks, by: { $0.artist })
            let artistGroups = artistDict.map { name, value in
                ArtistGroup(id: name, name: name, tracks: value.sorted { $0.title < $1.title })
            }.sorted { $0.name < $1.name }

            DispatchQueue.main.async {
                self?.songs = tracks
                self?.albums = albumGroups
                self?.artists = artistGroups
                self?.isLoading = false
            }
        }
    }
}
