import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        Form {
            Section("Account") {
                LabeledContent("User ID", value: auth.userId)

                Button(role: .destructive) {
                    auth.logout()
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                LabeledContent("API", value: APIClient.shared.baseURL)
            }
        }
        .navigationTitle("Settings")
    }
}
