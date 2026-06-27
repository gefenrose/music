import Foundation
import CryptoKit

class LastFMService: ObservableObject {
    static let shared = LastFMService()

    @Published var isAuthenticated = false
    @Published var username: String = ""
    @Published var sessionKey: String = ""
    @Published var apiKey: String = ""
    @Published var apiSecret: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "https://ws.audioscrobbler.com/2.0/"
    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    func load() {
        username = defaults.string(forKey: "lastfm_username") ?? ""
        sessionKey = defaults.string(forKey: "lastfm_session_key") ?? ""
        apiKey = defaults.string(forKey: "lastfm_api_key") ?? ""
        apiSecret = defaults.string(forKey: "lastfm_api_secret") ?? ""
        isAuthenticated = !sessionKey.isEmpty
    }

    func save() {
        defaults.set(username, forKey: "lastfm_username")
        defaults.set(sessionKey, forKey: "lastfm_session_key")
        defaults.set(apiKey, forKey: "lastfm_api_key")
        defaults.set(apiSecret, forKey: "lastfm_api_secret")
    }

    func logout() {
        sessionKey = ""
        isAuthenticated = false
        defaults.removeObject(forKey: "lastfm_session_key")
    }

    func authenticate(username: String, password: String) async {
        guard !apiKey.isEmpty, !apiSecret.isEmpty else {
            await setError("Please enter your API Key and Secret first.")
            return
        }
        await setLoading(true)
        var params: [String: String] = [
            "method": "auth.getMobileSession",
            "username": username,
            "password": password,
            "api_key": apiKey
        ]
        params["api_sig"] = signature(for: params, secret: apiSecret)
        params["format"] = "json"

        do {
            let data = try await post(params: params)
            let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
            await MainActor.run {
                self.username = decoded.session.name
                self.sessionKey = decoded.session.key
                self.isAuthenticated = true
                self.isLoading = false
                self.errorMessage = nil
                self.save()
            }
        } catch {
            await setError("Authentication failed: \(error.localizedDescription)")
        }
    }

    func updateNowPlaying(track: Track) async {
        guard isAuthenticated else { return }
        var params: [String: String] = [
            "method": "track.updateNowPlaying",
            "track": track.title,
            "artist": track.artist,
            "album": track.album,
            "duration": String(Int(track.duration)),
            "api_key": apiKey,
            "sk": sessionKey
        ]
        params["api_sig"] = signature(for: params, secret: apiSecret)
        params["format"] = "json"
        _ = try? await post(params: params)
    }

    func scrobble(track: Track, timestamp: Int) async {
        guard isAuthenticated else { return }
        var params: [String: String] = [
            "method": "track.scrobble",
            "track": track.title,
            "artist": track.artist,
            "album": track.album,
            "timestamp": String(timestamp),
            "duration": String(Int(track.duration)),
            "api_key": apiKey,
            "sk": sessionKey
        ]
        params["api_sig"] = signature(for: params, secret: apiSecret)
        params["format"] = "json"
        _ = try? await post(params: params)
    }

    private func signature(for params: [String: String], secret: String) -> String {
        let sorted = params.filter { $0.key != "format" }
            .sorted { $0.key < $1.key }
            .map { $0.key + $0.value }
            .joined()
        let toHash = sorted + secret
        return md5(toHash)
    }

    private func md5(_ string: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func post(params: [String: String]) async throws -> Data {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var formAllowed = CharacterSet.urlQueryAllowed
        formAllowed.remove(charactersIn: "+&=")
        request.httpBody = params
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        return data
    }

    @MainActor
    private func setError(_ msg: String) {
        errorMessage = msg
        isLoading = false
    }

    @MainActor
    private func setLoading(_ val: Bool) {
        isLoading = val
        errorMessage = nil
    }
}

private struct AuthResponse: Decodable {
    let session: Session
    struct Session: Decodable {
        let name: String
        let key: String
    }
}
