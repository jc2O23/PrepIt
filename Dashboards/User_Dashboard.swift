import SwiftUI

struct UserDashboardView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var isShowingProfile: Bool = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    ViewStationsView()
                } label: {
                    Label("View Stations", systemImage: "binoculars")
                }
                NavigationLink {
                    ViewRecipesView()
                } label: {
                    Label("View Recipes", systemImage: "book")
                }
                NavigationLink {
                    CompletedPrepListsView()
                } label: {
                    Label("Completed Prep Lists", systemImage: "checkmark.circle")
                }
            }
            .navigationTitle("User Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(role: .destructive) {
                            session.signOut()
                        } label: {
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        Button {
                            isShowingProfile = true
                        } label: {
                            Label("Update Profile…", systemImage: "person.crop.circle.badge.plus")
                        }
                    } label: {
                        if let name = session.currentUser?.displayName, !name.isEmpty {
                            Text(name)
                        } else {
                            Text("Account")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingProfile) {
                if let user = session.currentUser {
                    ProfileUpdateView(user: user)
                } else {
                    Text("No user signed in.")
                        .padding()
                }
            }
        }
    }
}
