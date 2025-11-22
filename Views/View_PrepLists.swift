import SwiftUI
import CloudKit

struct StationDetailView: View {
    let stationName: String

    @EnvironmentObject var session: SessionViewModel
    @State private var items: [CloudItem] = []
    @State private var isLoading: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var submitMessage: String?

    // Use this for the More Info sheet instead of Bool + String
    @State private var infoItem: CloudItem?
    @State private var recipeForSheet: CKRecipe?

    struct CloudItem: Identifiable, Equatable {
        let id: String // CKRecord.ID.recordName
        let title: String
        let parAmount: String
        let parLabel: String
        let isViewable: Bool
        var currentValue: String
        var notes: String
        let owner: String
        let moreInfo: String
        let createdAt: Date
        let recipeRecordName: String?
    }

    var body: some View {
        List {
            Section("Prep Sheet") {
                if isLoading {
                    ProgressView("Loading…")
                } else {
                    let visible = items
                        .filter { $0.isViewable }
                        .sorted { $0.createdAt < $1.createdAt }

                    if visible.isEmpty {
                        ContentUnavailableView(
                            "No prep items",
                            systemImage: "list.bullet.rectangle",
                            description: Text("No items configured for this station.")
                        )
                    } else {
                        ForEach(visible) { item in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.system(size: 32))

                                    if !(item.parAmount.isEmpty && item.parLabel.isEmpty) {
                                        let combined = [item.parLabel, item.parAmount]
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " | ")
                                        Text(combined)
                                            .font(.system(size: 18))
                                            .foregroundStyle(.secondary)
                                    }

                                    if !item.moreInfo
                                        .trimmingCharacters(in: .whitespacesAndNewlines)
                                        .isEmpty {
                                        Button {
                                            // Directly set the item to show
                                            infoItem = item
                                        } label: {
                                            Label("More Info", systemImage: "info.circle")
                                                .font(.subheadline)
                                        }
                                        .buttonStyle(.borderless)
                                        .padding(.top, 2)
                                    }
                                    if let recipeRecordName = item.recipeRecordName,
                                       !recipeRecordName.isEmpty {
                                        Button {
                                            loadRecipe(recordName: recipeRecordName)
                                        } label: {
                                            Label("Show Recipe", systemImage: "book")
                                                .font(.subheadline)
                                        }
                                        .buttonStyle(.borderless)
                                        .padding(.top, 2)
                                    }

                                    TextField("", text: bindingForCurrentValue(of: item))
                                        .textFieldStyle(.roundedBorder)

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Notes (optional)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        TextEditor(text: bindingForNotes(of: item))
                                            .frame(minHeight: 60)
                                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }

                        if !isLoading && !visible.isEmpty {
                            Button(action: submitPrepSheet) {
                                if isSubmitting {
                                    ProgressView()
                                } else {
                                    Label("Submit Prep Sheet", systemImage: "tray.and.arrow.up")
                                }
                            }
                            .disabled(isSubmitting)
                        }
                    }
                }
            }
        }
        .navigationTitle(stationName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadItems() }
        .refreshable { await loadItems() }
        // Sheet driven by the selected item instead of a Bool
        .sheet(item: $infoItem) { item in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Details")
                            .font(.largeTitle.bold())
                        Text(item.moreInfo)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            infoItem = nil
                        }
                    }
                }
            }
        }
        .sheet(item: $recipeForSheet) { recipe in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(recipe.name)
                            .font(.largeTitle)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Ingredients")
                                .font(.headline)
                            Text(recipe.ingredients)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instructions")
                                .font(.headline)
                            Text(recipe.instructions)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }

                        Spacer()
                    }
                    .padding()
                }
                .navigationTitle("Recipe")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            recipeForSheet = nil
                        }
                    }
                }
            }
        }
        .overlay {
            if let msg = submitMessage {
                VStack {
                    Spacer()
                    Text(msg)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    Spacer()
                }
                .transition(.opacity)
            }
        }
    }

    private func bindingForCurrentValue(of item: CloudItem) -> Binding<String> {
        Binding<String>(
            get: {
                items.first(where: { $0.id == item.id })?.currentValue ?? ""
            },
            set: { newValue in
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx].currentValue = newValue
                }
            }
        )
    }

    private func bindingForNotes(of item: CloudItem) -> Binding<String> {
        Binding<String>(
            get: {
                items.first(where: { $0.id == item.id })?.notes ?? ""
            },
            set: { newValue in
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx].notes = newValue
                }
            }
        )
    }

    private func loadItems() async {
        await MainActor.run { isLoading = true }

        await withCheckedContinuation { cont in
            CloudKitManager.shared.fetchPrepItemLists(for: stationName) { records in
                Task { @MainActor in
                    self.items = records.map { r in
                        CloudItem(
                            id: r.recordID.recordName,
                            title: r.title,
                            parAmount: r.parAmount,
                            parLabel: r.parLabel,
                            isViewable: r.isViewable,
                            currentValue: r.currentValue,
                            notes: "",
                            owner: r.owner,
                            moreInfo: r.moreInfo,
                            createdAt: r.createdAt,
                            recipeRecordName: r.recipeRecordName
                        )
                    }
                    self.isLoading = false
                    cont.resume()
                }
            }
        }
    }

    private func submitPrepSheet() {
        guard let displayName = session.currentUser?.displayName, !displayName.isEmpty else {
            submitMessage = "Could not determine user. Please sign in."
            return
        }
        isSubmitting = true
        submitMessage = nil
        let visibleItems = items.filter { $0.isViewable }
        let dateNow = Date()
        let group = DispatchGroup()
        var submitErrors: [String] = []
        for item in visibleItems {
            group.enter()
            CloudKitManager.shared.saveSubmittedPrepItem(
                prepName: item.title,
                parLabel: item.parLabel,
                parAmount: item.parAmount,
                prepComplete: item.currentValue,
                userSubmit: displayName,
                date: dateNow,
                stationName: stationName,
                notes: item.notes
            ) { result in
                if case .failure(let error) = result {
                    submitErrors.append("\(item.title): \(error.localizedDescription)")
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            isSubmitting = false
            if submitErrors.isEmpty {
                submitMessage = "Prep sheet submitted!"
            } else {
                submitMessage = "Some errors: " + submitErrors.joined(separator: ", ")
            }
        }
    }

    private func loadRecipe(recordName: String) {
        CloudKitManager.shared.fetchRecipe(recordName: recordName) { recipe in
            if let recipe {
                self.recipeForSheet = recipe
            } else {
                // Reuse submitMessage overlay to show an error if desired
                self.submitMessage = "Could not load recipe."
            }
        }
    }
}

extension CloudKitManager {
    func saveSubmittedPrepItem(
        prepName: String,
        parLabel: String,
        parAmount: String,
        prepComplete: String,
        userSubmit: String,
        date: Date,
        stationName: String,
        notes: String,
        completion: @escaping (Result<CKRecord.ID, Error>) -> Void
    ) {
        let record = CKRecord(recordType: "SubmittedPrepItem")
        record["prepName"] = prepName as CKRecordValue
        record["parLabel"] = parLabel as CKRecordValue
        record["parAmount"] = parAmount as CKRecordValue
        record["prepComplete"] = prepComplete as CKRecordValue
        record["userSubmit"] = userSubmit as CKRecordValue
        record["date"] = date as CKRecordValue
        record["stationName"] = stationName as CKRecordValue
        record["notes"] = notes as CKRecordValue
        CloudKitManager.shared.publicDB.save(record) { savedRecord, error in
            if let error = error {
                completion(.failure(error))
            } else if let savedRecord = savedRecord {
                completion(.success(savedRecord.recordID))
            } else {
                let unknownError = NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown save SubmittedPrepItem result"])
                completion(.failure(unknownError))
            }
        }
    }
}
