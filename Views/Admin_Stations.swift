import SwiftUI
import CloudKit

private struct CloudError: Identifiable, Equatable {
    enum Kind { case save, delete, fetch }
    let id = UUID()
    let kind: Kind
    let message: String
}

// Represents one station row: we keep both recordName (id) and display name
private struct StationRowModel: Identifiable, Hashable {
    let id: String            // CloudKit recordName
    let name: String          // stationName field
}

struct ManageStationsView: View {
    @State private var stations: [StationRowModel] = []
    @State private var isAlertShown: Bool = false
    @State private var newStation: String = ""
    @State private var isSaving: Bool = false
    @State private var isLoading: Bool = true
    @State private var cloudError: CloudError? = nil

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(Text("Manage Stations"))
                .toolbar { addToolbar }
                .alert("Add new Station", isPresented: $isAlertShown) { addStationAlertButtons } message: { addStationAlertMessage }
                .alert(item: $cloudError) { error in
                    Alert(
                        title: Text(title(for: error.kind)),
                        message: Text(error.message),
                        dismissButton: .cancel(Text("OK"))
                    )
                }
                .overlay(emptyOverlay)
                .task { await loadStations() }
                .refreshable { await loadStations() }
        }
    }

    private func title(for kind: CloudError.Kind) -> String {
        switch kind {
        case .save: return "Cloud Save Failed"
        case .delete: return "Cloud Delete Failed"
        case .fetch: return "Cloud Fetch Failed"
        }
    }
}

// MARK: - Subviews
private extension ManageStationsView {
    @ViewBuilder
    var content: some View {
        Group {
            if isLoading {
                ProgressView("Loading Stations…")
            } else {
                List {
                    ForEach(stations) { station in
                        stationRow(station)
                    }
                    .onDelete(perform: deleteAt)
                }
            }
        }
    }

    @ViewBuilder
    func stationRow(_ station: StationRowModel) -> some View {
        NavigationLink {
            StationPrepEditorView(stationName: station.name)
        } label: {
            HStack {
                Text(station.name)
                    .font(.title.weight(.light))
                Spacer(minLength: 8)
            }
            .padding(.vertical, 3)
        }
    }

    @ToolbarContentBuilder
    var addToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { isAlertShown.toggle() } label: {
                Image(systemName: "plus").imageScale(.large)
            }
            .disabled(isSaving)
        }
    }

    var emptyOverlay: some View {
        Group {
            if !isLoading && stations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.slash").font(.largeTitle)
                    Text("Station List").font(.headline)
                    Text("No stations found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
    }
}

// MARK: - Cloud
private extension ManageStationsView {
    func loadStations() async {
        isLoading = true
        await withCheckedContinuation { cont in
            // Use fetchStationRecords to get (recordName, stationName)
            CloudKitManager.shared.fetchStationRecords { pairs in
                let mapped = pairs.map { (recordName, stationName) in
                    StationRowModel(id: recordName, name: stationName)
                }
                self.stations = mapped.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                self.isLoading = false
                cont.resume()
            }
        }
    }

    func deleteAt(_ offsets: IndexSet) {
        let stationsToDelete = offsets.compactMap { idx in
            idx < stations.count ? stations[idx] : nil
        }
        guard !stationsToDelete.isEmpty else { return }

        var lastFailed = false
        let group = DispatchGroup()

        for station in stationsToDelete {
            group.enter()
            CloudKitManager.shared.deleteStation(recordName: station.id) { success in
                if !success { lastFailed = true }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if lastFailed {
                cloudError = CloudError(
                    kind: .delete,
                    message: "We couldn't delete one or more stations from iCloud."
                )
            }
            Task { await loadStations() }
        }
    }
}

// MARK: - Alert pieces
private extension ManageStationsView {
    @ViewBuilder
    var addStationAlertButtons: some View {
        TextField("Enter a new station", text: $newStation)
            .disabled(isSaving)

        Button("Save") { saveNewStation() }
            .disabled(isSaving || newStation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

        Button("Cancel", role: .cancel) {
            isAlertShown = false
            newStation = ""
        }

        if isSaving {
            ProgressView().padding(.top, 4)
        }
    }

    @ViewBuilder
    var addStationAlertMessage: some View {
        EmptyView()
    }
}

// MARK: - Actions
private extension ManageStationsView {
    func saveNewStation() {
        let name = newStation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isSaving = true

        CloudKitManager.shared.saveStation(stationName: name) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.newStation = ""
                    self.isAlertShown = false
                    self.isSaving = false
                    Task { await loadStations() }
                case .failure:
                    self.cloudError = CloudError(
                        kind: .save,
                        message: "We couldn't save your station to iCloud right now. Please try again."
                    )
                    self.isSaving = false
                }
            }
        }
    }
}
