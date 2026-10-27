import SwiftUI

extension RAAchievement: Identifiable {
    public var id: UInt32 { identifier }
}

struct AchievementsView: View {
    @ObservedObject var model: EmulatorModel
    @Environment(\.dismiss) private var dismiss
    @State private var user = ""
    @State private var pass = ""

    var body: some View {
        NavigationStack {
            List {
                Section("RetroAchievements") {
                    if let name = model.raUserName {
                        HStack { Text("Signed in as"); Spacer(); Text(name).bold() }
                        HStack { Text("Score"); Spacer(); Text("\(model.raScore)") }
                        Button("Log out", role: .destructive) { model.raLogout() }
                    } else {
                        TextField("Username", text: $user)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Password", text: $pass)
                        Button("Log in") { model.raLogin(user: user, password: pass); pass = "" }
                            .disabled(user.isEmpty || pass.isEmpty)
                        Text("Your password is only sent to retroachievements.org to get a login token; only the token is kept, in the iOS Keychain.")
                            .font(.footnote).foregroundColor(.secondary)
                    }
                    if let err = model.raError { Text(err).font(.footnote).foregroundColor(.red) }
                    if !model.raStatus.isEmpty { Text(model.raStatus).font(.footnote).foregroundColor(.secondary) }
                }

                Section("Game (softcore mode)") {
                    Text(model.raGameTitle ?? "No achievement set for the booted disk")
                    if !model.raSummary.isEmpty { Text(model.raSummary).font(.footnote) }
                    if let hash = model.currentHash {
                        Text("Disk MD5: \(hash)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary)
                    }
                }

                if !model.raAchievements.isEmpty {
                    Section("Achievements") {
                        ForEach(model.raAchievements) { a in
                            HStack(alignment: .top, spacing: 10) {
                                AsyncImage(url: a.badgeURL) { img in img.resizable() } placeholder: { Color.gray.opacity(0.25) }
                                    .frame(width: 44, height: 44).cornerRadius(6)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.title).bold()
                                    Text(a.detail).font(.caption).foregroundColor(.secondary)
                                    if let p = a.progress { Text(p).font(.caption2).foregroundColor(.orange) }
                                }
                                Spacer()
                                VStack { Text("\(a.points)").bold(); Text(a.unlocked ? "✓" : "🔒").font(.caption) }
                            }
                        }
                    }
                }

                Section("Debug log") {
                    Text(model.raLog.isEmpty ? "(empty)" : model.raLog)
                        .font(.system(size: 9, design: .monospaced)).textSelection(.enabled)
                }
            }
            .navigationTitle("Achievements")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct ToastView: View {
    let toast: RAToast
    var body: some View {
        HStack(spacing: 10) {
            AsyncImage(url: toast.badge) { img in img.resizable() } placeholder: { Color.gray.opacity(0.3) }
                .frame(width: 48, height: 48).cornerRadius(8)
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title).font(.headline).foregroundColor(.white)
                Text(toast.message).font(.subheadline).foregroundColor(.white.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.black.opacity(0.78))
        .cornerRadius(12)
        .padding(.horizontal, 12)
    }
}
