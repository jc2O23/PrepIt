import SwiftUI
import SwiftData

struct RootView: View {
    @EnvironmentObject var session: SessionViewModel

    var body: some View {
        Group {
            if session.isAuthenticated {
                if (session.currentUser?.privLevel == "Admin") {
                    AdminDashboardView()
                } else if (session.currentUser?.privLevel == "Viewer") {
                    ViewerDashboardView()
                } else {
                    UserDashboardView()
                }
            } else {
                LoginView()
            }
        }
    }
}
