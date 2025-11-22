//
//  CK_SubmittedPrepItem_Model.swift
//  PrepIt
//
//  Created by John Campbell on 11/21/25.
//

import Foundation
import CloudKit

extension CloudKitManager {
    struct SubmittedPrepItemRecord: Identifiable, Hashable {
        let id: String // recordName
        let prepName: String
        let parLabel: String
        let parAmount: String
        let prepComplete: String
        let userSubmit: String
        let notes: String
        let date: Date
        let stationName: String
    }

    /// Fetches SubmittedPrepItem records from the public CloudKit database.
    /// - Parameter completion: Called with an array of SubmittedPrepItemRecord.
    func fetchSubmittedPrepItems(completion: @escaping ([SubmittedPrepItemRecord]) -> Void) {
        let query = CKQuery(recordType: "SubmittedPrepItem", predicate: NSPredicate(value: true))
        var results: [SubmittedPrepItemRecord] = []
        let op = CKQueryOperation(query: query)
        op.desiredKeys = ["prepName", "parLabel", "parAmount", "prepComplete", "userSubmit", "notes", "date", "stationName"]
        op.resultsLimit = CKQueryOperation.maximumResults
        op.recordMatchedBlock = { recordID, result in
            switch result {
            case .success(let record):
                let prepName = record["prepName"] as? String ?? ""
                let parLabel = record["parLabel"] as? String ?? ""
                let parAmount = record["parAmount"] as? String ?? ""
                let prepComplete = record["prepComplete"] as? String ?? ""
                let userSubmit = record["userSubmit"] as? String ?? ""
                let notes = record["notes"] as? String ?? ""
                let date = record["date"] as? Date ?? (record.creationDate ?? Date())
                let stationName = record["stationName"] as? String ?? ""
                let rec = SubmittedPrepItemRecord(
                    id: recordID.recordName,
                    prepName: prepName,
                    parLabel: parLabel,
                    parAmount: parAmount,
                    prepComplete: prepComplete,
                    userSubmit: userSubmit,
                    notes: notes,
                    date: date,
                    stationName: stationName
                )
                results.append(rec)
            case .failure(let error):
                print("CloudKit fetchSubmittedPrepItems error: \(error)")
            }
        }
        op.queryResultBlock = { _ in
            DispatchQueue.main.async { completion(results) }
        }
        self.publicDB.add(op)
    }
}
