import SwiftUI
import CloudKit

struct StationPrepEditorView: View {
    let stationName: String

    @State private var items: [CloudItem] = []
    @State private var isLoading: Bool = true
    @State private var pendingDelete: IndexSet? = nil
    @State private var showDeleteConfirm: Bool = false

    struct CloudItem: Identifiable, Equatable {
        let id: String // CKRecord.ID.recordName
        var title: String
        var parAmount: String
        var parLabel: String
        var isViewable: Bool
        var moreInfo: String
        var createdAt: Date
    }

    var body: some View {
        List {
            Section("Prep Items") {
                if isLoading {
                    ProgressView("Loading…")
                } else if items.isEmpty {
                    ContentUnavailableView("No prep items", systemImage: "list.bullet.rectangle", description: Text("Add tasks for this station."))
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Title", text: binding(for: item, keyPath: \ .title))
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { update(item) }

                            HStack(spacing: 8) {
                                Text("Par amount:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("Amount", text: binding(for: item, keyPath: \ .parAmount))
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { update(item) }

                                Text("Label:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("e.g., pans, flats", text: binding(for: item, keyPath: \ .parLabel))
                                    .textFieldStyle(.roundedBorder)
                                    .onSubmit { update(item) }
                            }

                            Toggle(isOn: binding(for: item, keyPath: \ .isViewable)) {
                                Text("Viewable")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tint(.accentColor)
                            .onChange(of: binding(for: item, keyPath: \ .isViewable).wrappedValue) {
                                update(item)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("More info")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextEditor(text: binding(for: item, keyPath: \ .moreInfo))
                                    .frame(minHeight: 60)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
                                    .onSubmit { update(item) }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        pendingDelete = indexSet
                        showDeleteConfirm = true
                    }
                    .onMove { indices, newOffset in
                        var working = items
                        working.move(fromOffsets: indices, toOffset: newOffset)
                        items = working
                        // Order is not persisted in CloudKit here; add a field if needed.
                    }
                }
            }

            Section("Add Prep Item") {
                AddPrepItemEditorRow(stationName: stationName) {
                    await loadItems()
                }
            }
        }
        .navigationTitle("Edit \(stationName)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadItems() }
        .alert("Delete prep item(s)?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Data
    private func loadItems() async {
        isLoading = true
        await withCheckedContinuation { cont in
            CloudKitManager.shared.fetchPrepItemLists(for: stationName) { records in
                Task { @MainActor in
                    self.items = records
                        .sorted { $0.createdAt < $1.createdAt }
                        .map { r in
                            CloudItem(
                                id: r.recordID.recordName,
                                title: r.title,
                                parAmount: r.parAmount,
                                parLabel: r.parLabel,
                                isViewable: r.isViewable,
                                moreInfo: r.moreInfo,
                                createdAt: r.createdAt
                            )
                        }
                    self.isLoading = false
                    cont.resume()
                }
            }
        }
    }

    private func update(_ item: CloudItem) {
        CloudKitManager.shared.updatePrepItemList(
            recordName: item.id,
            title: item.title,
            parAmount: item.parAmount,
            parLabel: item.parLabel,
            isViewable: item.isViewable,
            moreInfo: item.moreInfo
        ) { result in
            if case .failure(let error) = result { print("Update error: \(error)") }
        }
    }

    private func deleteSelected() {
        guard let indexSet = pendingDelete else { return }
        let toDelete = indexSet.compactMap { idx in idx < items.count ? items[idx] : nil }
        let group = DispatchGroup()
        for item in toDelete {
            group.enter()
            CloudKitManager.shared.deletePrepItemList(recordName: item.id) { _ in group.leave() }
        }
        group.notify(queue: .main) {
            Task { await loadItems() }
        }
        pendingDelete = nil
    }

    // MARK: - Bindings helper
    private func binding<T>(for item: CloudItem, keyPath: WritableKeyPath<CloudItem, T>) -> Binding<T> {
        Binding<T>(
            get: {
                items.first(where: { $0.id == item.id })?[keyPath: keyPath] as T? ?? (CloudItem(id: "", title: "", parAmount: "", parLabel: "", isViewable: true, moreInfo: "", createdAt: Date())[keyPath: keyPath])
            },
            set: { newValue in
                if let idx = items.firstIndex(where: { $0.id == item.id }) {
                    items[idx][keyPath: keyPath] = newValue
                }
            }
        )
    }
}

private struct AddPrepItemEditorRow: View {
    let stationName: String
    var onAdded: () async -> Void

    @State private var title: String = ""
    @State private var parAmount: String = ""
    @State private var parLabel: String = ""
    @State private var moreInfo: String = ""
    @State private var selectedRecipeRecordName: String? = nil

    @State private var recipes: [CKRecipe] = []
    @State private var isLoadingRecipes: Bool = false
    @State private var recipeLoadError: String?

    @State private var showValidationError: Bool = false
    @State private var validationMessage: String = ""

    @FocusState private var focusedField: Field?
    private enum Field: Hashable {
        case title
        case parLabel
        case parAmount
        case moreInfo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Title
            TextField("Task name", text: $title)
                .focused($focusedField, equals: .title)

            // Par label
            TextField("Par label", text: $parLabel)
                .focused($focusedField, equals: .parLabel)

            // Par amount
            TextField("Par amount", text: $parAmount)
                .focused($focusedField, equals: .parAmount)

            // More info
            VStack(alignment: .leading, spacing: 6) {
                Text("More info (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $moreInfo)
                    .focused($focusedField, equals: .moreInfo)
                    .frame(minHeight: 60)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
            }

            // Recipe Picker
            Section {
                if isLoadingRecipes {
                    HStack {
                        Text("Recipe")
                        Spacer()
                        ProgressView()
                    }
                } else if let recipeLoadError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recipe")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Error loading recipes: \(recipeLoadError)")
                            .foregroundStyle(.red)
                            .font(.caption2)
                        Button("Retry") {
                            Task { await loadRecipes() }
                        }
                        .font(.caption)
                    }
                } else {
                    Picker("Recipe (optional)", selection: Binding(
                        get: {
                            selectedRecipeRecordName ?? ""
                        },
                        set: { newValue in
                            selectedRecipeRecordName = newValue.isEmpty ? nil : newValue
                        }
                    )) {
                        Text("None").tag("")

                        ForEach(recipes) { recipe in
                            Text(recipe.name)
                                .tag(recipe.id.recordName)
                        }
                    }
                }
            }

            // Add button (Option 2: more spacing, clearer tap target)
            VStack {
                Button {
                    addItem()
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
        .alert("Cannot Add Item", isPresented: $showValidationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .task {
            await loadRecipes()
        }
    }

    // MARK: - Add Item

    private func addItem() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        CloudKitManager.shared.savePrepItemList(
            title: cleanTitle,
            parAmount: parAmount,
            parLabel: parLabel,
            isViewable: true,
            currentValue: "",
            owner: "",
            moreInfo: moreInfo,
            stationName: stationName,
            recipeRecordName: selectedRecipeRecordName        // <- NEW
        ) { result in
            switch result {
            case .success:
                focusedField = nil
                Task { await onAdded() }
                title = ""; parAmount = ""; parLabel = ""; moreInfo = ""
                selectedRecipeRecordName = nil
            case .failure(let error):
                validationMessage = "Failed to add item: \(error.localizedDescription)"
                showValidationError = true
            }
        }
    }

    // MARK: - Load Recipes

    private func loadRecipes() async {
        await MainActor.run {
            isLoadingRecipes = true
            recipeLoadError = nil
        }

        let fetched: [CKRecipe] = await withCheckedContinuation { continuation in
            CloudKitManager.shared.fetchRecipes { items in
                continuation.resume(returning: items)
            }
        }

        await MainActor.run {
            self.isLoadingRecipes = false
            if fetched.isEmpty {
                self.recipes = []
            } else {
                self.recipes = fetched.sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
            }
        }
    }
}
struct RecipePickerField: View {
    @Binding var selectedRecipeRecordName: String?   // nil = no recipe

    @State private var recipes: [CKRecipe] = []
    @State private var isLoading: Bool = false
    @State private var loadError: String?

    var body: some View {
        Section("Attach Recipe (Optional)") {
            if isLoading {
                HStack {
                    Text("Recipe")
                    Spacer()
                    ProgressView()
                }
            } else if let loadError {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recipe")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Could not load recipes: \(loadError)")
                        .font(.caption2)
                        .foregroundStyle(.red)
                    Button("Retry") {
                        Task { await loadRecipes() }
                    }
                    .font(.caption)
                }
            } else {
                Picker("Recipe", selection: Binding(
                    get: {
                        selectedRecipeRecordName ?? ""
                    },
                    set: { newValue in
                        selectedRecipeRecordName =
                            newValue.isEmpty ? nil : newValue
                    }
                )) {
                    Text("None").tag("")

                    ForEach(recipes) { recipe in
                        Text(recipe.name)
                            .tag(recipe.id.recordName)
                    }
                }
            }
        }
        .task {
            await loadRecipes()
        }
    }

    private func loadRecipes() async {
        await MainActor.run {
            isLoading = true
            loadError = nil
        }

        let fetched: [CKRecipe] = await withCheckedContinuation { cont in
            CloudKitManager.shared.fetchRecipes { items in
                cont.resume(returning: items)
            }
        }

        await MainActor.run {
            self.recipes = fetched.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            self.isLoading = false
        }
    }
}
