import SwiftUI

// Full-screen sheet
struct NowPlayingSheet: View {
    @EnvironmentObject var player: AudioPlayerService
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let track = player.currentTrack {
                    NowPlayingContent(track: track)
                } else {
                    ContentUnavailableView(
                        "Nothing Playing",
                        systemImage: "music.note",
                        description: Text("Pick a song from your Library.")
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Now Playing").font(.caption).foregroundColor(.secondary)
                        Text(player.currentTrack?.album ?? "").font(.caption2).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Main content

struct NowPlayingContent: View {
    @EnvironmentObject var player: AudioPlayerService
    let track: Track

    @State private var artworkImage: UIImage?
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            // Artwork
            Group {
                if let img = artworkImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .overlay(Image(systemName: "music.note")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary))
                        .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 12)
                }
            }
            .scaleEffect(player.isPlaying ? 1.0 : 0.88)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: player.isPlaying)
            .padding(.horizontal, 32)
            .task(id: track.id) {
                artworkImage = track.artworkImage(size: CGSize(width: 600, height: 600))
            }

            Spacer(minLength: 24)

            // Track info + like button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.title3).bold()
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 20)

            // Progress bar
            VStack(spacing: 6) {
                ProgressSlider(
                    value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ),
                    range: 0...max(player.duration, 1),
                    isDragging: $isDragging
                )
                .padding(.horizontal, 32)

                HStack {
                    Text(formatTime(player.currentTime))
                    Spacer()
                    Text("-" + formatTime(max(0, player.duration - player.currentTime)))
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(.secondary)
                .padding(.horizontal, 36)
            }

            Spacer(minLength: 24)

            // Transport controls
            HStack(spacing: 0) {
                Spacer()
                Button { player.previous() } label: {
                    Image(systemName: "backward.fill").font(.system(size: 30))
                }
                Spacer()
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 70))
                }
                Spacer()
                Button { player.next() } label: {
                    Image(systemName: "forward.fill").font(.system(size: 30))
                }
                Spacer()
            }
            .foregroundColor(.primary)

            Spacer(minLength: 28)

            // Volume
            HStack(spacing: 10) {
                Image(systemName: "speaker.fill").foregroundColor(.secondary).font(.caption)
                Slider(
                    value: Binding(
                        get: { Double(player.volume) },
                        set: { player.setVolume(Float($0)) }
                    ),
                    in: 0...1
                )
                Image(systemName: "speaker.wave.3.fill").foregroundColor(.secondary).font(.caption)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 32)
        }
    }

    private func formatTime(_ t: Double) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        return String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Smooth progress slider

struct ProgressSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @Binding var isDragging: Bool

    var body: some View {
        GeometryReader { geo in
            let pct = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let filled = max(0, min(geo.size.width, geo.size.width * pct))

            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray4)).frame(height: isDragging ? 6 : 4)
                Capsule().fill(Color.primary).frame(width: filled, height: isDragging ? 6 : 4)
                Circle()
                    .fill(Color.primary)
                    .frame(width: isDragging ? 18 : 0, height: isDragging ? 18 : 0)
                    .offset(x: max(0, filled - (isDragging ? 9 : 0)))
            }
            .animation(.easeInOut(duration: 0.12), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        isDragging = true
                        let ratio = Double(g.location.x / geo.size.width)
                        value = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
                        value = max(range.lowerBound, min(range.upperBound, value))
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
        .frame(height: 20)
    }
}
