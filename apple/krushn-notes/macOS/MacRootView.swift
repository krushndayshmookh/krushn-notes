import SwiftUI

struct MacRootView: View {
    @EnvironmentObject private var auth: AuthManager

    var body: some View {
        if auth.isAuthenticated {
            MacContentView()
        } else {
            MacLoginView()
                .frame(width: 400, height: 300)
        }
    }
}
