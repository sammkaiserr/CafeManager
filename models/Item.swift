import Foundation

struct Item: Identifiable, Codable {
    var id: String
    var name: String
    var quantity: Int
    var threshold: Int
}
