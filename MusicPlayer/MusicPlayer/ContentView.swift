import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player:  AudioPlayerService
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var lastFM:  LastFMService

    @State private var showNowPlaying = false

    var body: some View {
        TabView {
            LibraryView()
                .tabItem { Label("Library", systemImage: "music.note.list") }
        }
        .safeAreaInset(edge: .bottom) {
            if player.currentTrack != nil {
                MiniPlayerView(showNowPlaying: $showNowPlaying)
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingSheet()
                .environmentObject(player)
        }
        .onAppear { library.requestAuthorization() }
    }
}
