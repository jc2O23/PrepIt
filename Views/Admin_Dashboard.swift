import SwiftData
import SwiftUI

// MARK: - AdminDashboardView

struct AdminDashboardView: View {
    @EnvironmentObject var session: SessionViewModel
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingProfile: Bool = false
    @State private var isShowingResetRoot: Bool = false
    @State private var newRootPassword: String = ""
    @State private var confirmRootPassword: String = ""
    @State private var resetError: String?
    @State private var isServerOnline: Bool = false
    @State private var isCheckingServer: Bool = false
    private let healthService = HealthService(baseURL: URL(string: "https://prepit-d8ecehhyd8daapcg.westcentralus-01.azurewebsites.net")!)



    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    ViewStationsView()
                } label: {
                    Label("View Stations", systemImage: "binoculars")
                }
                
                NavigationLink {
                    ManageStationsView()
                } label: {
                    Label("Manage Stations", systemImage: "slider.horizontal.3")
                }
                
                NavigationLink {
                    UserManagementView()
                } label: {
                    Label("Manage Users", systemImage: "person.3")
                }
                
                NavigationLink {
                    PrepRecipeAdminView()
                } label: {
                    Label("Manage Recipes", systemImage: "book.and.wrench")
                }
                
                NavigationLink {
                    ViewRecipesView()
                } label: {
                    Label("View Recipes", systemImage: "book.pages")
                }
                
                NavigationLink {
                    CompletedPrepListsView()
                } label: {
                    Label("Completed Prep Lists", systemImage: "checkmark.circle")
                }

                NavigationLink {
                    DiagnosticsView()
                } label: {
                    Label("Diagnostics", systemImage: "wrench.and.screwdriver")
                }
                
                NavigationLink {
                    RemoteConnectionView()
                } label: {
                    Label("Remote Connection", systemImage: "network")
                }
                .disabled(!isServerOnline)
                
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
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
                        Button {
                            isShowingResetRoot = true
                        } label: {
                            Label("Reset Root Password…", systemImage: "key.fill")
                        }
                    } label: {
                        if let name = session.currentUser?.displayName, !name.isEmpty {
                            Text(name)
                        } else {
                            Text("Account")
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            isCheckingServer = true
                            isServerOnline = await healthService.isServerOnline()
                            isCheckingServer = false
                        }
                    } label: {
                        if isCheckingServer {
                            ProgressView()
                        } else {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isCheckingServer)
                    .help("Retry server connection check")
                }
            }
            .task {
                isServerOnline = await healthService.isServerOnline()
            }
            .navigationTitle("Admin Dashboard")
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
