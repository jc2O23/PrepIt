import SwiftUI
import CloudKit

struct DiagnosticsView: View {

    // MARK: - CloudKit container

    private var containerID: String {
        // Match the identifier used by your app
        "iCloud.campbell.PrepItKitchen"
    }

    private var ckContainer: CKContainer { CKContainer(identifier: containerID) }

    // MARK: - Cloud-driven counts

    @State private var stationCount: Int = 0
    @State private var prepListCount: Int = 0          // number of PrepItemList records
    @State private var recipeCount: Int = 0            // number of Recipe records
    @State private var submittedPrepCount: Int = 0     // number of SubmittedPrepItem records
    @State private var userCount: Int = 0

    @State private var publicDBStatus: String = "Checking…"
    @State private var isLoadingCounts: Bool = false

    var body: some View {
        List {
            Section("CloudKit Counts") {
                if isLoadingCounts {
                    LabeledContent("Stations") {
                        ProgressView()
                    }
                    LabeledContent("Prep Lists") {
                        ProgressView()
                    }
                    LabeledContent("Recipes") {
                        ProgressView()
                    }
                    LabeledContent("Submitted Prep Items") {
                        ProgressView()
                    }
                    LabeledContent("Total Users") {
                        ProgressView()
                    }
                } else {
                    LabeledContent("Stations", value: "\(stationCount)")
                    LabeledContent("Prep Lists", value: "\(prepListCount)")
                    LabeledContent("Recipes", value: "\(recipeCount)")
                    LabeledContent("Submitted Prep Items", value: "\(submittedPrepCount)")
                    LabeledContent("Total Users", value: "\(userCount)")
                }
            }

            Section("CloudKit") {
                LabeledContent("Container", value: containerID)
                LabeledContent("Database", value: "Public")
                LabeledContent("Account Status", value: publicDBStatus)
            }
        }
        .navigationTitle("Diagnostics")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task { await refresh() }
    }

    // MARK: - Refresh

    private func refresh() async {
        // Run status + counts in parallel and await both.
        async let statusTask: Void = checkStatus()
        async let countTask: Void = loadCountsFromCloud()
        _ = await (statusTask, countTask)
    }

    // MARK: - CloudKit status

    @MainActor
    private func checkStatus() async {
        do {
            let status = try await ckContainer.accountStatus()
            switch status {
            case .available: publicDBStatus = "Available"
            case .couldNotDetermine: publicDBStatus = "Unknown"
            case .restricted: publicDBStatus = "Restricted"
            case .noAccount: publicDBStatus = "No iCloud Account"
            case .temporarilyUnavailable: publicDBStatus = "Temporarily Unavailable"
            @unknown default: publicDBStatus = "Unknown"
            }
        } catch {
            publicDBStatus = "Error: \(error.localizedDescription)"
        }
    }

    // MARK: - CloudKit counts

    private func loadCountsFromCloud() async {
        await MainActor.run { isLoadingCounts = true }

        // Use generic async count helper for each record type
        async let stations   = fetchCountAsync(for: "Station")
        async let prepLists  = fetchCountAsync(for: "PrepItemList")
        async let recipes    = fetchCountAsync(for: "Recipe")
        async let submitted  = fetchCountAsync(for: "SubmittedPrepItem")
        async let users      = fetchCountAsync(for: "User")

        let (stationTotal, prepTotal, recipeTotal, submittedTotal, userTotal) =
            await (stations, prepLists, recipes, submitted, users)

        await MainActor.run {
            stationCount        = stationTotal
            prepListCount       = prepTotal
            recipeCount         = recipeTotal
            submittedPrepCount  = submittedTotal
            userCount           = userTotal
            isLoadingCounts     = false
        }
    }

    // MARK: - CloudKit bridge helper

    /// Async wrapper around CloudKitManager.shared.countRecords(...)
    private func fetchCountAsync(for recordType: String) async -> Int {
        await withCheckedContinuation { (cont: CheckedContinuation<Int, Never>) in
            CloudKitManager.shared.countRecords(recordType: recordType) { count in
                cont.resume(returning: count)
            }
        }
    }
}

extension CloudKitManager {
    // MARK: - Generic Record Count Function (Public DB)

    /// Counts records for any given recordType in the public database.
    /// - Parameters:
    ///   - recordType: The CloudKit record type name, e.g. "Station", "PrepItemList".
    ///   - predicate: Optional predicate to filter records. Defaults to "true" (all records).
    ///   - completion: Called on completion with the count of records.
    func countRecords(
        recordType: String,
        predicate: NSPredicate = NSPredicate(value: true),
        completion: @escaping (Int) -> Void
    ) {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        var count = 0

        func run(_ cursor: CKQueryOperation.Cursor?) {
            let op: CKQueryOperation =
                cursor.map(CKQueryOperation.init(cursor:)) ??
                CKQueryOperation(query: query)

            // We only care about counting, not field data.
            op.desiredKeys = []
            op.resultsLimit = CKQueryOperation.maximumResults

            op.recordMatchedBlock = { _, result in
                if case .success = result {
                    count += 1
                }
            }

            op.queryResultBlock = { result in
                switch result {
                case .success(let nextCursor):
                    if let next = nextCursor {
                        run(next)
                    } else {
                        completion(count)
                    }
                case .failure(let error):
                    print("CloudKit countRecords error for \(recordType): \(error)")
                    completion(count) // return whatever we counted so far
                }
            }

            self.publicDB.add(op)
        }

        run(nil)
    }
}
