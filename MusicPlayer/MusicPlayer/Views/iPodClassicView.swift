import SwiftUI
import MediaPlayer

enum iPodPage: Hashable {
    case mainMenu, musicMenu, songs, albums, artists, nowPlaying, settings
    case albumDetail(String)
    case artistDetail(String)
}

struct iPodClassicView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player: AudioPlayerService
    @EnvironmentObject var lastFM: LastFMService

    @State private var pageStack: [iPodPage] = [.mainMenu]
    @State private var selectedIndices: [iPodPage: Int] = [:]
    @State private var scrollAccum: CGFloat = 0
    @State private var showLastFMSettings = false

    var currentPage: iPodPage { pageStack.last ?? .mainMenu }

    var selectedIndex: Int { selectedIndices[currentPage] ?? 0 }

    func setSelected(_ i: Int) { selectedIndices[currentPage] = i }

    // MARK: - Menu data

    struct MenuItem {
        let title: String
        let detail: String?
        let hasArrow: Bool
    }

    var menuItems: [MenuItem] {
        switch currentPage {
        case .mainMenu:
            return [
                MenuItem(title: "Music", detail: nil, hasArrow: true),
                MenuItem(title: "Now Playing", detail: nil, hasArrow: false),
                MenuItem(title: "Last.fm", detail: lastFM.isAuthenticated ? lastFM.username : "Not connected", hasArrow: true)
            ]
        case .musicMenu:
            return [
                MenuItem(title: "Songs", detail: "\(library.songs.count)", hasArrow: true),
                MenuItem(title: "Albums", detail: "\(library.albums.count)", hasArrow: true),
                MenuItem(title: "Artists", detail: "\(library.artists.count)", hasArrow: true)
            ]
        case .songs:
            return library.songs.map { MenuItem(title: $0.title, detail: $0.artist, hasArrow: false) }
        case .albums:
            return library.albums.map { MenuItem(title: $0.title, detail: $0.artist, hasArrow: true) }
        case .albumDetail(let id):
            let tracks = library.albums.first { $0.id == id }?.tracks ?? []
            return tracks.map { MenuItem(title: $0.title, detail: formatTime($0.duration), hasArrow: false) }
        case .artists:
            return library.artists.map { MenuItem(title: $0.name, detail: "\($0.tracks.count) songs", hasArrow: true) }
        case .artistDetail(let id):
            let tracks = library.artists.first { $0.id == id }?.tracks ?? []
            return tracks.map { MenuItem(title: $0.title, detail: $0.album, hasArrow: false) }
        case .nowPlaying, .settings:
            return []
        }
    }

    var pageTitle: String {
        switch currentPage {
        case .mainMenu: return "iPod"
        case .musicMenu: return "Music"
        case .songs: return "Songs"
        case .albums: return "Albums"
        case .albumDetail(let id): return library.albums.first { $0.id == id }?.title ?? "Album"
        case .artists: return "Artists"
        case .artistDetail(let id): return library.artists.first { $0.id == id }?.name ?? "Artist"
        case .nowPlaying: return "Now Playing"
        case .settings: return "Settings"
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // iPod white body
                LinearGradient(
                    colors: [Color(white: 0.97), Color(white: 0.91)],
                    startPoint: .top, endPoint: .bottom
                )

                VStack(spacing: 0) {
                    // ── Screen ──
                    screenArea
                        .frame(height: geo.size.height * 0.40)
                        .padding(.horizontal, 22)
                        .padding(.top, geo.safeAreaInsets.top + 14)

                    Spacer()

                    // ── Click wheel ──
                    let wheelDiam = min(geo.size.width * 0.80, 310.0)
                    ClickWheelView(
                        onMenu: navigateBack,
                        onPrevious: handlePrevious,
                        onNext: handleNext,
                        onPlayPause: { player.togglePlayPause(); feedback(.medium) },
                        onCenter: handleCenter,
                        onScroll: handleScroll
                    )
                    .frame(width: wheelDiam, height: wheelDiam)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 18)
                }
            }
        }
        .sheet(isPresented: $showLastFMSettings) {
            SettingsView().environmentObject(lastFM)
        }
        .onChange(of: currentPage) { _, _ in
            selectedIndices[currentPage] = selectedIndices[currentPage] ?? 0
        }
    }

    // MARK: - Screen area

    var screenArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(white: 0.96))
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(white: 0.65), lineWidth: 0.8)
                )

            if currentPage == .nowPlaying {
                nowPlayingScreen
            } else {
                menuScreen
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Now Playing screen

    var nowPlayingScreen: some View {
        VStack(spacing: 0) {
            // Title bar
            iPodTitleBar(title: "Now Playing")

            if let track = player.currentTrack {
                HStack(alignment: .top, spacing: 10) {
                    // Album art
                    Group {
                        if let img = track.artworkImage(size: CGSize(width: 100, height: 100)) {
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                Color(white: 0.82)
                                Image(systemName: "music.note")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(white: 0.55))
                            }
                        }
                    }
                    .frame(width: 90, height: 90)
                    .cornerRadius(4)
                    .padding(.leading, 8)
                    .padding(.top, 8)

                    // Track info
                    VStack(alignment: .leading, spacing: 5) {
                        Text(track.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(2)
                            .foregroundColor(.black)
                        Text(track.artist)
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.35))
                            .lineLimit(1)
                        Text(track.album)
                            .font(.system(size: 10))
                            .foregroundColor(Color(white: 0.5))
                            .lineLimit(1)
                    }
                    .padding(.top, 10)
                    .padding(.trailing, 8)

                    Spacer()
                }

                Spacer()

                // Progress bar
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(white: 0.8))
                        let pct = player.duration > 0 ? CGFloat(player.currentTime / player.duration) : 0
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.25, green: 0.52, blue: 1.0), Color(red: 0.15, green: 0.4, blue: 0.9)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .frame(width: g.size.width * pct)
                    }
                    .cornerRadius(2)
                }
                .frame(height: 5)
                .padding(.horizontal, 10)

                // Timestamps
                HStack {
                    Text(formatTime(player.currentTime))
                    Spacer()
                    Text("-" + formatTime(max(0, player.duration - player.currentTime)))
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(white: 0.45))
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .padding(.top, 3)

            } else {
                Spacer()
                Text("Nothing Playing")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.5))
                Spacer()
            }
        }
    }

    // MARK: - Menu screen

    var menuScreen: some View {
        VStack(spacing: 0) {
            iPodTitleBar(title: pageTitle)

            if library.isLoading {
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(menuItems.enumerated()), id: \.offset) { idx, item in
                                menuRow(item: item, index: idx)
                                    .id(idx)
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { _, val in
                        withAnimation(.none) { proxy.scrollTo(val, anchor: .center) }
                    }
                }
            }
        }
    }

    func menuRow(item: MenuItem, index: Int) -> some View {
        let sel = index == selectedIndex
        return HStack(spacing: 6) {
            Text(item.title)
                .font(.system(size: 11.5, weight: sel ? .semibold : .regular))
                .foregroundColor(sel ? .white : .black)
                .lineLimit(1)
            Spacer()
            if let d = item.detail {
                Text(d)
                    .font(.system(size: 10))
                    .foregroundColor(sel ? .white.opacity(0.8) : Color(white: 0.55))
                    .lineLimit(1)
            }
            if item.hasArrow {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(sel ? .white.opacity(0.8) : Color(white: 0.6))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            sel
            ? AnyView(LinearGradient(
                colors: [Color(red: 0.22, green: 0.48, blue: 0.98), Color(red: 0.14, green: 0.38, blue: 0.88)],
                startPoint: .top, endPoint: .bottom
            ))
            : AnyView(Color.clear)
        )
        .overlay(
            Rectangle()
                .fill(Color(white: 0.82))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - Navigation

    func navigateBack() {
        feedback(.medium)
        guard pageStack.count > 1 else { return }
        pageStack.removeLast()
    }

    func handleCenter() {
        feedback(.medium)
        let idx = selectedIndex
        switch currentPage {
        case .mainMenu:
            switch idx {
            case 0: pageStack.append(.musicMenu)
            case 1: pageStack.append(.nowPlaying)
            case 2: showLastFMSettings = true
            default: break
            }
        case .musicMenu:
            switch idx {
            case 0: pageStack.append(.songs)
            case 1: pageStack.append(.albums)
            case 2: pageStack.append(.artists)
            default: break
            }
        case .songs:
            guard idx < library.songs.count else { return }
            player.play(track: library.songs[idx], queue: library.songs, index: idx)
            pageStack.append(.nowPlaying)
        case .albums:
            guard idx < library.albums.count else { return }
            pageStack.append(.albumDetail(library.albums[idx].id))
        case .albumDetail(let id):
            let tracks = library.albums.first { $0.id == id }?.tracks ?? []
            guard idx < tracks.count else { return }
            player.play(track: tracks[idx], queue: tracks, index: idx)
            pageStack.append(.nowPlaying)
        case .artists:
            guard idx < library.artists.count else { return }
            pageStack.append(.artistDetail(library.artists[idx].id))
        case .artistDetail(let id):
            let tracks = library.artists.first { $0.id == id }?.tracks ?? []
            guard idx < tracks.count else { return }
            player.play(track: tracks[idx], queue: tracks, index: idx)
            pageStack.append(.nowPlaying)
        case .nowPlaying:
            player.togglePlayPause()
        case .settings:
            break
        }
    }

    func handleScroll(_ delta: CGFloat) {
        let items = menuItems
        guard !items.isEmpty, currentPage != .nowPlaying else { return }
        scrollAccum += delta
        let threshold: CGFloat = 0.18
        while abs(scrollAccum) >= threshold {
            let step = scrollAccum > 0 ? 1 : -1
            scrollAccum -= CGFloat(step) * threshold
            let newIdx = max(0, min(items.count - 1, selectedIndex + step))
            if newIdx != selectedIndex {
                setSelected(newIdx)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    func handlePrevious() {
        feedback(.medium)
        if currentPage == .nowPlaying {
            player.previous()
        } else {
            setSelected(max(0, selectedIndex - 1))
        }
    }

    func handleNext() {
        feedback(.medium)
        if currentPage == .nowPlaying {
            player.next()
        } else {
            setSelected(min(menuItems.count - 1, selectedIndex + 1))
        }
    }

    func feedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func formatTime(_ s: Double) -> String {
        guard s.isFinite else { return "0:00" }
        return String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}

// MARK: - Title bar

struct iPodTitleBar: View {
    let title: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Image(systemName: "battery.75")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            LinearGradient(
                colors: [Color(red: 0.35, green: 0.55, blue: 0.95), Color(red: 0.22, green: 0.42, blue: 0.85)],
                startPoint: .top, endPoint: .bottom
            )
        )
    }
}
