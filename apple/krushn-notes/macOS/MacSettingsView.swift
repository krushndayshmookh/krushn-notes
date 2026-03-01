import SwiftUI

struct MacSettingsView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("User ID", value: auth.userId)
                Button("Log Out", role: .destructive) {
                    auth.logout()
                }
            }
            Section("About") {
                LabeledContent("API", value: APIClient.shared.baseURL)
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 220)
        .navigationTitle("Settings")
    }
}
