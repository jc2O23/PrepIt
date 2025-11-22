import SwiftUI

struct RemoteConnectionView: View {
    var body: some View {
        List {
            NavigationLink {
                Remote_MenusListView()
            } label: {
                Label("Menus", systemImage: "list.bullet.rectangle")
            }

            NavigationLink {
                MenuItemView()
            } label: {
                Label("Menu Items", systemImage: "fork.knife")
            }

            NavigationLink {
                EmployeesListView()
            } label: {
                Label("Employees", systemImage: "person.2")
            }


        }
        .navigationTitle("Remote Connection")
    }
}

