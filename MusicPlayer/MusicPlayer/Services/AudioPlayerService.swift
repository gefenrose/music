import Foundation
import AVFoundation
import MediaPlayer
import Combine

class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()

    @Published var currentTrack: Track?
    @Published var queue: [Track] = []
    @Published var queueIndex: Int = 0
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 0.8

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var scrobbleTimer: Timer?
    private var trackStartTime: Date?
    private var hasScrobbled = false
    private var nowPlayingPosted = false

    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.resume(); return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause(); return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next(); return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous(); return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: e.positionTime)
            }
            return .success
        }
    }

    func play(track: Track, queue: [Track] = [], index: Int = 0) {
        guard let url = track.assetURL else { return }
        cancelScrobbleState()

        self.queue = queue.isEmpty ? [track] : queue
        self.queueIndex = index

        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
            player?.volume = volume
        } else {
            player?.replaceCurrentItem(with: item)
        }

        removeTimeObserver()
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            let t = time.seconds
            self?.currentTime = t.isFinite ? t : 0
            let d = self?.player?.currentItem?.duration.seconds ?? 0
            self?.duration = (d.isFinite && d > 0) ? d : 0
        }

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(trackDidEnd), name: .AVPlayerItemDidPlayToEndTime, object: item)

        currentTrack = track
        hasScrobbled = false
        nowPlayingPosted = false
        trackStartTime = Date()

        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
        startScrobbleTimer()

        Task {
            await LastFMService.shared.updateNowPlaying(track: track)
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func seek(to time: Double) {
        let target = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: target)
    }

    func next() {
        guard !queue.isEmpty else { return }
        let nextIndex = (queueIndex + 1) % queue.count
        play(track: queue[nextIndex], queue: queue, index: nextIndex)
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        let prevIndex = queueIndex == 0 ? queue.count - 1 : queueIndex - 1
        play(track: queue[prevIndex], queue: queue, index: prevIndex)
    }

    func setVolume(_ v: Float) {
        volume = v
        player?.volume = v
    }

    @objc private func trackDidEnd() {
        scrobbleCurrentTrack()
        next()
    }

    private func startScrobbleTimer() {
        scrobbleTimer?.invalidate()
        guard let track = currentTrack else { return }
        let scrobbleAfter = min(track.duration / 2, 240)
        scrobbleTimer = Timer.scheduledTimer(withTimeInterval: scrobbleAfter, repeats: false) { [weak self] _ in
            self?.scrobbleCurrentTrack()
        }
    }

    private func scrobbleCurrentTrack() {
        guard !hasScrobbled, let track = currentTrack, let startTime = trackStartTime else { return }
        guard track.duration > 30 else { return }
        hasScrobbled = true
        let timestamp = Int(startTime.timeIntervalSince1970)
        Task {
            await LastFMService.shared.scrobble(track: track, timestamp: timestamp)
        }
    }

    private func cancelScrobbleState() {
        scrobbleTimer?.invalidate()
        scrobbleTimer = nil
        trackStartTime = nil
        hasScrobbled = false
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let artwork = track.artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
