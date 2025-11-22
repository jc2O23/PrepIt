import Foundation


public struct ServiceFetch {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    private func makeURL(_ pathComponent: String) -> URL {
        baseURL.appendingPathComponent(pathComponent)
    }
    
    private func fetch<T: Decodable>(_ pathComponent: String) async throws -> T {
        let url = makeURL(pathComponent)

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    public func fetchMenuItems() async throws -> [MenuItem] {
        try await fetch("menu_items")
    }

    public func fetchMenus() async throws -> [ResMenu] {
        try await fetch("menu")
    }

    public func fetchEmployees() async throws -> [Employee] {
        try await fetch("employees")
    }
}

