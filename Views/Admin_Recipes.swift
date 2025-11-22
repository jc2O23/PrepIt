import SwiftUI
import CloudKit

// MARK: - Admin Recipes Main View

struct PrepRecipeAdminView: View {
    @State private var recipes: [CKRecipe] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showingAddSheet: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && recipes.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView("Loading Recipes…")

                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, recipes.isEmpty {
                    VStack(spacing: 12) {
                        Text("Error Loading Recipes")
                            .font(.title3)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") {
                            Task { await loadRecipes() }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recipes.isEmpty {
                    VStack(spacing: 12) {
                        Text("No Recipes Yet")
                            .font(.title3)
                        Text("Tap the + button to add your first recipe.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(recipes) { recipe in
                            NavigationLink {
                                AdminRecipeDetailView(
                                    recipe: recipe,
                                    onUpdated: { updated in
                                        if let idx = recipes.firstIndex(where: { $0.id == updated.id }) {
                                            recipes[idx] = updated
                                        }
                                    },
                                    onDeleted: { deleted in
                                        recipes.removeAll { $0.id == deleted.id }
                                    }
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(recipe.name)
                                        .font(.headline)
                                    if !recipe.ingredients.isEmpty {
                                        Text(recipe.ingredients)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteAt)
                    }
                    .refreshable {
                        await loadRecipes()
                    }
                }
            }
            .navigationTitle("Manage Recipes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddRecipeSheet { newRecipe in
                    recipes.append(newRecipe)
                    recipes.sort {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                }
            }
            .task {
                await loadRecipes()
            }
        }
    }

    // MARK: - CloudKit load

    private func loadRecipes() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        let fetched: [CKRecipe] = await withCheckedContinuation { continuation in
            CloudKitManager.shared.fetchRecipes { items in
                continuation.resume(returning: items)
            }
        }

        await MainActor.run {
            self.recipes = fetched.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            self.isLoading = false
        }
    }

    // MARK: - Delete via swipe

    private func deleteAt(_ offsets: IndexSet) {
        let items = offsets.map { recipes[$0] }

        for recipe in items {
            CloudKitManager.shared.deleteRecipe(recipe) { success in
                DispatchQueue.main.async {
                    if success {
                        self.recipes.removeAll { $0.id == recipe.id }
                    } else {
                        self.errorMessage = "Could not delete recipe from iCloud."
                    }
                }
            }
        }
    }
}

// MARK: - Add Recipe Sheet

struct AddRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var ingredients: String = ""
    @State private var instructions: String = ""
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    /// Called when a recipe is successfully created in CloudKit.
    let onAdded: (CKRecipe) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("New Recipe") {
                    TextField("Name", text: $name)

                    VStack(alignment: .leading) {
                        Text("Ingredients")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $ingredients)
                            .frame(minHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3))
                            )
                    }

                    VStack(alignment: .leading) {
                        Text("Instructions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $instructions)
                            .frame(minHeight: 160)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3))
                            )
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Add Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(
                        isSaving ||
                        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        CloudKitManager.shared.addRecipe(
            name: trimmedName,
            ingredients: ingredients,
            instructions: instructions
        ) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success(let recipe):
                    self.onAdded(recipe)
                    self.dismiss()
                case .failure(let error):
                    self.errorMessage = "Could not save recipe: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Admin Recipe Detail View (Edit / Delete)

struct AdminRecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var recipe: CKRecipe
    @State private var isSaving: Bool = false
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String?
    @State private var showDeleteAlert: Bool = false

    let onUpdated: (CKRecipe) -> Void
    let onDeleted: (CKRecipe) -> Void

    init(
        recipe: CKRecipe,
        onUpdated: @escaping (CKRecipe) -> Void,
        onDeleted: @escaping (CKRecipe) -> Void
    ) {
        _recipe = State(initialValue: recipe)
        self.onUpdated = onUpdated
        self.onDeleted = onDeleted
    }

    var body: some View {
        Form {
            Section("Recipe Info") {
                TextField("Name", text: $recipe.name)

                VStack(alignment: .leading) {
                    Text("Ingredients")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $recipe.ingredients)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                }

                VStack(alignment: .leading) {
                    Text("Instructions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $recipe.instructions)
                        .frame(minHeight: 160)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Text("Delete Recipe")
                    }
                }
            }
        }
        .navigationTitle("Edit Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    save()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(
                    recipe.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    isSaving ||
                    isDeleting
                )
            }
        }
        .alert("Delete Recipe?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                delete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently remove \"\(recipe.name)\" from iCloud.")
        }
    }

    // MARK: - Actions

    private func save() {
        isSaving = true
        errorMessage = nil

        CloudKitManager.shared.updateRecipe(recipe) { result in
            DispatchQueue.main.async {
                self.isSaving = false
                switch result {
                case .success(let updated):
                    self.onUpdated(updated)
                    self.dismiss()
                case .failure(let error):
                    self.errorMessage = "Could not update recipe: \(error.localizedDescription)"
                }
            }
        }
    }

    private func delete() {
        isDeleting = true
        errorMessage = nil

        CloudKitManager.shared.deleteRecipe(recipe) { success in
            DispatchQueue.main.async {
                self.isDeleting = false
                if success {
                    self.onDeleted(self.recipe)
                    self.dismiss()
                } else {
                    self.errorMessage = "Could not delete recipe from iCloud."
                }
            }
        }
    }
}
