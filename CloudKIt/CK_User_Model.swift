//
//  CK_User_Model.swift
//  PrepIt
//
//  Created by John Campbell on 11/21/25.
//

import Foundation
import CloudKit

extension CloudKitManager{
    // MARK: - Users (Public DB)

    /// Saves a user record (including password hash) to the public CloudKit database.
    /// Fields: displayName, userName, privLevel, passwordHash, passwordSalt
    func saveUser(displayName: String, userName: String, privLevel: String, password: String, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        print("Attempting to save user: @\(userName)")
        let record = CKRecord(recordType: "User")
        record["displayName"] = displayName as CKRecordValue
        record["userName"] = userName as CKRecordValue
        record["privLevel"] = privLevel as CKRecordValue

        // Hash + salt instead of storing plaintext password
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let salt = PasswordSecurity.generateSalt()
        let hash = PasswordSecurity.hashPassword(cleanPassword, salt: salt)
        record["passwordSalt"] = PasswordSecurity.toBase64(salt) as CKRecordValue
        record["passwordHash"] = PasswordSecurity.toBase64(hash) as CKRecordValue

        publicDB.save(record) { savedRecord, error in
            if let error = error {
                print("CloudKit Save User Error: \(error)")
                completion(.failure(error))
            } else if let savedRecord = savedRecord {
                print("Saved user to PUBLIC with recordID: \(savedRecord.recordID.recordName)")
                completion(.success(savedRecord.recordID))
            } else {
                let unknownError = NSError(
                    domain: "CloudKitManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown save user result"]
                )
                completion(.failure(unknownError))
            }
        }
    }

    /// Fetches user records (recordName, displayName, userName, privLevel) from the public CloudKit database.
    /// - Parameter completion: Called with an array of tuples.
    func fetchUserRecords(completion: @escaping ([(String, String, String, String)]) -> Void) {
        print("Attempting to fetch user records (PUBLIC via CKQueryOperation)")
        let query = CKQuery(recordType: "User", predicate: NSPredicate(value: true))
        var results: [(String, String, String, String)] = []

        func runOperation(with cursor: CKQueryOperation.Cursor?) {
            let op: CKQueryOperation = cursor.map(CKQueryOperation.init(cursor:)) ?? CKQueryOperation(query: query)
            op.desiredKeys = ["displayName", "userName", "privLevel"]
            op.resultsLimit = CKQueryOperation.maximumResults

            op.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    let displayName = record["displayName"] as? String ?? ""
                    let userName = record["userName"] as? String ?? ""
                    let privLevel = record["privLevel"] as? String ?? ""
                    results.append((recordID.recordName, displayName, userName, privLevel))
                case .failure(let error):
                    print("CloudKit user record fetch error: \(error)")
                }
            }

            op.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let cursor = cursor { runOperation(with: cursor) } else { completion(results) }
                case .failure(let error):
                    print("CloudKit Fetch Users Error (operation): \(error)")
                    completion(results)
                }
            }

            self.publicDB.add(op)
        }

        runOperation(with: nil)
    }

    /// Updates a user record's displayName and optionally password (hash) in the public CloudKit database.
    /// - Parameters:
    ///   - recordName: The CloudKit record name of the user to update.
    ///   - displayName: The new display name to set.
    ///   - password: Optional new password to set; pass nil to leave unchanged.
    ///   - completion: Called with the saved record ID on success or an error on failure.
    func updateUserRecord(
        recordName: String,
        displayName: String,
        password: String?,
        completion: @escaping (Result<CKRecord.ID, Error>) -> Void
    ) {
        let recordID = CKRecord.ID(recordName: recordName)
        publicDB.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let record = record else {
                let unknownError = NSError(
                    domain: "CloudKitManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "User record not found for update"]
                )
                completion(.failure(unknownError))
                return
            }

            record["displayName"] = displayName as CKRecordValue

            // If a new password was provided, recompute salt + hash
            if let newPassword = password {
                let cleanPassword = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
                let salt = PasswordSecurity.generateSalt()
                let hash = PasswordSecurity.hashPassword(cleanPassword, salt: salt)
                record["passwordSalt"] = PasswordSecurity.toBase64(salt) as CKRecordValue
                record["passwordHash"] = PasswordSecurity.toBase64(hash) as CKRecordValue
            }

            self.publicDB.save(record) { savedRecord, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let savedRecord = savedRecord else {
                    let unknownError = NSError(
                        domain: "CloudKitManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown update user result"]
                    )
                    completion(.failure(unknownError))
                    return
                }
                completion(.success(savedRecord.recordID))
            }
        }
    }

    /// Deletes a user record from the public CloudKit database by its record name.
    /// - Parameters:
    ///   - recordName: The CloudKit record name to delete.
    ///   - completion: A closure called with true if deletion succeeded, false otherwise.
    func deleteUser(recordName: String, completion: @escaping (Bool) -> Void) {
        let recordID = CKRecord.ID(recordName: recordName)
        publicDB.delete(withRecordID: recordID) { _, error in
            if let error = error {
                print("CloudKit Delete User Error: \(error)")
                completion(false)
            } else {
                print("Successfully deleted user with recordName: \(recordName)")
                completion(true)
            }
        }
    }
}

/// Verifies a user's credentials by hashing the provided password with the stored salt
/// and comparing it to the stored password hash.
/// - Parameters:
///   - userName: The username to look up.
///   - password: The plaintext password to verify.
///   - completion: Called with true if credentials are valid, false otherwise.
extension CloudKitManager {
    func verifyUserCredentials(userName: String, password: String, completion: @escaping (Bool) -> Void) {
        let predicate = NSPredicate(format: "userName == %@", userName)
        let query = CKQuery(recordType: "User", predicate: predicate)

        // Use the new iOS 15+ API
        publicDB.fetch(
            withQuery: query,
            inZoneWith: nil,
            desiredKeys: ["passwordSalt", "passwordHash"],
            resultsLimit: 1
        ) { result in
            switch result {
            case .failure(let error):
                print("verifyUserCredentials fetch error: \(error)")
                DispatchQueue.main.async { completion(false) }

            case .success(let fetchResult):
                guard
                    let firstMatch = fetchResult.matchResults.first,
                    let record = try? firstMatch.1.get(),
                    let saltBase64 = record["passwordSalt"] as? String,
                    let hashBase64 = record["passwordHash"] as? String,
                    let saltData = PasswordSecurity.fromBase64(saltBase64),
                    let storedHash = PasswordSecurity.fromBase64(hashBase64)
                else {
                    DispatchQueue.main.async { completion(false) }
                    return
                }

                let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
                let candidateHash = PasswordSecurity.hashPassword(cleanPassword, salt: saltData)
                let isValid = (candidateHash == storedHash)

                DispatchQueue.main.async {
                    completion(isValid)
                }
            }
        }
    }
}
