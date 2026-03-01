import SwiftUI
import AppKit


struct MacLoginView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "note.text")
                .font(.system(size: 56))
            Text("krushn notes")
                .font(.largeTitle.bold())
            Text("Personal notes & tasks")
                .foregroundStyle(.secondary)

            Spacer()

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task {
                    isLoading = true
                    errorMessage = nil
                    guard let window = NSApp.keyWindow else { return }
                    await auth.loginWithGitHub(presentationAnchor: window)
                    if !auth.isAuthenticated {
                        errorMessage = "Login failed. Please try again."
                    }
                    isLoading = false
                }
            } label: {
                HStack {
                    if isLoading { ProgressView().controlSize(.small) }
                    Text("Continue with GitHub")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            .padding(.horizontal, 40)
            .padding(.bottom, 32)
        }
        .padding()
    }
}
