import SwiftUI

struct ContentView: View {
    @State private var items: [Item] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAddSheet = false
    @State private var selectedItem: Item?

    let service = FirestoreService()

    var body: some View {
        NavigationView {
            VStack {
                if isLoading && items.isEmpty {
                    ProgressView("Loading inventory...")
                } else if items.isEmpty {
                    ContentUnavailableView(
                        "No inventory yet",
                        systemImage: "shippingbox",
                        description: Text("Add your first item to start tracking stock.")
                    )
                } else {
                    List {
                        if let errorMessage {
                            Section {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                            }
                        }

                        Section {
                            ForEach(items) { item in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.name)
                                        .font(.headline)

                                    Text("Quantity: \(item.quantity)")
                                        .font(.subheadline)

                                    if item.quantity <= item.threshold {
                                        Text("⚠️ Low Stock")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                    }
                                }
                                .onTapGesture {
                                    selectedItem = item
                                }
                            }
                            .onDelete(perform: deleteItem)
                        }

                        Section {
                            AssistantView(items: items)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddItemView { newItem in
                    addItem(newItem)
                }
            }
            .sheet(item: $selectedItem) { item in
                EditItemView(item: item) { updatedItem in
                    updateItem(updatedItem)
                }
            }
            .onAppear {
                loadItems()
            }
        }
    }

    func loadItems() {
        isLoading = true
        service.fetchItems { result in
            DispatchQueue.main.async {
                isLoading = false

                switch result {
                case .success(let fetchedItems):
                    items = fetchedItems
                    errorMessage = nil
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func addItem(_ newItem: Item) {
        service.addItem(newItem) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    errorMessage = nil
                    loadItems()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func deleteItem(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { items[$0] }
        let group = DispatchGroup()
        var deletionError: Error?

        for item in itemsToDelete {
            group.enter()
            service.deleteItem(item) { result in
                if case .failure(let error) = result {
                    deletionError = error
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let deletionError {
                errorMessage = deletionError.localizedDescription
            } else {
                errorMessage = nil
                loadItems()
            }
        }
    }

    func updateItem(_ updatedItem: Item) {
        service.updateItem(updatedItem) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    errorMessage = nil
                    loadItems()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
