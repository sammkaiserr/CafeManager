import SwiftUI

struct AddItemView: View {
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var quantity = ""
    @State private var threshold = ""
    @State private var errorMessage: String?

    var onSave: (Item) -> Void

    var body: some View {
        NavigationView {
            Form {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }

                TextField("Item Name", text: $name)

                TextField("Quantity", text: $quantity)
                    .keyboardType(.numberPad)

                TextField("Threshold", text: $threshold)
                    .keyboardType(.numberPad)
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
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

    func saveItem() {
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
        let item = Item(
            id: UUID().uuidString,
            name: trimmedName,
            quantity: qty,
            threshold: th
        )

        onSave(item)
        dismiss()
    }
}
