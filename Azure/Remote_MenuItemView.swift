import SwiftUI

struct MenuItemView: View {
    @State private var items: [MenuItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = ServiceFetch(baseURL: URL(string: "https://prepit-d8ecehhyd8daapcg.westcentralus-01.azurewebsites.net")!)

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading menu…")
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text("Failed to load menu")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await load() }
                        }
                    }
                    .padding()
                } else if items.isEmpty {
                    ContentUnavailableView("No menu items", systemImage: "list.bullet.rectangle")
                } else {
                    List(items) { item in
                        NavigationLink {
                            MenuItemDetailView(item: item)
                        } label: {
                            MenuItemRow(item: item)
                        }
                    }
                }
            }
            .navigationTitle("Admin • Menu")
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
            .task { await load() }
            .refreshable { await load(force: true) }
        }
    }

    @MainActor
    private func load(force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let fetched = try await service.fetchMenuItems()
            items = fetched
        } catch {
            errorMessage = (error as? URLError)?.localizedDescription ?? error.localizedDescription
        }
    }
}

struct MenuItemRow: View {
    let item: MenuItem

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                HStack(spacing: 12) {
                    Text(priceString(item.price))
                        .font(.subheadline).bold()
                    Text("Stock: \(item.stock)")
                        .font(.caption)
                        .foregroundStyle(item.stock > 0 ? Color.secondary : Color.red)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func priceString(_ price: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f.string(from: NSNumber(value: price)) ?? "$\(price)"
    }
}

struct MenuItemDetailView: View {
    let item: MenuItem

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Name", value: item.name)
                LabeledContent("Price", value: priceString(item.price))
                LabeledContent("Stock", value: "\(item.stock)")
                LabeledContent("Parent ID", value: "\(item.parentID)")
                LabeledContent("Category", value: categoryName(for: item.mainGroup))
            }
            if !item.description.isEmpty {
                Section("Description") {
                    Text(item.description)
                }
            }
        }
        .navigationTitle(item.name)
    }

    private func priceString(_ price: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f.string(from: NSNumber(value: price)) ?? "$\(price)"
    }

    private func categoryName(for group: Int) -> String {
        switch group {
        case 1: return "Mains"
        case 3: return "Drinks"
        case 6: return "Sides"
        case 29: return "Happy Hour"
        default: return "Other (\(group))"
        }
    }
}

