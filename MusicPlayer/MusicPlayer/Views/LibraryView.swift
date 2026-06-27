import SwiftUI

// MARK: - View Mode

enum LibraryViewMode: String {
    case list, grid, card
}

// MARK: - View mode picker toolbar item

struct ViewModePicker: View {
    @Binding var mode: LibraryViewMode

    var body: some View {
        Menu {
            Button { mode = .list } label: { Label("List",  systemImage: "list.bullet") }
            Button { mode = .grid } label: { Label("Grid",  systemImage: "square.grid.2x2") }
            Button { mode = .card } label: { Label("Card",  systemImage: "rectangle.stack") }
        } label: {
            Image(systemName: iconName)
        }
    }

    private var iconName: String {
        switch mode {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        case .card: return "rectangle.stack"
        }
    }
}

// MARK: - Library root

struct LibraryView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player:  AudioPlayerService

    @State private var tab: LibraryTab = .songs
    @State private var searchText = ""

    @AppStorage("viewMode.songs")   private var songsModeRaw:   String = LibraryViewMode.list.rawValue
    @AppStorage("viewMode.albums")  private var albumsModeRaw:  String = LibraryViewMode.grid.rawValue
    @AppStorage("viewMode.artists") private var artistsModeRaw: String = LibraryViewMode.list.rawValue

    private var songsMode:   LibraryViewMode { LibraryViewMode(rawValue: songsModeRaw)   ?? .list }
    private var albumsMode:  LibraryViewMode { LibraryViewMode(rawValue: albumsModeRaw)  ?? .grid }
    private var artistsMode: LibraryViewMode { LibraryViewMode(rawValue: artistsModeRaw) ?? .list }

    enum LibraryTab: String, CaseIterable {
        case songs   = "Songs"
        case albums  = "Albums"
        case artists = "Artists"
    }

    private var currentModeBinding: Binding<LibraryViewMode> {
        switch tab {
        case .songs:   return Binding(get: { self.songsMode },   set: { self.songsModeRaw   = $0.rawValue })
        case .albums:  return Binding(get: { self.albumsMode },  set: { self.albumsModeRaw  = $0.rawValue })
        case .artists: return Binding(get: { self.artistsMode }, set: { self.artistsModeRaw = $0.rawValue })
        }
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
                    case .songs:
                        SongsListView(searchText: searchText, mode: songsMode)
                    case .albums:
                        AlbumsListView(searchText: searchText, mode: albumsMode)
                    case .artists:
                        ArtistsListView(searchText: searchText, mode: artistsMode)
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ViewModePicker(mode: currentModeBinding)
                }
            }
            .searchable(text: $searchText, prompt: "Search")
        }
    }
}

// MARK: - Songs

struct SongsListView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player:  AudioPlayerService
    let searchText: String
    let mode: LibraryViewMode

    var songs: [Track] {
        searchText.isEmpty ? library.songs
            : library.songs.filter { $0.title.localizedCaseInsensitiveContains(searchText)
                                  || $0.artist.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        switch mode {
        case .list: songsList
        case .grid: songsGrid
        case .card: songsCards
        }
    }

    // List
    private var songsList: some View {
        List(songs) { track in
            SongRow(track: track, isPlaying: player.currentTrack?.id == track.id && player.isPlaying)
                .contentShape(Rectangle())
                .onTapGesture { playTrack(track) }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        }
        .listStyle(.plain)
    }

    // Grid (2 columns)
    private var songsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(songs) { track in
                    SongGridCell(track: track, isPlaying: player.currentTrack?.id == track.id && player.isPlaying)
                        .onTapGesture { playTrack(track) }
                }
            }
            .padding()
        }
    }

    // Card (full-width horizontal cards)
    private var songsCards: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(songs) { track in
                    SongCard(track: track, isPlaying: player.currentTrack?.id == track.id && player.isPlaying)
                        .onTapGesture { playTrack(track) }
                }
            }
            .padding()
        }
    }

    private func playTrack(_ track: Track) {
        if let idx = library.songs.firstIndex(of: track) {
            player.play(track: track, queue: library.songs, index: idx)
        }
    }
}

struct SongGridCell: View {
    let track: Track
    let isPlaying: Bool
    @State private var img: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let img { Image(uiImage: img).resizable().aspectRatio(contentMode: .fill) }
                    else { Color(.systemGray5).overlay(Image(systemName: "music.note").foregroundColor(.secondary)) }
                }
                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                if isPlaying {
                    Image(systemName: "waveform").foregroundColor(.accentColor)
                        .symbolEffect(.variableColor.iterative)
                        .padding(6).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .padding(4)
                }
            }
            Text(track.title).font(.caption).bold().lineLimit(1).foregroundColor(isPlaying ? .accentColor : .primary)
            Text(track.artist).font(.caption2).foregroundColor(.secondary).lineLimit(1)
        }
        .task(id: track.id) { img = track.artworkImage(size: CGSize(width: 200, height: 200)) }
    }
}

struct SongCard: View {
    let track: Track
    let isPlaying: Bool
    @State private var img: UIImage?

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let img { Image(uiImage: img).resizable().aspectRatio(contentMode: .fill) }
                else { Color(.systemGray5).overlay(Image(systemName: "music.note").foregroundColor(.secondary)) }
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title).font(.body).bold().lineLimit(1).foregroundColor(isPlaying ? .accentColor : .primary)
                Text(track.artist).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                Text(track.album).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer()
            if isPlaying {
                Image(systemName: "waveform").foregroundColor(.accentColor)
                    .symbolEffect(.variableColor.iterative)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .task(id: track.id) { img = track.artworkImage(size: CGSize(width: 140, height: 140)) }
    }
}

// MARK: - Albums

struct AlbumsListView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player:  AudioPlayerService
    let searchText: String
    let mode: LibraryViewMode

    var albums: [AlbumGroup] {
        searchText.isEmpty ? library.albums
            : library.albums.filter { $0.title.localizedCaseInsensitiveContains(searchText)
                                   || $0.artist.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        switch mode {
        case .list: albumsList
        case .grid: albumsGrid
        case .card: albumsCards
        }
    }

    private var albumsList: some View {
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

    private var albumsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(albums) { album in
                    NavigationLink {
                        AlbumDetailView(album: album).environmentObject(player)
                    } label: {
                        AlbumGridCell(album: album)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private var albumsCards: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(albums) { album in
                    NavigationLink {
                        AlbumDetailView(album: album).environmentObject(player)
                    } label: {
                        AlbumCard(album: album)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

struct AlbumGridCell: View {
    let album: AlbumGroup
    @State private var img: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let img { Image(uiImage: img).resizable().aspectRatio(contentMode: .fill) }
                else { Color(.systemGray5).overlay(Image(systemName: "music.note").foregroundColor(.secondary)) }
            }
            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(album.title).font(.caption).bold().lineLimit(1)
            Text(album.artist).font(.caption2).foregroundColor(.secondary).lineLimit(1)
        }
        .task(id: album.id) { img = album.tracks.first?.artworkImage(size: CGSize(width: 200, height: 200)) }
    }
}

struct AlbumCard: View {
    let album: AlbumGroup
    @State private var img: UIImage?

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if let img { Image(uiImage: img).resizable().aspectRatio(contentMode: .fill) }
                else { Color(.systemGray5).overlay(Image(systemName: "music.note").foregroundColor(.secondary)) }
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title).font(.body).bold().lineLimit(1)
                Text(album.artist).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
                Text("\(album.tracks.count) song\(album.tracks.count == 1 ? "" : "s")")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .task(id: album.id) { img = album.tracks.first?.artworkImage(size: CGSize(width: 140, height: 140)) }
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
    let mode: LibraryViewMode

    var artists: [ArtistGroup] {
        searchText.isEmpty ? library.artists
            : library.artists.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        switch mode {
        case .list: artistsList
        case .grid: artistsGrid
        case .card: artistsCards
        }
    }

    private var artistsList: some View {
        List(artists) { artist in
            NavigationLink {
                ArtistDetailView(artist: artist).environmentObject(player)
            } label: {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 36)).foregroundColor(.secondary)
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

    private var artistsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(artists) { artist in
                    NavigationLink {
                        ArtistDetailView(artist: artist).environmentObject(player)
                    } label: {
                        ArtistGridCell(artist: artist)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }

    private var artistsCards: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(artists) { artist in
                    NavigationLink {
                        ArtistDetailView(artist: artist).environmentObject(player)
                    } label: {
                        ArtistCard(artist: artist)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}

struct ArtistGridCell: View {
    let artist: ArtistGroup

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 70)).foregroundColor(.secondary)
                .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
            Text(artist.name).font(.caption).bold().lineLimit(1)
            Text("\(artist.tracks.count) song\(artist.tracks.count == 1 ? "" : "s")")
                .font(.caption2).foregroundColor(.secondary)
        }
    }
}

struct ArtistCard: View {
    let artist: ArtistGroup

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 50)).foregroundColor(.secondary)
                .frame(width: 70, height: 70)

            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name).font(.body).bold().lineLimit(1)
                Text("\(artist.tracks.count) song\(artist.tracks.count == 1 ? "" : "s")")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
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

// MARK: - Song row (shared)

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
