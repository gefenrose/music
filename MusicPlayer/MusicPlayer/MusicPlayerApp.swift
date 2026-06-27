import SwiftUI

@main
struct MusicPlayerApp: App {
    @StateObject private var player = AudioPlayerService.shared
    @StateObject private var library = MusicLibraryManager.shared
    @StateObject private var lastFM = LastFMService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .environmentObject(library)
                .environmentObject(lastFM)
        }
    }
}
