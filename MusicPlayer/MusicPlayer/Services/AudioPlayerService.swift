import Foundation
import AVFoundation
import MediaPlayer
import Combine

enum RepeatMode: String, CaseIterable {
    case off, one, all
}

class AudioPlayerService: NSObject, ObservableObject {
    static let shared = AudioPlayerService()

    @Published var currentTrack: Track?
    @Published var queue: [Track] = []
    @Published var queueIndex: Int = 0
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Float = 0.8
    @Published var repeatMode: RepeatMode = .off
    @Published var isShuffled: Bool = false

    private var originalQueue: [Track] = []   // pre-shuffle order
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var scrobbleTimer: Timer?
    private var trackStartTime: Date?
    private var hasScrobbled = false

    private override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
    }

    // MARK: - Setup

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        } catch {
            print("Audio session category error: \(error)")
        }
        Task.detached {
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }

    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget  { [weak self] _ in self?.resume();   return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.pause();    return .success }
        center.nextTrackCommand.addTarget     { [weak self] _ in self?.next();     return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent { self?.seek(to: e.positionTime) }
            return .success
        }
    }

    // MARK: - Playback

    func play(track: Track, queue: [Track] = [], index: Int = 0) {
        guard let url = track.assetURL else { return }
        cancelScrobbleState()

        let newQueue = queue.isEmpty ? [track] : queue
        originalQueue = newQueue

        if isShuffled {
            var shuffled = newQueue
            shuffled.remove(at: index)
            shuffled.shuffle()
            shuffled.insert(track, at: 0)
            self.queue = shuffled
            self.queueIndex = 0
        } else {
            self.queue = newQueue
            self.queueIndex = index
        }

        loadAndPlay(track: track)
    }

    private func loadAndPlay(track: Track) {
        guard let url = track.assetURL else { return }

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
        NotificationCenter.default.addObserver(self, selector: #selector(trackDidEnd),
                                               name: .AVPlayerItemDidPlayToEndTime, object: item)

        currentTrack = track
        hasScrobbled = false
        trackStartTime = Date()

        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
        startScrobbleTimer()

        Task { await LastFMService.shared.updateNowPlaying(track: track) }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        scrobbleTimer?.invalidate()
        scrobbleTimer = nil
        updateNowPlayingInfo()
    }

    func resume() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
        startScrobbleTimer()
    }

    func togglePlayPause() { isPlaying ? pause() : resume() }

    func seek(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }

    func next() {
        guard !queue.isEmpty else { return }
        switch repeatMode {
        case .one:
            seek(to: 0); resume()
        case .all:
            let i = (queueIndex + 1) % queue.count
            queueIndex = i
            loadAndPlay(track: queue[i])
        case .off:
            let i = queueIndex + 1
            guard i < queue.count else { pause(); return }
            queueIndex = i
            loadAndPlay(track: queue[i])
        }
    }

    func previous() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 { seek(to: 0); return }
        let i = max(0, queueIndex - 1)
        queueIndex = i
        loadAndPlay(track: queue[i])
    }

    func setVolume(_ v: Float) { volume = v; player?.volume = v }

    // MARK: - Shuffle / Repeat

    func toggleShuffle() {
        isShuffled.toggle()
        guard let current = currentTrack else { return }
        if isShuffled {
            var others = originalQueue
            if let idx = others.firstIndex(of: current) { others.remove(at: idx) }
            others.shuffle()
            queue = [current] + others
            queueIndex = 0
        } else {
            queue = originalQueue
            queueIndex = originalQueue.firstIndex(of: current) ?? 0
        }
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    // MARK: - Track end

    @objc private func trackDidEnd() {
        scrobbleCurrentTrack()
        next()
    }

    // MARK: - Scrobble

    private func startScrobbleTimer() {
        scrobbleTimer?.invalidate()
        guard let track = currentTrack, !hasScrobbled else { return }
        let threshold = min(track.duration / 2, 240)
        let remaining = max(threshold - currentTime, 1)
        scrobbleTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            self?.scrobbleCurrentTrack()
        }
    }

    private func scrobbleCurrentTrack() {
        guard !hasScrobbled, let track = currentTrack, let startTime = trackStartTime else { return }
        guard track.duration > 30 else { return }
        hasScrobbled = true
        let timestamp = Int(startTime.timeIntervalSince1970)
        Task { await LastFMService.shared.scrobble(track: track, timestamp: timestamp) }
    }

    private func cancelScrobbleState() {
        scrobbleTimer?.invalidate()
        scrobbleTimer = nil
        trackStartTime = nil
        hasScrobbled = false
    }

    private func removeTimeObserver() {
        if let obs = timeObserver { player?.removeTimeObserver(obs); timeObserver = nil }
    }

    // MARK: - Lock screen

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle:              track.title,
            MPMediaItemPropertyArtist:             track.artist,
            MPMediaItemPropertyAlbumTitle:         track.album,
            MPMediaItemPropertyPlaybackDuration:   track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate:  isPlaying ? 1.0 : 0.0
        ]
        if let artwork = track.artwork {
            info[MPMediaItemPropertyArtwork] = artwork
        } else if let img = track.localArtwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
