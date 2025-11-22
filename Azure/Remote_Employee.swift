import Foundation

public struct Employee: Identifiable, Codable, Hashable {
    public let id: Int
    public let firstName: String
    public let lastName: String
    public let displayName: String
    public let pinNum: Int
    public let pinCode: Int
    public let accessLevel: Int
    public let role: String

    enum CodingKeys: String, CodingKey {
        case id = "employee_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case displayName = "display_name"
        case pinNum = "pin_num"
        case pinCode = "pin_code"
        case accessLevel = "access_level"
        case role
    }
}
