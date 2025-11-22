//
//  CK_Station_Model.swift
//  PrepIt
//
//  Created by John Campbell on 11/21/25.
//

import Foundation
import CloudKit

extension CloudKitManager {
    func saveStation(stationName: String, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        print("Attempting to save station: \(stationName)")
        let record = CKRecord(recordType: "Station")
        record["stationName"] = stationName as CKRecordValue
        publicDB.save(record) { savedRecord, error in
            if let error = error {
                print("CloudKit Save Error: \(error)")
                completion(.failure(error))
            } else if let savedRecord = savedRecord {
                print("Saved to PUBLIC with recordID: \(savedRecord.recordID.recordName)")
                print("Successfully saved station: \(stationName)")
                completion(.success(savedRecord.recordID))
            } else {
                let unknownError = NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown save result"])
                completion(.failure(unknownError))
            }
        }
    }

    /// Fetches all station records from the public CloudKit database and returns their names.
    /// - Parameter completion: A closure called with an array of station names.
    func fetchStations(completion: @escaping ([String]) -> Void) {
        print("Attempting to fetch stations from CloudKit (PUBLIC via CKQueryOperation)")
        let query = CKQuery(recordType: "Station", predicate: NSPredicate(value: true))
        var allStationNames: [String] = []

        func runOperation(with cursor: CKQueryOperation.Cursor?) {
            let op: CKQueryOperation
            if let cursor = cursor {
                op = CKQueryOperation(cursor: cursor)
            } else {
                op = CKQueryOperation(query: query)
            }
            op.desiredKeys = ["stationName"]
            op.resultsLimit = CKQueryOperation.maximumResults

            op.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    if let name = record["stationName"] as? String {
                        allStationNames.append(name)
                    }
                case .failure(let error):
                    print("CloudKit record fetch error: \(error)")
                }
            }

            op.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let cursor = cursor {
                        // Continue with next page
                        runOperation(with: cursor)
                    } else {
                        completion(allStationNames)
                    }
                case .failure(let error):
                    print("CloudKit Fetch Error (operation): \(error)")
                    completion(allStationNames)
                }
            }

            self.publicDB.add(op)
        }

        runOperation(with: nil)
    }

    /// Fetches station records (recordName and stationName) from the public CloudKit database.
    /// - Parameter completion: Called with an array of (recordName, stationName) tuples.
    func fetchStationRecords(completion: @escaping ([(String, String)]) -> Void) {
        print("Attempting to fetch station records (PUBLIC via CKQueryOperation)")
        let query = CKQuery(recordType: "Station", predicate: NSPredicate(value: true))
        var results: [(String, String)] = []

        func runOperation(with cursor: CKQueryOperation.Cursor?) {
            let op: CKQueryOperation
            if let cursor = cursor {
                op = CKQueryOperation(cursor: cursor)
            } else {
                op = CKQueryOperation(query: query)
            }
            op.desiredKeys = ["stationName"]
            op.resultsLimit = CKQueryOperation.maximumResults

            op.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    if let name = record["stationName"] as? String {
                        results.append((recordID.recordName, name))
                    }
                case .failure(let error):
                    print("CloudKit record fetch error: \(error)")
                }
            }

            op.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let cursor = cursor {
                        runOperation(with: cursor)
                    } else {
                        completion(results)
                    }
                case .failure(let error):
                    print("CloudKit Fetch Error (operation): \(error)")
                    completion(results)
                }
            }

            self.publicDB.add(op)
        }

        runOperation(with: nil)
    }

    /// Deletes a station record from the public CloudKit database by its record name.
    /// - Parameters:
    ///   - recordName: The CloudKit record name to delete.
    ///   - completion: A closure called with true if deletion succeeded, false otherwise.
    func deleteStation(recordName: String, completion: @escaping (Bool) -> Void) {
        let recordID = CKRecord.ID(recordName: recordName)
        publicDB.delete(withRecordID: recordID) { _, error in
            if let error = error {
                print("CloudKit Delete Error: \(error)")
                completion(false)
            } else {
                print("Successfully deleted station with recordName: \(recordName)")
                completion(true)
            }
        }
    }
}
