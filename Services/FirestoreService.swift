import Foundation
import FirebaseFirestore

enum FirestoreServiceError: LocalizedError {
    case invalidDocument
    case emptyOrder
    case insufficientStock([String])

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            return "Some inventory records are missing required fields."
        case .emptyOrder:
            return "Add at least one menu item before completing the order."
        case .insufficientStock(let names):
            return "Not enough stock for: \(names.joined(separator: ", "))."
        }
    }
}

final class FirestoreService {
    private let db = Firestore.firestore()

    private func itemData(for item: Item) -> [String: Any] {
        [
            "id": item.id,
            "name": item.name,
            "quantity": item.quantity,
            "threshold": item.threshold
        ]
    }

    func addItem(_ item: Item, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("items").document(item.id).setData(itemData(for: item)) { error in
            if let error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }
    }

    func fetchItems(completion: @escaping (Result<[Item], Error>) -> Void) {
        db.collection("items").getDocuments { snapshot, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let documents = snapshot?.documents else {
                completion(.success([]))
                return
            }

            let items = documents.compactMap { document -> Item? in
                let data = document.data()
                guard let name = data["name"] as? String else {
                    return nil
                }

                let quantity = data["quantity"] as? Int ?? 0
                let threshold = data["threshold"] as? Int ?? 0

                return Item(
                    id: data["id"] as? String ?? document.documentID,
                    name: name,
                    quantity: quantity,
                    threshold: threshold
                )
            }

            completion(.success(items))
        }
    }

    func updateItem(_ item: Item, completion: @escaping (Result<Void, Error>) -> Void) {
        addItem(item, completion: completion)
    }

    func deleteItem(_ item: Item, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("items").document(item.id).delete { error in
            if let error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }
    }

    func completeOrder(
        existingOrder: CafeOrder?,
        tableNumber: Int,
        orderedItems: [OrderSelection],
        updatedItems: [Item],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !orderedItems.isEmpty else {
            completion(.failure(FirestoreServiceError.emptyOrder))
            return
        }

        let batch = db.batch()
        let orderReference: DocumentReference
        let existingItems = existingOrder?.items ?? []

        if let existingOrder {
            orderReference = db.collection("orders").document(existingOrder.id)
        } else {
            orderReference = db.collection("orders").document()
        }

        let orderData: [String: Any] = [
            "id": orderReference.documentID,
            "tableNumber": tableNumber,
            "createdAt": Timestamp(date: existingOrder?.createdAt ?? Date()),
            "items": mergedOrderItems(existingItems: existingItems, addedItems: orderedItems)
        ]

        batch.setData(orderData, forDocument: orderReference)

        for item in updatedItems {
            let itemReference = db.collection("items").document(item.id)
            batch.setData(itemData(for: item), forDocument: itemReference)
        }

        batch.commit { error in
            if let error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }
    }

    private func mergedOrderItems(
        existingItems: [CafeOrderItem],
        addedItems: [OrderSelection]
    ) -> [[String: Any]] {
        var quantitiesByItemID = Dictionary(
            uniqueKeysWithValues: existingItems.map { item in
                (
                    item.itemID,
                    (name: item.name, quantity: item.quantity)
                )
            }
        )

        for item in addedItems {
            let current = quantitiesByItemID[item.item.id]
            quantitiesByItemID[item.item.id] = (
                name: item.item.name,
                quantity: (current?.quantity ?? 0) + item.quantity
            )
        }

        return quantitiesByItemID.map { itemID, value in
            [
                "itemID": itemID,
                "name": value.name,
                "quantity": value.quantity
            ]
        }
        .sorted { lhs, rhs in
            let leftName = lhs["name"] as? String ?? ""
            let rightName = rhs["name"] as? String ?? ""
            return leftName < rightName
        }
    }

    func fetchOrders(completion: @escaping (Result<[CafeOrder], Error>) -> Void) {
        db.collection("orders")
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error {
                    completion(.failure(error))
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }

                let orders = documents.compactMap { document -> CafeOrder? in
                    let data = document.data()
                    guard let tableNumber = data["tableNumber"] as? Int else {
                        return nil
                    }

                    let timestamp = data["createdAt"] as? Timestamp ?? Timestamp(date: .distantPast)
                    let rawItems = data["items"] as? [[String: Any]] ?? []
                    let items = rawItems.compactMap { rawItem -> CafeOrderItem? in
                        guard
                            let itemID = rawItem["itemID"] as? String,
                            let name = rawItem["name"] as? String,
                            let quantity = rawItem["quantity"] as? Int
                        else {
                            return nil
                        }

                        return CafeOrderItem(itemID: itemID, name: name, quantity: quantity)
                    }

                    return CafeOrder(
                        id: data["id"] as? String ?? document.documentID,
                        tableNumber: tableNumber,
                        createdAt: timestamp.dateValue(),
                        items: items
                    )
                }

                completion(.success(orders))
            }
    }

    func deleteOrder(
        _ order: CafeOrder,
        restoredItems: [Item],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let batch = db.batch()
        let orderReference = db.collection("orders").document(order.id)
        batch.deleteDocument(orderReference)

        for item in restoredItems {
            let itemReference = db.collection("items").document(item.id)
            batch.setData(itemData(for: item), forDocument: itemReference)
        }

        batch.commit { error in
            if let error {
                completion(.failure(error))
                return
            }

            completion(.success(()))
        }
    }
}
