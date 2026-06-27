import SwiftUI

struct MiniPlayerView: View {
    @EnvironmentObject var player: AudioPlayerService
    @Binding var showNowPlaying: Bool

    var body: some View {
        guard let track = player.currentTrack else { return AnyView(EmptyView()) }
        return AnyView(content(track: track))
    }

    private func content(track: Track) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                ArtworkThumbnail(track: track, size: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline).bold()
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { player.previous() }) {
                    Image(systemName: "backward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                Button(action: { player.togglePlayPause() }) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)

                Button(action: { player.next() }) {
                    Image(systemName: "forward.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .contentShape(Rectangle())
            .onTapGesture { showNowPlaying = true }
        }
    }
}
