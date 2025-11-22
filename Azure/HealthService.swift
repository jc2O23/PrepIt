import Foundation

struct HealthService {
    let baseURL: URL

    func isServerOnline() async -> Bool {
        var request = URLRequest(url: baseURL)
        request.timeoutInterval = 5 // seconds
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return false
            }
            // Try to validate expected JSON message, but treat any 2xx as online if parsing fails
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                return message.contains("PrepIt API is connected")
            }
            return true
        } catch {
            return false
        }
    }
}
