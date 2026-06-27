import SwiftUI

struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    @EnvironmentObject var library: MusicLibraryManager
    @EnvironmentObject var lastFM: LastFMService

    var body: some View {
        iPodClassicView()
            .ignoresSafeArea()
            .onAppear { library.requestAuthorization() }
    }
}
