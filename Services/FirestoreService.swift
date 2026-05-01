import Foundation
import FirebaseFirestore

enum FirestoreServiceError: LocalizedError {
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case .invalidDocument:
            return "Some inventory records are missing required fields."
        }
    }
}

final class FirestoreService {
    private let db = Firestore.firestore()

    func addItem(_ item: Item, completion: @escaping (Result<Void, Error>) -> Void) {
        let data: [String: Any] = [
            "id": item.id,
            "name": item.name,
            "quantity": item.quantity,
            "threshold": item.threshold
        ]

        db.collection("items").document(item.id).setData(data) { error in
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
}
