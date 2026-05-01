import Foundation

struct OrderSelection: Identifiable {
    let item: Item
    let quantity: Int

    var id: String {
        item.id
    }
}

struct CafeOrderItem: Identifiable {
    let itemID: String
    let name: String
    let quantity: Int

    var id: String {
        itemID
    }
}

struct CafeOrder: Identifiable {
    let id: String
    let tableNumber: Int
    let createdAt: Date
    let items: [CafeOrderItem]

    var totalItems: Int {
        items.reduce(0) { $0 + $1.quantity }
    }
}
