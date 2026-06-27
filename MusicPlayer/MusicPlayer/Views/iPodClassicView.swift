import SwiftUI
import MediaPlayer

// MARK: - iPod Classic colour palette

private enum iPodColor {
    // Screen background – warm white
    static let screenBG      = Color(red: 0.969, green: 0.969, blue: 0.969)
    // Title-bar chrome (top lighter, bottom darker)
    static let titleTop      = Color(red: 0.820, green: 0.820, blue: 0.830)
    static let titleBot      = Color(red: 0.655, green: 0.655, blue: 0.665)
    // Row separator
    static let separator     = Color(red: 0.780, green: 0.780, blue: 0.790)
    // Normal row text
    static let rowText       = Color.black
    static let rowDetail     = Color(red: 0.40, green: 0.40, blue: 0.42)
    static let rowChevron    = Color(red: 0.62, green: 0.62, blue: 0.64)
    // Selection gradient (3-stop classic Apple blue)
    static let selTop        = Color(red: 0.489, green: 0.686, blue: 0.980)
    static let selMid        = Color(red: 0.169, green: 0.431, blue: 0.898)
    static let selBot        = Color(red: 0.047, green: 0.220, blue: 0.690)
    // Now-playing scrubber
    static let scrubFill     = Color(red: 0.169, green: 0.431, blue: 0.898)
    static let scrubTrack    = Color(red: 0.60, green: 0.60, blue: 0.62)
}

// MARK: - Navigation model

enum iPodPage: Hashable {
    case mainMenu, musicMenu, songs, albums, artists, nowPlaying, settings
    case albumDetail(String)
    case artistDetail(String)
}

// MARK: - Main view

struct iPodClassicView: View {
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var player:  AudioPlayerService
    @EnvironmentObject var lastFM:  LastFMService

    @State private var pageStack: [iPodPage] = [.mainMenu]
    @State private var selectedIndices: [iPodPage: Int] = [:]
    @State private var scrollAccum: CGFloat = 0
    @State private var showLastFMSettings = false

    var currentPage: iPodPage { pageStack.last ?? .mainMenu }
    var selectedIndex: Int    { selectedIndices[currentPage] ?? 0 }
    func setSelected(_ i: Int) { selectedIndices[currentPage] = i }

    // MARK: Menu data

    struct MenuItem {
        let title: String
        let detail: String?
        let hasChevron: Bool
    }

    var menuItems: [MenuItem] {
        switch currentPage {
        case .mainMenu:
            return [
                .init(title: "Music",       detail: nil,                              hasChevron: true),
                .init(title: "Now Playing", detail: nil,                              hasChevron: false),
                .init(title: "Last.fm",     detail: lastFM.isAuthenticated ? lastFM.username : "Not connected", hasChevron: true)
            ]
        case .musicMenu:
            return [
                .init(title: "Songs",   detail: "\(library.songs.count)",   hasChevron: true),
                .init(title: "Albums",  detail: "\(library.albums.count)",  hasChevron: true),
                .init(title: "Artists", detail: "\(library.artists.count)", hasChevron: true)
            ]
        case .songs:
            return library.songs.map   { .init(title: $0.title,  detail: $0.artist, hasChevron: false) }
        case .albums:
            return library.albums.map  { .init(title: $0.title,  detail: $0.artist, hasChevron: true)  }
        case .albumDetail(let id):
            let tracks = library.albums.first { $0.id == id }?.tracks ?? []
            return tracks.map { .init(title: $0.title, detail: formatDuration($0.duration), hasChevron: false) }
        case .artists:
            return library.artists.map { .init(title: $0.name,   detail: "\($0.tracks.count) songs",   hasChevron: true) }
        case .artistDetail(let id):
            let tracks = library.artists.first { $0.id == id }?.tracks ?? []
            return tracks.map { .init(title: $0.title, detail: $0.album, hasChevron: false) }
        case .nowPlaying, .settings:
            return []
        }
    }

    var pageTitle: String {
        switch currentPage {
        case .mainMenu:              return "iPod"
        case .musicMenu:             return "Music"
        case .songs:                 return "Songs"
        case .albums:                return "Albums"
        case .albumDetail(let id):   return library.albums.first  { $0.id == id }?.title ?? "Album"
        case .artists:               return "Artists"
        case .artistDetail(let id):  return library.artists.first { $0.id == id }?.name  ?? "Artist"
        case .nowPlaying:            return "Now Playing"
        case .settings:              return "Settings"
        }
    }

    // MARK: - Layout

    var body: some View {
        GeometryReader { geo in
            ZStack {
                iPodBodyBackground()

                VStack(spacing: 0) {
                    // ── Screen ──────────────────────────────────────────
                    Group {
                        if currentPage == .nowPlaying {
                            NowPlayingScreen()
                        } else {
                            MenuScreen(
                                title: pageTitle,
                                items: menuItems,
                                selectedIndex: selectedIndex,
                                isLoading: library.isLoading
                            )
                        }
                    }
                    .frame(height: screenHeight(geo))
                    .background(iPodColor.screenBG)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color(white: 0.38), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 5, x: 0, y: 3)
                    .padding(.horizontal, horizontalPad(geo))
                    .padding(.top, topPad(geo))

                    Spacer()

                    // ── Click wheel ──────────────────────────────────────
                    let wd = wheelDiam(geo)
                    ClickWheelView(
                        onMenu:      navigateBack,
                        onPrevious:  handlePrevious,
                        onNext:      handleNext,
                        onPlayPause: { player.togglePlayPause(); impact(.medium) },
                        onCenter:    handleCenter,
                        onScroll:    handleScroll
                    )
                    .frame(width: wd, height: wd)
                    .padding(.bottom, bottomPad(geo))
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showLastFMSettings) {
            SettingsView().environmentObject(lastFM)
        }
        .onChange(of: currentPage) { _, _ in
            if selectedIndices[currentPage] == nil { selectedIndices[currentPage] = 0 }
        }
    }

    // MARK: - Sizing helpers

    func screenHeight(_ g: GeometryProxy) -> CGFloat  { g.size.height * 0.40 }
    func horizontalPad(_ g: GeometryProxy) -> CGFloat { 20 }
    func topPad(_ g: GeometryProxy) -> CGFloat        { g.safeAreaInsets.top + 14 }
    func wheelDiam(_ g: GeometryProxy) -> CGFloat     { min(g.size.width * 0.80, 310) }
    func bottomPad(_ g: GeometryProxy) -> CGFloat     { g.safeAreaInsets.bottom + 18 }

    // MARK: - Navigation

    func navigateBack() {
        impact(.medium)
        guard pageStack.count > 1 else { return }
        pageStack.removeLast()
    }

    func handleCenter() {
        impact(.medium)
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
        let count = menuItems.count
        guard count > 0, currentPage != .nowPlaying else { return }
        scrollAccum += delta
        let threshold: CGFloat = 0.18
        while abs(scrollAccum) >= threshold {
            let step = scrollAccum > 0 ? 1 : -1
            scrollAccum -= CGFloat(step) * threshold
            let next = max(0, min(count - 1, selectedIndex + step))
            if next != selectedIndex {
                setSelected(next)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    func handlePrevious() {
        impact(.medium)
        if currentPage == .nowPlaying { player.previous() }
        else { setSelected(max(0, selectedIndex - 1)) }
    }

    func handleNext() {
        impact(.medium)
        if currentPage == .nowPlaying { player.next() }
        else { setSelected(min(menuItems.count - 1, selectedIndex + 1)) }
    }

    func impact(_ s: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: s).impactOccurred()
    }

    func formatDuration(_ s: TimeInterval) -> String {
        guard s.isFinite else { return "0:00" }
        return String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}

// MARK: - iPod body background

private struct iPodBodyBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(white: 0.975), Color(white: 0.900)],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Classic title bar

private struct ClassicTitleBar: View {
    let title: String

    var body: some View {
        ZStack {
            // Chrome gradient
            LinearGradient(
                colors: [iPodColor.titleTop, iPodColor.titleBot],
                startPoint: .top, endPoint: .bottom
            )

            HStack(spacing: 0) {
                // Left spacer balances the battery icon so title is truly centred
                Spacer().frame(width: 28)

                Spacer()

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(1)
                    .shadow(color: .white.opacity(0.6), radius: 0, x: 0, y: 1)

                Spacer()

                // Battery
                BatteryIcon()
                    .frame(width: 28)
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 22)
        // 1 pt separator line at bottom
        .overlay(Rectangle().fill(iPodColor.separator).frame(height: 0.5), alignment: .bottom)
    }
}

// Pixel-faithful battery indicator
private struct BatteryIcon: View {
    var body: some View {
        HStack(spacing: 1) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5)
                    .stroke(Color(white: 0.28), lineWidth: 0.8)
                    .frame(width: 18, height: 9)
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(white: 0.28))
                    .frame(width: 13, height: 6)
                    .offset(x: 2)
            }
            // Nub
            Rectangle()
                .fill(Color(white: 0.28))
                .frame(width: 2, height: 4)
                .cornerRadius(0.5)
        }
    }
}

// MARK: - Menu screen

private struct MenuScreen: View {
    @EnvironmentObject var library: MusicLibraryManager

    let title: String
    let items: [iPodClassicView.MenuItem]
    let selectedIndex: Int
    let isLoading: Bool

    var body: some View {
        VStack(spacing: 0) {
            ClassicTitleBar(title: title)

            if isLoading {
                Spacer()
                ProgressView().scaleEffect(0.65).tint(iPodColor.selMid)
                Spacer()
            } else if items.isEmpty {
                Spacer()
                Text("No items")
                    .font(.system(size: 11))
                    .foregroundColor(iPodColor.rowDetail)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                                ClassicMenuRow(
                                    title: item.title,
                                    detail: item.detail,
                                    hasChevron: item.hasChevron,
                                    isSelected: idx == selectedIndex
                                )
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
        .background(iPodColor.screenBG)
    }
}

// MARK: - Classic menu row

private struct ClassicMenuRow: View {
    let title: String
    let detail: String?
    let hasChevron: Bool
    let isSelected: Bool

    private let rowH: CGFloat = 22

    var body: some View {
        ZStack(alignment: .bottom) {
            // Row background
            if isSelected {
                LinearGradient(
                    stops: [
                        .init(color: iPodColor.selTop, location: 0.00),
                        .init(color: iPodColor.selMid, location: 0.50),
                        .init(color: iPodColor.selBot, location: 1.00)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            } else {
                Color.white
            }

            // Content
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(isSelected ? .white : iPodColor.rowText)
                    .lineLimit(1)

                Spacer()

                if let d = detail {
                    Text(d)
                        .font(.system(size: 10.5))
                        .foregroundColor(isSelected ? .white.opacity(0.85) : iPodColor.rowDetail)
                        .lineLimit(1)
                }

                if hasChevron {
                    Text("›")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? .white.opacity(0.85) : iPodColor.rowChevron)
                        .offset(y: -0.5)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: rowH)

            // Separator — only shown on unselected rows
            if !isSelected {
                iPodColor.separator
                    .frame(height: 0.5)
            }
        }
        .frame(height: rowH)
    }
}

// MARK: - Now Playing screen

private struct NowPlayingScreen: View {
    @EnvironmentObject var player: AudioPlayerService

    var body: some View {
        VStack(spacing: 0) {
            ClassicTitleBar(title: "Now Playing")

            if let track = player.currentTrack {
                trackDisplay(track)
            } else {
                Spacer()
                Text("Nothing Playing")
                    .font(.system(size: 11))
                    .foregroundColor(iPodColor.rowDetail)
                Spacer()
            }
        }
        .background(iPodColor.screenBG)
    }

    @ViewBuilder
    private func trackDisplay(_ track: Track) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Album art – square, flush left, full height of content area
            GeometryReader { g in
                Group {
                    if let img = track.artworkImage(size: CGSize(width: 200, height: 200)) {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Color(red: 0.78, green: 0.78, blue: 0.80)
                            Image(systemName: "music.note")
                                .font(.system(size: g.size.width * 0.35))
                                .foregroundColor(Color(white: 0.5))
                        }
                    }
                }
                .frame(width: g.size.width, height: g.size.height)
                .clipped()
            }
            .aspectRatio(1, contentMode: .fit)

            // Track info column
            VStack(alignment: .leading, spacing: 0) {
                // Song title
                Text(track.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 7)

                // Thin rule
                iPodColor.separator.frame(height: 0.5).padding(.vertical, 4)

                // Artist
                Text(track.artist)
                    .font(.system(size: 10))
                    .foregroundColor(Color(white: 0.25))
                    .lineLimit(1)

                // Album
                Text(track.album)
                    .font(.system(size: 10))
                    .foregroundColor(iPodColor.rowDetail)
                    .lineLimit(1)
                    .padding(.top, 2)

                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)

        // ── Scrubber area (bottom) ──────────────────────────────────
        VStack(spacing: 2) {
            // Track / progress bar with diamond thumb
            GeometryReader { g in
                let pct = player.duration > 0 ? CGFloat(player.currentTime / player.duration) : 0
                let filled = g.size.width * pct

                ZStack(alignment: .leading) {
                    // Track groove
                    Capsule()
                        .fill(iPodColor.scrubTrack)
                        .frame(height: 3)

                    // Filled portion
                    Capsule()
                        .fill(iPodColor.scrubFill)
                        .frame(width: max(0, filled), height: 3)

                    // Diamond thumb
                    DiamondShape()
                        .fill(Color.white)
                        .overlay(DiamondShape().stroke(iPodColor.scrubFill, lineWidth: 1))
                        .frame(width: 8, height: 8)
                        .offset(x: max(0, filled - 4))
                }
                .frame(height: g.size.height)
            }
            .frame(height: 10)
            .padding(.horizontal, 8)

            // Time labels
            HStack {
                Text(formatTime(player.currentTime))
                Spacer()
                // Play/pause state icon
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 7))
                    .foregroundColor(iPodColor.rowDetail)
                Spacer()
                Text("-" + formatTime(max(0, player.duration - player.currentTime)))
            }
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(iPodColor.rowDetail)
            .padding(.horizontal, 10)
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
        .background(iPodColor.screenBG)
        .overlay(iPodColor.separator.frame(height: 0.5), alignment: .top)
    }

    private func formatTime(_ s: Double) -> String {
        guard s.isFinite else { return "0:00" }
        return String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
}

// Diamond scrubber thumb
private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        p.closeSubpath()
        return p
    }
}
