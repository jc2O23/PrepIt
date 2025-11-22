import SwiftUI
import CloudKit

private extension Date {
    func roundedToMinute() -> Date {
        let interval = floor(self.timeIntervalSinceReferenceDate / 60.0) * 60.0
        return Date(timeIntervalSinceReferenceDate: interval)
    }
}

// MARK: - Prep Item Record (copied here to ensure scope)
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

// MARK: - Grouping key for submissions
private struct PrepGroupKey: Hashable {
    let stationName: String
    let date: Date
}

// MARK: - Grouping structure for submissions
struct SubmittedPrepGroup: Identifiable, Hashable {
    let id: String // stationName + rounded date timeInterval for stability
    let stationName: String
    let date: Date
    let items: [SubmittedPrepItemRecord]
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Main View
struct CompletedPrepListsView: View {
    @State private var prepItems: [SubmittedPrepItemRecord] = []
    @State private var groups: [SubmittedPrepGroup] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var selectedGroupID: String? = nil
    @State private var hasLoaded: Bool = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .navigationTitle("Completed Prep Lists")
            } else if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .navigationTitle("Completed Prep Lists")
            } else {
                if groups.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("No completed prep lists yet")
                            .font(.headline)
                        Text("When prep lists are completed, they'll appear here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Completed Prep Lists")
                } else {
                    List {
                        // Group groups by calendar day (year, month, day)
                        let calendar = Calendar.current
                        let dayBuckets = Dictionary(grouping: groups) { (g: SubmittedPrepGroup) -> Date in
                            calendar.startOfDay(for: g.date)
                        }
                        // Sort days descending (most recent first)
                        let sortedDays: [Date] = dayBuckets.keys.sorted(by: >)
                        ForEach(sortedDays, id: \.self) { day in
                            Section(header: Text(day.formatted(date: .abbreviated, time: .omitted))) {
                                let dayGroups = (dayBuckets[day] ?? []).sorted { (lhs: SubmittedPrepGroup, rhs: SubmittedPrepGroup) in lhs.date > rhs.date }
                                ForEach(dayGroups, id: \.id) { group in
                                    NavigationLink {
                                        PrepSubmissionDetailView(group: group)
                                            .onAppear {
                                                #if DEBUG
                                                print("Navigated to:", group.stationName, group.date, "items:", group.items.count)
                                                #endif
                                            }
                                    } label: {
                                        VStack(alignment: .leading) {
                                            Text(group.stationName)
                                                .font(.headline)
                                            Text(group.formattedDate)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Completed Prep Lists")
                }
            }
        }
        .task {
            guard !hasLoaded else { return }
            hasLoaded = true
            isLoading = true
            fetchSubmittedPrepItems { results in
                let grouped = Dictionary(grouping: results) { item in
                    PrepGroupKey(stationName: item.stationName, date: item.date.roundedToMinute())
                }
                let groupArray: [SubmittedPrepGroup] = grouped.map { (key: PrepGroupKey, items: [SubmittedPrepItemRecord]) in
                    let stableID = "\(key.stationName)|\(key.date.timeIntervalSinceReferenceDate)"
                    let sortedItems: [SubmittedPrepItemRecord] = items.sorted { (a: SubmittedPrepItemRecord, b: SubmittedPrepItemRecord) in a.id < b.id }
                    return SubmittedPrepGroup(
                        id: stableID,
                        stationName: key.stationName,
                        date: key.date,
                        items: sortedItems
                    )
                }
                .sorted { (lhs: SubmittedPrepGroup, rhs: SubmittedPrepGroup) in lhs.date > rhs.date }

                self.prepItems = results
                if self.groups != groupArray {
                    self.groups = groupArray
                }
                self.isLoading = false
                self.errorMessage = nil
            }
        }
    }

    // MARK: - Fetch Submitted Prep Items
    func fetchSubmittedPrepItems(completion: @escaping ([SubmittedPrepItemRecord]) -> Void) {
        let query = CKQuery(recordType: "SubmittedPrepItem", predicate: NSPredicate(value: true))
        var results: [SubmittedPrepItemRecord] = []
        let op = CKQueryOperation(query: query)
        op.desiredKeys = ["prepName", "parLabel", "parAmount", "prepComplete", "userSubmit", "notes", "date", "stationName"]
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
                let rec = SubmittedPrepItemRecord(id: recordID.recordName, prepName: prepName, parLabel: parLabel, parAmount: parAmount, prepComplete: prepComplete, userSubmit: userSubmit, notes: notes, date: date, stationName: stationName)
                results.append(rec)
            case .failure(let error):
                print("CloudKit fetchSubmittedPrepItems error: \(error)")
            }
        }
        op.queryResultBlock = { _ in
            DispatchQueue.main.async { completion(results) }
        }
        CKContainer(identifier: "iCloud.campbell.PrepItKitchen").publicCloudDatabase.add(op)
    }
}

// MARK: - Detail View
struct PrepSubmissionDetailView: View {
    let group: SubmittedPrepGroup

    var body: some View {
        List {
            Section(header: Text("Station")) {
                Text(group.stationName)
            }
            Section(header: Text("Submission Time")) {
                Text(group.formattedDate)
            }
            Section(header: Text("Submitted By")) {
                let submitter = group.items.first?.userSubmit ?? ""
                Text(submitter.isEmpty ? "—" : submitter)
                    .foregroundStyle(.secondary)
            }
            Section(header: Text("Completed Prep Items")) {
                ForEach(group.items, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.prepName)
                            .font(.headline)
                        if !item.parLabel.isEmpty || !item.parAmount.isEmpty {
                            Text("\(item.parLabel) \(item.parAmount)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Text("Completed: \(item.prepComplete)")
                            .font(.caption)
                        if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Notes: \(item.notes)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("\(group.stationName) Submission")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            #if DEBUG
            print("Detail disappeared for:", group.stationName, group.date)
            #endif
        }
    }
}

private struct TestingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(.green)
            Text("Testing Destination")
                .font(.title2)
                .bold()
            Text("If you can see this, navigation works and the pop is caused by data/state changes in the destination.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Testing")
        .navigationBarTitleDisplayMode(.inline)
    }
}
