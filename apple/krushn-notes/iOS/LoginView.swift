import SwiftUI
import AuthenticationServices


struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "note.text")
                    .font(.system(size: 64))
                    .foregroundStyle(.primary)
                Text("krushn notes")
                    .font(.largeTitle.bold())
                Text("Personal notes & tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task {
                        isLoading = true
                        errorMessage = nil
                        // Get the window scene for presentation
                        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let window = scene.windows.first else {
                            isLoading = false
                            return
                        }
                        await auth.loginWithGitHub(presentationAnchor: window)
                        if !auth.isAuthenticated {
                            errorMessage = "Login failed. Please try again."
                        }
                        isLoading = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                        }
                        Text("Continue with GitHub")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.primary)
                    .foregroundStyle(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}
