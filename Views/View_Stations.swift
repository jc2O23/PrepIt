import SwiftUI

struct ViewStationsView: View {
    @State private var stations: [String] = []
    @State private var isLoading: Bool = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading Stations…")
                } else if stations.isEmpty {
                    ContentUnavailableView(
                        "Station List",
                        systemImage: "rectangle.stack.slash",
                        description: Text("No stations found.")
                    )
                } else {
                    List(stations, id: \ .self) { name in
                        NavigationLink {
                            StationDetailView(stationName: name)
                        } label: {
                            Text(name)
                                .font(.title.weight(.light))
                                .padding(.vertical, 3)
                        }
                    }
                }
            }
            .navigationTitle(Text("Stations"))
            .task { await loadStations() }
            .refreshable { await loadStations() }
        }
    }

    private func loadStations() async {
        isLoading = true
        await withCheckedContinuation { cont in
            CloudKitManager.shared.fetchStations { names in
                self.stations = names.sorted()
                self.isLoading = false
                cont.resume()
            }
        }
    }
}
