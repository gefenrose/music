import SwiftUI

// MARK: - Library root

struct LibraryView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player:  AudioPlayerService

    @State private var tab: LibraryTab = .songs
    @State private var searchText = ""

    enum LibraryTab: String, CaseIterable {
        case songs   = "Songs"
        case albums  = "Albums"
        case artists = "Artists"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library", selection: $tab) {
                    ForEach(LibraryTab.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if library.isLoading {
                    Spacer()
                    ProgressView("Loading Library…")
                    Spacer()
                } else {
                    switch tab {
                    case .songs:   SongsListView(searchText: searchText)
                    case .albums:  AlbumsListView(searchText: searchText)
                    case .artists: ArtistsListView(searchText: searchText)
                    }
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search")
        }
    }
}

// MARK: - Songs

struct SongsListView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player:  AudioPlayerService
    let searchText: String

    var songs: [Track] {
        searchText.isEmpty ? library.songs
            : library.songs.filter { $0.title.localizedCaseInsensitiveContains(searchText)
                                  || $0.artist.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(songs) { track in
            SongRow(track: track, isPlaying: player.currentTrack?.id == track.id && player.isPlaying)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let idx = library.songs.firstIndex(of: track) {
                        player.play(track: track, queue: library.songs, index: idx)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .listStyle(.plain)
    }
}

struct SongRow: View {
    let track: Track
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkThumbnail(track: track, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .foregroundColor(isPlaying ? .accentColor : .primary)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if isPlaying {
                Image(systemName: "waveform")
                    .foregroundColor(.accentColor)
                    .symbolEffect(.variableColor.iterative)
            } else {
                Text(formatDuration(track.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatDuration(_ s: Double) -> String {
        guard s > 0, s.isFinite else { return "" }
        return String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}

// MARK: - Albums

struct AlbumsListView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player:  AudioPlayerService
    let searchText: String

    var albums: [AlbumGroup] {
        searchText.isEmpty ? library.albums
            : library.albums.filter { $0.title.localizedCaseInsensitiveContains(searchText)
                                   || $0.artist.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(albums) { album in
            NavigationLink {
                AlbumDetailView(album: album).environmentObject(player)
            } label: {
                AlbumRow(album: album)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .listStyle(.plain)
    }
}

struct AlbumRow: View {
    let album: AlbumGroup
    var body: some View {
        HStack(spacing: 12) {
            ArtworkThumbnail(track: album.tracks.first, size: 50)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title).font(.body).lineLimit(1)
                Text(album.artist).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Artists

struct ArtistsListView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player:  AudioPlayerService
    let searchText: String

    var artists: [ArtistGroup] {
        searchText.isEmpty ? library.artists
            : library.artists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List(artists) { artist in
            NavigationLink {
                ArtistDetailView(artist: artist).environmentObject(player)
            } label: {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(artist.name).font(.body).lineLimit(1)
                        Text("\(artist.tracks.count) song\(artist.tracks.count == 1 ? "" : "s")")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Album detail

struct AlbumDetailView: View {
    @EnvironmentObject var player: AudioPlayerService
    let album: AlbumGroup

    var body: some View {
        List {
            AlbumHeaderView(album: album)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())

            HStack(spacing: 12) {
                Button {
                    player.play(track: album.tracks[0], queue: album.tracks, index: 0)
                } label: {
                    Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)

                Button {
                    let shuffled = album.tracks.shuffled()
                    player.play(track: shuffled[0], queue: shuffled, index: 0)
                } label: {
                    Label("Shuffle", systemImage: "shuffle").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).controlSize(.large)
            }
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))

            ForEach(Array(album.tracks.enumerated()), id: \.element.id) { idx, track in
                AlbumTrackRow(track: track, index: idx + 1,
                              isPlaying: player.currentTrack?.id == track.id && player.isPlaying)
                    .contentShape(Rectangle())
                    .onTapGesture { player.play(track: track, queue: album.tracks, index: idx) }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AlbumHeaderView: View {
    let album: AlbumGroup
    @State private var img: UIImage?

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if let img {
                    Image(uiImage: img).resizable().aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                        .overlay(Image(systemName: "music.note").font(.largeTitle).foregroundColor(.secondary))
                }
            }
            .frame(maxWidth: 220)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 12)

            VStack(spacing: 4) {
                Text(album.title).font(.title3).bold().multilineTextAlignment(.center)
                Text(album.artist).font(.subheadline).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .task(id: album.id) {
            img = album.tracks.first?.artworkImage(size: CGSize(width: 440, height: 440))
        }
    }
}

struct AlbumTrackRow: View {
    let track: Track
    let index: Int
    let isPlaying: Bool

    var body: some View {
        HStack {
            Text("\(index)")
                .font(.body.monospacedDigit())
                .foregroundColor(.secondary)
                .frame(width: 28, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .foregroundColor(isPlaying ? .accentColor : .primary)
                    .lineLimit(1)
                if track.artist != track.album {
                    Text(track.artist).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if isPlaying {
                Image(systemName: "waveform").foregroundColor(.accentColor)
                    .symbolEffect(.variableColor.iterative)
            }
        }
    }
}

// MARK: - Artist detail

struct ArtistDetailView: View {
    @EnvironmentObject var player: AudioPlayerService
    let artist: ArtistGroup

    var body: some View {
        List(Array(artist.tracks.enumerated()), id: \.element.id) { idx, track in
            SongRow(track: track, isPlaying: player.currentTrack?.id == track.id && player.isPlaying)
                .contentShape(Rectangle())
                .onTapGesture { player.play(track: track, queue: artist.tracks, index: idx) }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .listStyle(.plain)
        .navigationTitle(artist.name)
    }
}

// MARK: - Shared artwork thumbnail

struct ArtworkThumbnail: View {
    let track: Track?
    let size: CGFloat
    @State private var img: UIImage?

    var body: some View {
        Group {
            if let img {
                Image(uiImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: size * 0.12)
                    .fill(Color(.systemGray5))
                    .overlay(Image(systemName: "music.note")
                        .font(.system(size: size * 0.35)).foregroundColor(.secondary))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
        .task(id: track?.id) {
            img = track?.artworkImage(size: CGSize(width: size * 2, height: size * 2))
        }
    }
}

// MARK: - ArtworkView (used by NowPlayingView)

struct ArtworkView: View {
    let image: UIImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: size * 0.1)
                    .fill(Color(.systemGray5))
                    .overlay(Image(systemName: "music.note")
                        .font(.system(size: size * 0.4)).foregroundColor(.secondary))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.1))
    }
}
