import SwiftUI
import CloudKit

struct ViewRecipesView: View {
    @State private var recipes: [CKRecipe] = []
    @State private var isLoading: Bool = true
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack {
                        ProgressView("Loading Recipes…")
                            .padding()
                    }
                } else if let loadError {
                    VStack(spacing: 12) {
                        Text("Error")
                            .font(.title2)
                            .foregroundStyle(.red)
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Try Again") {
                            Task { await loadRecipes() }
                        }
                    }
                    .padding()
                } else if recipes.isEmpty {
                    VStack(spacing: 12) {
                        Text("No Recipes Found")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(recipes) { recipe in
                        NavigationLink {
                            RecipeDetailView(recipe: recipe)
                        } label: {
                            Text(recipe.name)
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("View Recipes")
            .task {
                await loadRecipes()
            }
            .refreshable {
                await loadRecipes()
            }
        }
    }

    // MARK: - CloudKit Load
    private func loadRecipes() async {
        await MainActor.run {
            isLoading = true
            loadError = nil
        }

        let result = await withCheckedContinuation { continuation in
            CloudKitManager.shared.fetchRecipes { items in
                continuation.resume(returning: items)
            }
        }

        await MainActor.run {
            // Only show recipes that are marked as viewable
            recipes = result
                .filter { $0.isViewable }    // NEW
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            isLoading = false
        }
    }
}
struct RecipeDetailView: View {
    let recipe: CKRecipe

    var body: some View {
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
        .navigationTitle("Recipe Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
