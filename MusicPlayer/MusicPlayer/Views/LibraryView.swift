import SwiftUI
import MediaPlayer

struct LibraryView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player: AudioPlayerService
    @State private var selectedSegment = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Picker("Library", selection: $selectedSegment) {
                    Text("Songs").tag(0)
                    Text("Albums").tag(1)
                    Text("Artists").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                if library.authorizationStatus == .denied || library.authorizationStatus == .restricted {
                    ContentUnavailableView(
                        "No Access",
                        systemImage: "lock.fill",
                        description: Text("Go to Settings > Privacy > Media & Apple Music to allow access.")
                    )
                } else if library.isLoading {
                    ProgressView("Loading library…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    switch selectedSegment {
                    case 0: SongsListView()
                    case 1: AlbumsListView()
                    default: ArtistsListView()
                    }
                }
            }
            .navigationTitle("Library")
        }
    }
}

struct SongsListView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player: AudioPlayerService

    var body: some View {
        List(library.songs) { track in
            TrackRow(track: track)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let idx = library.songs.firstIndex(of: track) {
                        player.play(track: track, queue: library.songs, index: idx)
                    }
                }
        }
        .listStyle(.plain)
    }
}

struct AlbumsListView: View {
    @EnvironmentObject var library: MusicLibraryManager

    var body: some View {
        List(library.albums) { album in
            NavigationLink(destination: AlbumDetailView(album: album)) {
                HStack(spacing: 12) {
                    ArtworkView(artwork: album.artwork, size: 50)
                    VStack(alignment: .leading) {
                        Text(album.title).font(.headline)
                        Text(album.artist).font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

struct AlbumDetailView: View {
    @EnvironmentObject var player: AudioPlayerService
    let album: AlbumGroup

    var body: some View {
        List(album.tracks) { track in
            TrackRow(track: track)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let idx = album.tracks.firstIndex(of: track) {
                        player.play(track: track, queue: album.tracks, index: idx)
                    }
                }
        }
        .navigationTitle(album.title)
        .listStyle(.plain)
    }
}

struct ArtistsListView: View {
    @EnvironmentObject var library: MusicLibraryManager

    var body: some View {
        List(library.artists) { artist in
            NavigationLink(destination: ArtistDetailView(artist: artist)) {
                VStack(alignment: .leading) {
                    Text(artist.name).font(.headline)
                    Text("\(artist.tracks.count) song\(artist.tracks.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.plain)
    }
}

struct ArtistDetailView: View {
    @EnvironmentObject var player: AudioPlayerService
    let artist: ArtistGroup

    var body: some View {
        List(artist.tracks) { track in
            TrackRow(track: track)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let idx = artist.tracks.firstIndex(of: track) {
                        player.play(track: track, queue: artist.tracks, index: idx)
                    }
                }
        }
        .navigationTitle(artist.name)
        .listStyle(.plain)
    }
}

struct TrackRow: View {
    @EnvironmentObject var player: AudioPlayerService
    let track: Track

    var isCurrentTrack: Bool { player.currentTrack == track }

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(artwork: track.artwork, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .foregroundColor(isCurrentTrack ? .accentColor : .primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isCurrentTrack && player.isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(.accentColor)
                    .symbolEffect(.variableColor)
            }
            Text(formatDuration(track.duration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct ArtworkView: View {
    let artwork: MPMediaItemArtwork?
    let size: CGFloat

    var body: some View {
        Group {
            if let image = artwork?.image(at: CGSize(width: size, height: size)) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGray5))
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(size * 0.1)
    }
}
