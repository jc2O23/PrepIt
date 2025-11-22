import SwiftUI

struct EmployeesListView: View {
    @State private var employees: [Employee] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = ServiceFetch(
        baseURL: URL(string: "https://prepit-d8ecehhyd8daapcg.westcentralus-01.azurewebsites.net")!
    )

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading employees…")
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Text("Failed to load employees")
                        .font(.headline)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await load(force: true) }
                    }
                }
                .padding()
            } else if employees.isEmpty {
                ContentUnavailableView("No employees", systemImage: "person.2")
            } else {
                List(employees) { emp in
                    EmployeeRow(employee: emp)
                }
                .refreshable { await load(force: true) }
            }
        }
        .navigationTitle("Employees")
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
            let fetched = try await service.fetchEmployees()
            employees = fetched
        } catch {
            errorMessage = (error as? URLError)?.localizedDescription ?? error.localizedDescription
        }
    }
}

private struct EmployeeRow: View {
    let employee: Employee

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(employee.displayName.isEmpty ? "\(employee.firstName) \(employee.lastName)" : employee.displayName)
                    .font(.headline)
                Text("\(employee.role) • Access: \(employee.accessLevel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("PIN #: \(employee.pinNum)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("#\(employee.id)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }
}

