import SwiftUI
import CloudKit

struct User: Identifiable, Hashable {
    let id = UUID()
    var displayName: String
    var userName: String
    var privLevel: String
    var canDelete: Bool
    var cloudKitRecordName: String?
}
struct UserManagementView: View {
    @EnvironmentObject var session: SessionViewModel

    @State private var remoteUsers: [User] = []
    @State private var isLoading: Bool = false

    @State private var isPresentingAdd: Bool = false
    @State private var newDisplayName: String = ""
    @State private var newName: String = ""
    @State private var newPassword: String = ""
    @State private var confirmNewPassword: String = ""
    @State private var newPriv: Privilege = .user

    @State private var pendingDelete: User?
    @State private var deleteAlert: Bool = false
    @State private var addError: String?

    @State private var selectedUserForEdit: User?
    @State private var isPresentingEdit: Bool = false

    enum Privilege: String, CaseIterable, Identifiable {
        case admin = "Admin"
        case user = "User"
        case viewer = "Viewer"
        var id: String { rawValue }
    }

    // Username that represents the root (non-deletable) user in CloudKit
    private let rootUserName: String = "root"

    var body: some View {
        Group {
            if isLoading && remoteUsers.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading users…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Users") {
                        ForEach(remoteUsers) { user in
                            let canModify = user.canDelete && user.userName != session.currentUser?.userName

                            HStack {
                                VStack(alignment: .leading) {
                                    Text(user.displayName)
                                        .font(.headline)
                                    Text("@\(user.userName) • \(user.privLevel)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if user.userName == session.currentUser?.userName {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                        .foregroundStyle(.blue)
                                        .help("Current user")
                                }
                            }
                            // Context menu: only show actions when allowed
                            .contextMenu {
                                if canModify {
                                    Button {
                                        selectedUserForEdit = user
                                        isPresentingEdit = true
                                    } label: {
                                        Label("Update Profile…", systemImage: "pencil")
                                    }
                                }
                            }
                            // Swipe actions: only show when allowed
                            .swipeActions {
                                if canModify {
                                    Button(role: .destructive) {
                                        if user.userName == session.currentUser?.userName {
                                            addError = "You cannot delete the currently signed-in user."
                                        } else if user.canDelete == false {
                                            addError = "You cannot delete the root user."
                                        } else {
                                            pendingDelete = user
                                            deleteAlert = true
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .opacity(canModify ? 1.0 : 0.6)
                            .allowsHitTesting(canModify)
                        }
                    }
                }
                .refreshable {
                    await syncUsersFromCloud()
                }
            }
        }
        .navigationTitle("Manage Users")
        .task { await syncUsersFromCloud() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        // Delete alert
        .alert("Delete User?", isPresented: $deleteAlert, presenting: pendingDelete) { user in
            Button("Delete", role: .destructive) {
                handleDeleteConfirmed()
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { user in
            Text("This will remove \(user.displayName) (@\(user.userName)).")
        }
        // Add user sheet
        .sheet(isPresented: $isPresentingAdd) {
            NavigationStack {
                Form {
                    Section("Credentials") {
                        TextField("Display name", text: $newDisplayName)
                        TextField("Username (unique)", text: $newName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textContentType(.username)

                        SecureField("Password", text: $newPassword)
                            .textContentType(.password)
                        SecureField("Confirm Password", text: $confirmNewPassword)
                            .textContentType(.password)

                        if !newPassword.isEmpty || !confirmNewPassword.isEmpty {
                            if newPassword != confirmNewPassword {
                                Text("Passwords do not match")
                                    .foregroundStyle(.red)
                            } else if newPassword.count < 6 {
                                Text("Password must be at least 6 characters")
                                    .foregroundStyle(.red)
                            }
                        }

                        if let addError {
                            Text(addError)
                                .foregroundStyle(.red)
                        }
                    }

                    Section("Privilege") {
                        Picker("Role", selection: $newPriv) {
                            ForEach(Privilege.allCases) { role in
                                Text(role.rawValue).tag(role)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .navigationTitle("Add User")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isPresentingAdd = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveUser() }
                            .disabled({
                                let displayOK = !newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                let nameOK = !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                let pwdOK = !newPassword.isEmpty &&
                                            newPassword == confirmNewPassword &&
                                            newPassword.count >= 6
                                return !(displayOK && nameOK && pwdOK) || addError != nil
                            }())
                    }
                }
            }
        }
        // Edit sheet
        .sheet(isPresented: $isPresentingEdit) {
            if let u = selectedUserForEdit {
                NavigationStack {
                    ProfileUpdateView(user: SessionViewModel.SessionUser(
                        recordName: u.cloudKitRecordName ?? "",
                        displayName: u.displayName,
                        userName: u.userName,
                        privLevel: u.privLevel
                    ))
                }
            } else {
                Text("No user selected")
            }
        }
    }

    // MARK: - Cloud

    /// Async wrapper for fetchUserRecords(completion:).
    private func fetchUserRecordsAsync() async -> [(String, String, String, String)] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[(String, String, String, String)], Never>) in
            CloudKitManager.shared.fetchUserRecords { records in
                continuation.resume(returning: records)
            }
        }
    }

    private func syncUsersFromCloud() async {
        let records = await fetchUserRecordsAsync()
        await MainActor.run {
            var seen = Set<String>()
            var fetched: [User] = []

            for rec in records {
                let recordName = rec.0   // CloudKit recordName
                let displayName = rec.1
                let userName = rec.2
                let privLevel = rec.3

                if seen.insert(userName).inserted {
                    let canDelete = (userName != rootUserName)
                    let u = User(
                        displayName: displayName,
                        userName: userName,
                        privLevel: privLevel,
                        canDelete: canDelete,
                        cloudKitRecordName: recordName
                    )
                    fetched.append(u)
                }
            }

            remoteUsers = fetched
            isLoading = false
        }
    }

    private func handleDeleteConfirmed() {
        guard let u = pendingDelete else { return }

        defer { pendingDelete = nil }

        if u.userName == session.currentUser?.userName {
            addError = "You cannot delete the currently signed-in user."
            return
        } else if u.canDelete == false {
            addError = "You cannot delete the root user."
            return
        }

        if let recordName = u.cloudKitRecordName, !recordName.isEmpty {
            CloudKitManager.shared.deleteUser(recordName: recordName) { success in
                DispatchQueue.main.async {
                    if success {
                        if let idx = remoteUsers.firstIndex(where: { $0.id == u.id }) {
                            remoteUsers.remove(at: idx)
                        }
                    } else {
                        addError = "Couldn't delete user from iCloud. Please try again."
                    }
                }
            }
        } else {
            if let idx = remoteUsers.firstIndex(where: { $0.id == u.id }) {
                remoteUsers.remove(at: idx)
            }
        }
    }

    private func saveUser() {
        let display = newDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        addError = nil

        guard !display.isEmpty, !name.isEmpty, !newPassword.isEmpty else { return }

        // Uniqueness check (local, from loaded users)
        if remoteUsers.contains(where: { $0.userName == name }) {
            addError = "That username is already taken."
            return
        }

        CloudKitManager.shared.saveUser(
            displayName: display,
            userName: name,
            privLevel: newPriv.rawValue,
            password: newPassword
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let recordID):
                    let user = User(
                        displayName: display,
                        userName: name,
                        privLevel: newPriv.rawValue,
                        canDelete: true,
                        cloudKitRecordName: recordID.recordName
                    )
                    remoteUsers.append(user)

                    newDisplayName = ""
                    newName = ""
                    newPassword = ""
                    confirmNewPassword = ""
                    newPriv = .user
                    isPresentingAdd = false

                case .failure(let error):
                    addError = "Couldn't save user to iCloud: \(error.localizedDescription)"
                }
            }
        }
    }
}
