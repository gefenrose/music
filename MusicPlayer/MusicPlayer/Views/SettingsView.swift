import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var lastFM:  LastFMService
    @EnvironmentObject var library: MusicLibraryManager
    @State private var username = ""
    @State private var password = ""
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var showPassword = false
    @State private var showImporter = false
    @State private var importMessage: String?

    var body: some View {
        NavigationView {
            Form {
                // MARK: Import Music
                Section("Import Music") {
                    Button {
                        showImporter = true
                    } label: {
                        Label("Import Files", systemImage: "square.and.arrow.down")
                    }

                    if let msg = importMessage {
                        Text(msg).font(.caption).foregroundColor(.secondary)
                    }

                    let localCount = library.songs.filter { $0.id.hasPrefix("local:") }.count
                    if localCount > 0 {
                        Text("\(localCount) imported file\(localCount == 1 ? "" : "s") on device")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text("Supports MP3, M4A, AAC, WAV, AIFF, FLAC. You can also add files via the Files app or Finder (USB).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: Last.fm API Credentials
                Section("Last.fm API Credentials") {
                    TextField("API Key", text: $apiKey)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    SecureField("API Secret", text: $apiSecret)

                    HStack {
                        Spacer()
                        Link("Get API credentials at last.fm/api", destination: URL(string: "https://www.last.fm/api/account/create")!)
                            .font(.caption)
                    }
                }

                // MARK: Last.fm Account
                Section("Last.fm Account") {
                    if lastFM.isAuthenticated {
                        HStack {
                            Label(lastFM.username, systemImage: "person.fill")
                            Spacer()
                            Text("Connected")
                                .foregroundColor(.green)
                                .font(.subheadline)
                        }
                        Button("Sign Out", role: .destructive) {
                            lastFM.logout()
                        }
                    } else {
                        TextField("Username", text: $username)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        HStack {
                            if showPassword {
                                TextField("Password", text: $password)
                                    .autocapitalization(.none)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("Password", text: $password)
                            }
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button(action: signIn) {
                            HStack {
                                Spacer()
                                if lastFM.isLoading { ProgressView() }
                                else { Text("Sign In") }
                                Spacer()
                            }
                        }
                        .disabled(lastFM.isLoading || username.isEmpty || password.isEmpty)
                    }

                    if let error = lastFM.errorMessage {
                        Text(error).foregroundColor(.red).font(.caption)
                    }
                }

                // MARK: Scrobbling
                Section("Scrobbling") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(lastFM.isAuthenticated ? "Active" : "Not Connected")
                            .foregroundColor(lastFM.isAuthenticated ? .green : .secondary)
                    }
                    Text("Tracks are scrobbled after 50% playback (minimum 30 seconds).")
                        .font(.caption).foregroundColor(.secondary)
                }

                Section("About") {
                    LabeledContent("App", value: "Music Player")
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                apiKey    = lastFM.apiKey
                apiSecret = lastFM.apiSecret
                username  = lastFM.username
            }
            .onChange(of: apiKey)    { _, v in lastFM.apiKey = v;    lastFM.save() }
            .onChange(of: apiSecret) { _, v in lastFM.apiSecret = v; lastFM.save() }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    importMessage = "Importing \(urls.count) file\(urls.count == 1 ? "" : "s")…"
                    library.importFiles(from: urls)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { importMessage = nil }
                case .failure(let error):
                    importMessage = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func signIn() {
        lastFM.apiKey    = apiKey
        lastFM.apiSecret = apiSecret
        lastFM.save()
        Task { await lastFM.authenticate(username: username, password: password) }
    }
}
