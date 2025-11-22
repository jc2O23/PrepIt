import SwiftUI
import CloudKit

struct ProfileUpdateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var session: SessionViewModel

    // Snapshot of the current session user
    let user: SessionViewModel.SessionUser

    @State private var displayName: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Display Name")) {
                    TextField("Enter new display name", text: $displayName)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("Password")) {
                    SecureField("New password", text: $newPassword)
                    SecureField("Confirm new password", text: $confirmPassword)

                    if !newPassword.isEmpty || !confirmPassword.isEmpty {
                        if newPassword != confirmPassword {
                            Text("Passwords do not match")
                                .foregroundStyle(.red)
                        } else if newPassword.count < 6 {
                            Text("Password must be at least 6 characters")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("Update Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveChanges)
                        .disabled(isSaveDisabled)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                displayName = user.displayName
                newPassword = ""
                confirmPassword = ""
            }
        }
    }

    // MARK: - Derived state

    private var isSaveDisabled: Bool {
        let nameEmpty = displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty

        let changingPassword = !newPassword.isEmpty || !confirmPassword.isEmpty
        let passwordValid = newPassword == confirmPassword && newPassword.count >= 6

        return nameEmpty || (changingPassword && !passwordValid)
    }

    // MARK: - Actions

    private func saveChanges() {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let changingPassword = !newPassword.isEmpty || !confirmPassword.isEmpty
        if changingPassword {
            guard newPassword == confirmPassword, newPassword.count >= 6 else { return }
        }

        // Use recordName from SessionUser to update in CloudKit
        let recordName = user.recordName

        CloudKitManager.shared.updateUserRecord(
            recordName: recordName,
            displayName: trimmedName,
            password: changingPassword ? newPassword : nil
        ) { result in
            Task { @MainActor in
                switch result {
                case .success:
                    // Update the session's currentUser with the new display name
                    session.currentUser = SessionViewModel.SessionUser(
                        recordName: user.recordName,
                        displayName: trimmedName,
                        userName: user.userName,
                        privLevel: user.privLevel
                    )
                    dismiss()

                case .failure(let error):
                    // You can surface this to the UI later if you want
                    print("Failed to update user in CloudKit: \(error)")
                }
            }
        }
    }
}
