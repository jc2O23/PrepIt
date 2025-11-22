import SwiftUI

struct Remote_MenusListView: View {
    @State private var menus: [ResMenu] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = ServiceFetch(
        baseURL: URL(string: "https://prepit-d8ecehhyd8daapcg.westcentralus-01.azurewebsites.net")!
    )

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading menus…")
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Failed to load menus")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await load(force: true) }
                    }
                }
                .padding()
            } else if menus.isEmpty {
                ContentUnavailableView("No menus", systemImage: "list.bullet.rectangle")
            } else {
                List(menus) { menu in
                    NavigationLink {
                        Remote_MenuDetailView(menu: menu)
                    } label: {
                        Remote_MenuRow(menu: menu)
                    }
                }
                .refreshable { await load(force: true) }
            }
        }
        .navigationTitle("Menus")
        .task { await load() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load(force: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
    }

    @MainActor
    private func load(force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await service.fetchMenus()
            menus = fetched
        } catch {
            errorMessage = (error as? URLError)?.localizedDescription ?? error.localizedDescription
        }
    }
}

private struct Remote_MenuRow: View {
    let menu: ResMenu

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(menu.menuName)
                .font(.headline)
            Text("\(menu.menuStartTime) – \(menu.menuEndTime) • \(menu.menuDays)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct Remote_MenuDetailView: View {
    let menu: ResMenu

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Name", value: menu.menuName)
                LabeledContent("Start", value: menu.menuStartTime)
                LabeledContent("End", value: menu.menuEndTime)
                LabeledContent("Days", value: menu.menuDays)
                LabeledContent("ID", value: "\(menu.id)")
            }
        }
        .navigationTitle(menu.menuName)
    }
}
