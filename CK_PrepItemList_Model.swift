//
//  CK_PrepItemList_Model.swift
//  PrepIt
//
//  Created by John Campbell on 11/21/25.
//

import Foundation
import CloudKit

extension CloudKitManager {
    struct PrepItemListRecordFull {
        let recordID: CKRecord.ID
        let title: String
        let parAmount: String
        let parLabel: String
        let isViewable: Bool
        let currentValue: String
        let owner: String
        let moreInfo: String
        let stationName: String
        let createdAt: Date
        let recipeRecordName: String?
    }

    func savePrepItemList(
        title: String,
        parAmount: String,
        parLabel: String,
        isViewable: Bool,
        currentValue: String,
        owner: String,
        moreInfo: String,
        stationName: String,
        createdAt: Date = Date(),
        recipeRecordName: String? = nil,
        completion: @escaping (Result<CKRecord.ID, Error>) -> Void
    ) {
        let record = CKRecord(recordType: "PrepItemList")
        record["title"] = title as CKRecordValue
        record["parAmount"] = parAmount as CKRecordValue
        record["parLabel"] = parLabel as CKRecordValue
        record["isViewable"] = (isViewable as NSNumber)
        record["currentValue"] = currentValue as CKRecordValue
        record["owner"] = owner as CKRecordValue
        record["moreInfo"] = moreInfo as CKRecordValue
        record["stationName"] = stationName as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        if let recipeRecordName {
                record["recipeRecordName"] = recipeRecordName as CKRecordValue    // NEW
            }

        publicDB.save(record) { savedRecord, error in
            if let error = error { completion(.failure(error)); return }
            guard let savedRecord = savedRecord else {
                let unknownError = NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown save PrepItemList result"])
                completion(.failure(unknownError))
                return
            }
            completion(.success(savedRecord.recordID))
        }
    }

    func updatePrepItemList(
        recordName: String,
        title: String? = nil,
        parAmount: String? = nil,
        parLabel: String? = nil,
        isViewable: Bool? = nil,
        currentValue: String? = nil,
        owner: String? = nil,
        moreInfo: String? = nil,
        stationName: String? = nil,
        recipeRecordName: String? = nil,
        completion: @escaping (Result<CKRecord.ID, Error>) -> Void
    ) {
        let recordID = CKRecord.ID(recordName: recordName)
        publicDB.fetch(withRecordID: recordID) { record, error in
            if let error = error { completion(.failure(error)); return }
            guard let record = record else {
                let unknownError = NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Record not found for update"])
                completion(.failure(unknownError))
                return
            }
            if let title = title { record["title"] = title as CKRecordValue }
            if let parAmount = parAmount { record["parAmount"] = parAmount as CKRecordValue }
            if let parLabel = parLabel { record["parLabel"] = parLabel as CKRecordValue }
            if let isViewable = isViewable { record["isViewable"] = (isViewable as NSNumber) }
            if let currentValue = currentValue { record["currentValue"] = currentValue as CKRecordValue }
            if let owner = owner { record["owner"] = owner as CKRecordValue }
            if let moreInfo = moreInfo { record["moreInfo"] = moreInfo as CKRecordValue }
            if let stationName = stationName { record["stationName"] = stationName as CKRecordValue }

            if let recipeRecordName = recipeRecordName {
                        if recipeRecordName.isEmpty {
                            record["recipeRecordName"] = nil
                        } else {
                            record["recipeRecordName"] = recipeRecordName as CKRecordValue
                        }
                    }
            
            self.publicDB.save(record) { savedRecord, error in
                if let error = error { completion(.failure(error)); return }
                guard let savedRecord = savedRecord else {
                    let unknownError = NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown update PrepItemList result"])
                    completion(.failure(unknownError))
                    return
                }
                completion(.success(savedRecord.recordID))
            }
        }
    }

    func fetchPrepItemLists(for stationName: String, completion: @escaping ([PrepItemListRecordFull]) -> Void) {
        let predicate = NSPredicate(format: "stationName == %@", stationName)
        let query = CKQuery(recordType: "PrepItemList", predicate: predicate)
        var results: [PrepItemListRecordFull] = []

        func runOperation(with cursor: CKQueryOperation.Cursor?) {
            let op: CKQueryOperation = cursor.map(CKQueryOperation.init(cursor:)) ?? CKQueryOperation(query: query)
            op.desiredKeys = ["title", "parAmount", "parLabel", "isViewable", "currentValue", "owner", "moreInfo", "stationName", "createdAt", "recipeRecordName"]
            op.resultsLimit = CKQueryOperation.maximumResults

            op.recordMatchedBlock = { recordID, result in
                switch result {
                case .success(let record):
                    let title = record["title"] as? String ?? ""
                    let parAmount = record["parAmount"] as? String ?? ""
                    let parLabel = record["parLabel"] as? String ?? ""
                    let isViewable = (record["isViewable"] as? NSNumber)?.boolValue ?? true
                    let currentValue = record["currentValue"] as? String ?? ""
                    let owner = record["owner"] as? String ?? ""
                    let moreInfo = record["moreInfo"] as? String ?? ""
                    let stationName = record["stationName"] as? String ?? ""
                    let createdAt = (record["createdAt"] as? Date) ?? (record.creationDate ?? Date())
                    let recipeRecordName = record["recipeRecordName"] as? String
                    results.append(PrepItemListRecordFull(
                        recordID: recordID,
                        title: title,
                        parAmount: parAmount,
                        parLabel: parLabel,
                        isViewable: isViewable,
                        currentValue: currentValue,
                        owner: owner,
                        moreInfo: moreInfo,
                        stationName: stationName,
                        createdAt: createdAt,
                        recipeRecordName: recipeRecordName
                    ))
                case .failure(let error):
                    print("CloudKit fetchPrepItemLists record error: \(error)")
                }
            }

            op.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let cursor = cursor { runOperation(with: cursor) } else { completion(results) }
                case .failure(let error):
                    print("CloudKit fetchPrepItemLists error: \(error)")
                    completion(results)
                }
            }

            self.publicDB.add(op)
        }

        runOperation(with: nil)
    }
    func deletePrepItemList(recordName: String, completion: @escaping (Bool) -> Void) {
            let recordID = CKRecord.ID(recordName: recordName)
            publicDB.delete(withRecordID: recordID) { _, error in
                if let error = error {
                    print("CloudKit Delete PrepItemList Error: \(error)")
                    completion(false)
                } else {
                    print("Successfully deleted PrepItemList with recordName: \(recordName)")
                    completion(true)
                }
            }
        }
    

}
