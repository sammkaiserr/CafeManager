import SwiftUI

struct TakeOrderView: View {
    @Environment(\.dismiss) private var dismiss

    let items: [Item]
    let initialTableNumber: Int
    let existingOrder: CafeOrder?
    let onCompleteOrder: (CafeOrder?, Int, [OrderSelection], @escaping (Result<Void, Error>) -> Void) -> Void

    @State private var selectedTableNumber: Int
    @State private var selectedQuantities: [String: Int] = [:]
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    init(
        items: [Item],
        initialTableNumber: Int = 1,
        existingOrder: CafeOrder? = nil,
        onCompleteOrder: @escaping (CafeOrder?, Int, [OrderSelection], @escaping (Result<Void, Error>) -> Void) -> Void
    ) {
        self.items = items
        self.initialTableNumber = initialTableNumber
        self.existingOrder = existingOrder
        self.onCompleteOrder = onCompleteOrder
        _selectedTableNumber = State(initialValue: initialTableNumber)
    }

    private var orderedSelections: [OrderSelection] {
        items.compactMap { item in
            let quantity = selectedQuantities[item.id, default: 0]
            guard quantity > 0 else {
                return nil
            }

            return OrderSelection(item: item, quantity: quantity)
        }
    }

    private var totalSelectedItems: Int {
        orderedSelections.reduce(0) { $0 + $1.quantity }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    sectionCard(title: "Table") {
                        if existingOrder != nil {
                            HStack {
                                Text("Table Number")
                                Spacer()
                                Text("\(selectedTableNumber)")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            HStack {
                                Text("Table Number")

                                Spacer()

                                HStack(spacing: 12) {
                                    Button {
                                        if selectedTableNumber > 1 {
                                            selectedTableNumber -= 1
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title3)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(selectedTableNumber == 1 || isSubmitting)

                                    Text("\(selectedTableNumber)")
                                        .font(.headline)
                                        .frame(minWidth: 28)

                                    Button {
                                        if selectedTableNumber < 20 {
                                            selectedTableNumber += 1
                                        }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(selectedTableNumber == 20 || isSubmitting)
                                }
                            }
                        }
                    }

                    if let errorMessage {
                        sectionCard {
                            Text(errorMessage)
                                .foregroundColor(.red)
                        }
                    }

                    if let existingOrder, !existingOrder.items.isEmpty {
                        sectionCard(title: "Current Order") {
                            ForEach(existingOrder.items) { item in
                                HStack {
                                    Text(item.name)
                                    Spacer()
                                    Text("x\(item.quantity)")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    sectionCard(title: "Menu") {
                        ForEach(items) { item in
                            orderRow(for: item)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .navigationTitle(existingOrder == nil ? "Take Order" : "Order More")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Table \(selectedTableNumber)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text("\(totalSelectedItems) item\(totalSelectedItems == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Button(action: completeOrder) {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Complete Order")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitting || orderedSelections.isEmpty)
                }
                .padding()
                .background(.regularMaterial)
            }
        }
    }

    @ViewBuilder
    private func sectionCard<Content: View>(
        title: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.systemGray5), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func orderRow(for item: Item) -> some View {
        let quantity = selectedQuantities[item.id, default: 0]

        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)

                Text("Available: \(item.quantity)")
                    .font(.caption)
                    .foregroundColor(item.quantity <= item.threshold ? .orange : .secondary)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    updateQuantity(for: item, delta: -1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(quantity == 0 || isSubmitting)

                Text("\(quantity)")
                    .font(.headline)
                    .frame(minWidth: 28)

                Button {
                    updateQuantity(for: item, delta: 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(quantity >= item.quantity || isSubmitting || item.quantity == 0)
            }
            .foregroundColor(item.quantity == 0 ? .gray : .accentColor)
        }
        .padding(.vertical, 4)
    }

    private func updateQuantity(for item: Item, delta: Int) {
        let current = selectedQuantities[item.id, default: 0]
        let updated = min(max(current + delta, 0), item.quantity)
        selectedQuantities[item.id] = updated
        errorMessage = nil
    }

    private func completeOrder() {
        guard !orderedSelections.isEmpty else {
            errorMessage = "Add at least one item before completing the order."
            return
        }

        isSubmitting = true
        errorMessage = nil

        onCompleteOrder(existingOrder, selectedTableNumber, orderedSelections) { result in
            DispatchQueue.main.async {
                isSubmitting = false

                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
