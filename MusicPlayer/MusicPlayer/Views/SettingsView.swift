import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var lastFM: LastFMService
    @State private var username = ""
    @State private var password = ""
    @State private var apiKey = ""
    @State private var apiSecret = ""
    @State private var showPassword = false

    var body: some View {
        NavigationView {
            Form {
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
                                if lastFM.isLoading {
                                    ProgressView()
                                } else {
                                    Text("Sign In")
                                }
                                Spacer()
                            }
                        }
                        .disabled(lastFM.isLoading || username.isEmpty || password.isEmpty)
                    }

                    if let error = lastFM.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section("Scrobbling") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(lastFM.isAuthenticated ? "Active" : "Not Connected")
                            .foregroundColor(lastFM.isAuthenticated ? .green : .secondary)
                    }
                    Text("Tracks are scrobbled after 50% playback (minimum 30 seconds).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("About") {
                    LabeledContent("App", value: "Music Player")
                    LabeledContent("Version", value: "1.0")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                apiKey = lastFM.apiKey
                apiSecret = lastFM.apiSecret
                username = lastFM.username
            }
            .onChange(of: apiKey) { _, v in lastFM.apiKey = v; lastFM.save() }
            .onChange(of: apiSecret) { _, v in lastFM.apiSecret = v; lastFM.save() }
        }
    }

    private func signIn() {
        lastFM.apiKey = apiKey
        lastFM.apiSecret = apiSecret
        lastFM.save()
        Task {
            await lastFM.authenticate(username: username, password: password)
        }
    }
}
