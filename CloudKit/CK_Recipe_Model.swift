//
//  CK_Recipe_Model.swift
//  PrepIt
//
//  Created by John Campbell on 11/21/25.
//

import Foundation
import CloudKit

// MARK: - CKRecipe Model

struct CKRecipe: Identifiable, Equatable {
    let id: CKRecord.ID
    var name: String
    var ingredients: String
    var instructions: String
    var isViewable: Bool
}

private let recipeRecordType = "Recipe"

extension CKRecipe {
    init?(record: CKRecord) {
        guard
            record.recordType == recipeRecordType,
            let name = record["name"] as? String,
            let ingredients = record["ingredients"] as? String,
            let instructions = record["instructions"] as? String
        else {
            return nil
        }
        self.id = record.recordID
        self.name = name
        self.ingredients = ingredients
        self.instructions = instructions
        self.isViewable = (record["isViewable"] as? NSNumber)?.boolValue ?? true
    }

    func toRecord() -> CKRecord {
        let record = CKRecord(recordType: recipeRecordType, recordID: id)
        record["name"] = name as CKRecordValue
        record["ingredients"] = ingredients as CKRecordValue
        record["instructions"] = instructions as CKRecordValue
        record["isViewable"] = NSNumber(value: isViewable)   // NEW
        return record
    }
}

// MARK: - CloudKitManager Recipe APIs

extension CloudKitManager {

    // Fetch all recipes from PUBLIC DB
    func fetchRecipes(completion: @escaping ([CKRecipe]) -> Void) {
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: recipeRecordType, predicate: predicate)
        var allRecipes: [CKRecipe] = []

        func runOperation(with cursor: CKQueryOperation.Cursor?) {
            let op: CKQueryOperation = cursor.map(CKQueryOperation.init(cursor:)) ?? CKQueryOperation(query: query)
            op.resultsLimit = CKQueryOperation.maximumResults

            op.recordMatchedBlock = { _, result in
                switch result {
                case .success(let record):
                    if let recipe = CKRecipe(record: record) {
                        allRecipes.append(recipe)
                    }
                case .failure(let error):
                    print("CloudKit fetchRecipes record error: \(error)")
                }
            }

            op.queryResultBlock = { result in
                switch result {
                case .success(let cursor):
                    if let cursor = cursor {
                        runOperation(with: cursor)
                    } else {
                        DispatchQueue.main.async {
                            completion(allRecipes)
                        }
                    }
                case .failure(let error):
                    print("CloudKit fetchRecipes error: \(error)")
                    DispatchQueue.main.async {
                        completion(allRecipes)
                    }
                }
            }

            self.publicDB.add(op)
        }

        runOperation(with: nil)
    }

    // Add a new recipe
    func addRecipe(
        name: String,
        ingredients: String,
        instructions: String,
        isViewable: Bool = true,   // NEW param with default
        completion: @escaping (Result<CKRecipe, Error>) -> Void
    ) {
        let record = CKRecord(recordType: recipeRecordType)
        record["name"] = name as CKRecordValue
        record["ingredients"] = ingredients as CKRecordValue
        record["instructions"] = instructions as CKRecordValue
        record["isViewable"] = NSNumber(value: isViewable)       // NEW

        publicDB.save(record) { savedRecord, error in
            if let error = error {
                print("CloudKit addRecipe error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            guard let savedRecord = savedRecord, let recipe = CKRecipe(record: savedRecord) else {
                let err = NSError(
                    domain: "CloudKitManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create CKRecipe from saved record"]
                )
                DispatchQueue.main.async {
                    completion(.failure(err))
                }
                return
            }
            DispatchQueue.main.async {
                completion(.success(recipe))
            }
        }
    }

    // Update an existing recipe
    func updateRecipe(
        _ recipe: CKRecipe,
        completion: @escaping (Result<CKRecipe, Error>) -> Void
    ) {
        let recordID = recipe.id
        publicDB.fetch(withRecordID: recordID) { record, error in
            if let error = error {
                print("CloudKit fetch for updateRecipe error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }

            guard let record = record else {
                let err = NSError(
                    domain: "CloudKitManager",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Record not found for update"]
                )
                DispatchQueue.main.async {
                    completion(.failure(err))
                }
                return
            }

            record["name"] = recipe.name as CKRecordValue
            record["ingredients"] = recipe.ingredients as CKRecordValue
            record["instructions"] = recipe.instructions as CKRecordValue
            record["isViewable"] = NSNumber(value: recipe.isViewable)

            self.publicDB.save(record) { savedRecord, error in
                if let error = error {
                    print("CloudKit updateRecipe save error: \(error)")
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                    return
                }
                guard let savedRecord = savedRecord, let updated = CKRecipe(record: savedRecord) else {
                    let err = NSError(
                        domain: "CloudKitManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create CKRecipe from updated record"]
                    )
                    DispatchQueue.main.async {
                        completion(.failure(err))
                    }
                    return
                }
                DispatchQueue.main.async {
                    completion(.success(updated))
                }
            }
        }
    }

    // Delete a recipe
    func deleteRecipe(
        _ recipe: CKRecipe,
        completion: @escaping (Bool) -> Void
    ) {
        publicDB.delete(withRecordID: recipe.id) { _, error in
            if let error = error {
                print("CloudKit deleteRecipe error: \(error)")
                DispatchQueue.main.async {
                    completion(false)
                }
            } else {
                DispatchQueue.main.async {
                    completion(true)
                }
            }
        }
    }
    
    func fetchRecipe(recordName: String, completion: @escaping (CKRecipe?) -> Void) {
            let recordID = CKRecord.ID(recordName: recordName)
            publicDB.fetch(withRecordID: recordID) { record, error in
                if let error = error {
                    print("CloudKit fetchRecipe error: \(error)")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                if let record, let recipe = CKRecipe(record: record) {
                    DispatchQueue.main.async { completion(recipe) }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            }
        }
}
