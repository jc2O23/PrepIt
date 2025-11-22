import Foundation

public struct MenuItem: Identifiable, Codable, Hashable {
    public let id: Int
    public let name: String
    public let description: String
    public let price: Double
    public let stock: Int
    public let parentID: Int
    public let mainGroup: Int  
    enum CodingKeys: String, CodingKey {
        case id = "menu_items_id"
        case name = "menu_item_name"
        case description = "menu_item_desc"
        case price = "menu_item_price"
        case stock = "menu_item_stock"
        case parentID = "menu_item_parent"
        case mainGroup = "menu_main"
    }
}
