import SwiftUI
import MediaPlayer

// MARK: - Navigation pages

enum iPodPage: Hashable {
    case mainMenu, musicMenu, artists, albums, songs, nowPlaying
    case albumDetail(String)
    case artistDetail(String)
}

// MARK: - Root view

struct iPodClassicView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player:  AudioPlayerService
    @EnvironmentObject var lastFM:  LastFMService

    @State private var pageStack: [iPodPage] = [.mainMenu]
    @State private var selectedIndices: [iPodPage: Int] = [:]
    @State private var scrollAccum: CGFloat = 0
    @State private var showSettings = false

    var currentPage: iPodPage { pageStack.last ?? .mainMenu }
    var selectedIndex: Int    { selectedIndices[currentPage] ?? 0 }
    func setSelected(_ i: Int) { selectedIndices[currentPage] = i }

    // MARK: Menu data

    struct MenuItem { let title: String; let icon: String?; let chevron: Bool }

    var menuItems: [MenuItem] {
        switch currentPage {
        case .mainMenu:
            return [
                MenuItem(title: "Now Playing", icon: "play.circle.fill",  chevron: false),
                MenuItem(title: "Music",       icon: "music.note.list",   chevron: true),
                MenuItem(title: "Settings",    icon: "gear",              chevron: true),
            ]
        case .musicMenu:
            return [
                MenuItem(title: "Artists", icon: nil, chevron: true),
                MenuItem(title: "Albums",  icon: nil, chevron: true),
                MenuItem(title: "Songs",   icon: nil, chevron: true),
            ]
        case .artists:
            return library.artists.map { MenuItem(title: $0.name,  icon: nil, chevron: true)  }
        case .albums:
            return library.albums.map  { MenuItem(title: $0.title, icon: nil, chevron: true)  }
        case .songs:
            return library.songs.map   { MenuItem(title: $0.title, icon: nil, chevron: false) }
        case .albumDetail(let id):
            return (library.albums.first  { $0.id == id }?.tracks ?? [])
                .map { MenuItem(title: $0.title, icon: nil, chevron: false) }
        case .artistDetail(let id):
            return (library.artists.first { $0.id == id }?.tracks ?? [])
                .map { MenuItem(title: $0.title, icon: nil, chevron: false) }
        case .nowPlaying:
            return []
        }
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // ── iPhone screen area ───────────────────────────────
                screenContent(geo: geo)
                    .frame(width: geo.size.width, height: screenHeight(geo))
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0, bottomLeadingRadius: 20,
                            bottomTrailingRadius: 20, topTrailingRadius: 0
                        )
                    )

                // ── Physical bezel / gap ─────────────────────────────
                Color.black.frame(height: 16)

                // ── Click wheel area ─────────────────────────────────
                wheelArea(geo: geo)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 20, bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0, topTrailingRadius: 20
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // ── Home indicator safe area ─────────────────────────
                Color.black.frame(height: geo.safeAreaInsets.bottom > 0
                    ? geo.safeAreaInsets.bottom : 20)
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(lastFM)
        }
        .onChange(of: currentPage) { _, _ in
            if selectedIndices[currentPage] == nil { selectedIndices[currentPage] = 0 }
        }
    }

    func screenHeight(_ g: GeometryProxy) -> CGFloat { g.size.height * 0.525 }

    func statusBarHeight() -> CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.statusBarManager?.statusBarFrame.height ?? 44
    }

    // MARK: - Screen content

    @ViewBuilder
    func screenContent(geo: GeometryProxy) -> some View {
        if currentPage == .nowPlaying {
            NowPlayingScreen().environmentObject(player)
        } else {
            menuListScreen(geo: geo)
        }
    }

    func menuListScreen(geo: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    // Push list below status bar
                    Color.clear.frame(height: max(geo.safeAreaInsets.top, statusBarHeight()))

                    if library.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                            .tint(Color(red: 0.25, green: 0.55, blue: 0.88))
                    } else {
                        ForEach(Array(menuItems.enumerated()), id: \.offset) { idx, item in
                            menuRow(item: item, index: idx).id(idx)
                        }
                    }
                }
            }
            .background(Color(white: 0.964))
            .onChange(of: selectedIndex) { _, val in
                withAnimation(.none) { proxy.scrollTo(val, anchor: .center) }
            }
        }
    }

    // MARK: - Menu row

    func menuRow(item: MenuItem, index: Int) -> some View {
        let sel = index == selectedIndex
        return ZStack(alignment: .bottom) {
            // Row background
            if sel {
                selectionGradient
            } else {
                Color(white: 0.964)
            }

            // Content
            HStack(spacing: 14) {
                if let icon = item.icon {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(sel ? .white : .black)
                        .frame(width: 28)
                }
                Text(item.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(sel ? .white : .black)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                if item.chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(sel ? .white.opacity(0.75) : Color(white: 0.62))
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 52)

            // Hairline separator on unselected rows
            if !sel {
                Color(white: 0.80).frame(height: 0.5)
            }
        }
        .frame(height: 52)
    }

    var selectionGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.330, green: 0.648, blue: 0.930),
                Color(red: 0.165, green: 0.455, blue: 0.820),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Click wheel area

    func wheelArea(geo: GeometryProxy) -> some View {
        ZStack {
            // Silver aluminium background with radial vignette
            ZStack {
                Color(white: 0.80)
                RadialGradient(
                    colors: [Color(white: 0.965), Color(white: 0.72)],
                    center: .center,
                    startRadius: 0,
                    endRadius: min(geo.size.width, geo.size.height - screenHeight(geo)) * 0.62
                )
            }

            let wd = min(geo.size.width * 0.78, 308.0)
            ClickWheelView(
                onMenu:      navigateBack,
                onPrevious:  handlePrevious,
                onNext:      handleNext,
                onPlayPause: { player.togglePlayPause(); impact(.medium) },
                onCenter:    handleCenter,
                onScroll:    handleScroll
            )
            .frame(width: wd, height: wd)
        }
    }

    // MARK: - Navigation

    func navigateBack() {
        impact(.medium)
        guard pageStack.count > 1 else { return }
        pageStack.removeLast()
    }

    func handleCenter() {
        impact(.medium)
        let i = selectedIndex
        switch currentPage {
        case .mainMenu:
            switch i {
            case 0: pageStack.append(.nowPlaying)
            case 1: pageStack.append(.musicMenu)
            default: showSettings = true
            }
        case .musicMenu:
            switch i {
            case 0: pageStack.append(.artists)
            case 1: pageStack.append(.albums)
            default: pageStack.append(.songs)
            }
        case .artists:
            guard i < library.artists.count else { return }
            pageStack.append(.artistDetail(library.artists[i].id))
        case .albums:
            guard i < library.albums.count else { return }
            pageStack.append(.albumDetail(library.albums[i].id))
        case .songs:
            guard i < library.songs.count else { return }
            player.play(track: library.songs[i], queue: library.songs, index: i)
            pageStack.append(.nowPlaying)
        case .albumDetail(let id):
            let tracks = library.albums.first { $0.id == id }?.tracks ?? []
            guard i < tracks.count else { return }
            player.play(track: tracks[i], queue: tracks, index: i)
            pageStack.append(.nowPlaying)
        case .artistDetail(let id):
            let tracks = library.artists.first { $0.id == id }?.tracks ?? []
            guard i < tracks.count else { return }
            player.play(track: tracks[i], queue: tracks, index: i)
            pageStack.append(.nowPlaying)
        case .nowPlaying:
            player.togglePlayPause()
        }
    }

    func handleScroll(_ delta: CGFloat) {
        if currentPage == .nowPlaying {
            // Classic iPod: clockwise = volume up, counter-clockwise = volume down
            // One full rotation (2π) covers the full 0-1 volume range
            let newVol = max(0, min(1, player.volume + Float(delta / (.pi * 2))))
            player.setVolume(newVol)
            return
        }
        guard !menuItems.isEmpty else { return }
        scrollAccum += delta
        let threshold: CGFloat = 0.18
        while abs(scrollAccum) >= threshold {
            let step = scrollAccum > 0 ? 1 : -1
            scrollAccum -= CGFloat(step) * threshold
            let next = max(0, min(menuItems.count - 1, selectedIndex + step))
            if next != selectedIndex {
                setSelected(next)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    func handlePrevious() {
        impact(.medium)
        if currentPage == .nowPlaying {
            if player.currentTime > 3 { player.seek(to: 0) }
            else { player.previous() }
        } else {
            setSelected(max(0, selectedIndex - 1))
        }
    }

    func handleNext() {
        impact(.medium)
        if currentPage == .nowPlaying { player.next() }
        else { setSelected(min(menuItems.count - 1, selectedIndex + 1)) }
    }

    func impact(_ s: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: s).impactOccurred()
    }
}

// MARK: - Now Playing (full-bleed)

struct NowPlayingScreen: View {
    @EnvironmentObject var player: AudioPlayerService

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                Color.black

                if let track = player.currentTrack {
                    // Full-bleed album art
                    if let img = track.artworkImage(
                        size: CGSize(width: geo.size.width * 3, height: geo.size.height * 3)
                    ) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }

                    // Bottom gradient so text is readable
                    LinearGradient(
                        stops: [
                            .init(color: .clear,            location: 0.35),
                            .init(color: .black.opacity(0.72), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Track info + progress
                    VStack(alignment: .leading, spacing: 4) {
                        Text(track.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)

                        Text(track.artist)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.88))
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)

                        Spacer().frame(height: 8)

                        // Progress bar
                        GeometryReader { g in
                            let pct = player.duration > 0
                                ? CGFloat(player.currentTime / player.duration) : 0
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.28))
                                    .frame(height: 4)
                                Capsule()
                                    .fill(Color.white)
                                    .frame(width: max(0, g.size.width * pct), height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)

                } else {
                    // Nothing playing
                    VStack {
                        Spacer()
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.35))
                        Text("Nothing Playing")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.45))
                            .padding(.top, 8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
