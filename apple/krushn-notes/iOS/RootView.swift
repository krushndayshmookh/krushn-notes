import SwiftUI

struct RootView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        if auth.isAuthenticated {
            ContentView()
        } else {
            LoginView()
        }
    }
}
