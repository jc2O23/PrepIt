import SwiftUI
import Combine

@MainActor
final class SessionViewModel: ObservableObject {
    struct SessionUser {
        let recordName: String
        let displayName: String
        let userName: String
        let privLevel: String
    }

    @Published var isAuthenticated: Bool = false
    @Published var currentUser: SessionUser?
    @Published var isSigningIn: Bool = false
    @Published var signInError: String?

    func signIn(username: String, password: String) async -> Bool {
        isSigningIn = true
        signInError = nil
        defer { isSigningIn = false }

        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)

        // DEBUG-only local root user (no CloudKit)
        #if DEBUG
        if u == "root", p == "changeMe" {
            currentUser = SessionUser(
                recordName: "local-root",
                displayName: "Root User",
                userName: "root",
                privLevel: "Admin"
            )
            isAuthenticated = true
            return true
        }
        #endif

        // Ask CloudKitManager to validate the password correctly
        let isValid = await verifyCredentialsAsync(username: u, password: p)

        guard isValid else {
            isAuthenticated = false
            currentUser = nil
            signInError = "Invalid username or password."
            return false
        }

        // We still need the user's display information after validation
        let records = await fetchUserRecordsAsync()
        guard let match = records.first(where: { $0.2 == u }) else {
            isAuthenticated = false
            currentUser = nil
            signInError = "User not found after validation."
            return false
        }

        currentUser = SessionUser(
            recordName: match.0,
            displayName: match.1,
            userName: match.2,
            privLevel: match.3
        )
        isAuthenticated = true
        return true
    }

    func signOut() {
        isAuthenticated = false
        currentUser = nil
    }

    // MARK: - CloudKit bridge
    private func fetchUserRecordsAsync() async -> [(String, String, String, String)] {
        await withCheckedContinuation { (continuation: CheckedContinuation<[(String, String, String, String)], Never>) in
            CloudKitManager.shared.fetchUserRecords { records in
                continuation.resume(returning: records)
            }
        }
    }
    private func verifyCredentialsAsync(username: String, password: String) async -> Bool {
        await withCheckedContinuation { continuation in
            CloudKitManager.shared.verifyUserCredentials(
                userName: username,
                password: password
            ) { isValid in
                continuation.resume(returning: isValid)
            }
        }
    }
}
