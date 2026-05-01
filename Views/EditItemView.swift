import SwiftUI

struct EditItemView: View {
    @Environment(\.dismiss) var dismiss

    @State private var name: String
    @State private var quantity: String
    @State private var threshold: String
    @State private var errorMessage: String?

    var item: Item
    var onUpdate: (Item) -> Void

    init(item: Item, onUpdate: @escaping (Item) -> Void) {
        self.item = item
        self.onUpdate = onUpdate

        _name = State(initialValue: item.name)
        _quantity = State(initialValue: "\(item.quantity)")
        _threshold = State(initialValue: "\(item.threshold)")
    }

    var body: some View {
        NavigationView {
            Form {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                TextField("Item Name", text: $name)
                TextField("Quantity", text: $quantity)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
                TextField("Threshold", text: $threshold)
#if os(iOS)
                    .keyboardType(.numberPad)
#endif
            }
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Update") {
                        updateItem()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    func updateItem() {
        guard let qty = Int(quantity),
              let th = Int(threshold),
              qty >= 0,
              th >= 0 else {
            errorMessage = "Enter valid non-negative numbers for quantity and threshold."
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Item name cannot be empty."
            return
        }

        errorMessage = nil
        let updatedItem = Item(
            id: item.id,
            name: trimmedName,
            quantity: qty,
            threshold: th
        )

        onUpdate(updatedItem)
        dismiss()
    }
}
