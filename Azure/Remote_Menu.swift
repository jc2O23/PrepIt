import Foundation

public struct ResMenu: Codable, Identifiable {
    public let id: Int
    public let menuName: String
    public let menuStartTime: String
    public let menuEndTime: String
    public let menuDays: String

    enum CodingKeys: String, CodingKey {
        case id = "menu_id"
        case menuName = "menu_name"
        case menuStartTime = "menu_start_time"
        case menuEndTime = "menu_end_time"
        case menuDays = "menu_days"
    }
}
