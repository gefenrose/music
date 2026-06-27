import SwiftUI
import MediaPlayer

struct NowPlayingView: View {
    @EnvironmentObject var player: AudioPlayerService

    var body: some View {
        NavigationView {
            Group {
                if let track = player.currentTrack {
                    PlayerContentView(track: track)
                } else {
                    ContentUnavailableView(
                        "Nothing Playing",
                        systemImage: "music.note",
                        description: Text("Pick a song from your Library to start listening.")
                    )
                }
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PlayerContentView: View {
    @EnvironmentObject var player: AudioPlayerService
    let track: Track

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Album Art
            ArtworkView(artwork: track.artwork, size: 280)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .scaleEffect(player.isPlaying ? 1.0 : 0.9)
                .animation(.spring(response: 0.4), value: player.isPlaying)

            // Track Info
            VStack(spacing: 6) {
                Text(track.title)
                    .font(.title2).bold()
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(track.artist)
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text(track.album)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            // Progress
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    in: 0...max(player.duration, 1)
                )
                .padding(.horizontal)

                HStack {
                    Text(formatTime(player.currentTime))
                    Spacer()
                    Text("-" + formatTime(max(0, player.duration - player.currentTime)))
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            }

            // Controls
            HStack(spacing: 44) {
                Button(action: { player.previous() }) {
                    Image(systemName: "backward.fill")
                        .font(.title)
                }

                Button(action: { player.togglePlayPause() }) {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }

                Button(action: { player.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.title)
                }
            }
            .foregroundColor(.primary)

            // Volume
            HStack(spacing: 12) {
                Image(systemName: "speaker.fill").foregroundColor(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(player.volume) },
                        set: { player.setVolume(Float($0)) }
                    ),
                    in: 0...1
                )
                Image(systemName: "speaker.wave.3.fill").foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }
}
