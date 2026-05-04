import SwiftUI

struct ContentView: View {
    private enum AppSection: String, CaseIterable, Hashable, Identifiable {
        case takeOrder = "Take Order"
        case inventory = "Inventory"

        var id: String {
            rawValue
        }

        var systemImage: String {
            switch self {
            case .takeOrder:
                return "takeoutbag.and.cup.and.straw.fill"
            case .inventory:
                return "shippingbox.fill"
            }
        }
    }

    @State private var items: [Item] = []
    @State private var orders: [CafeOrder] = []
    @State private var isLoading = false
    @State private var isLoadingOrders = false
    @State private var errorMessage: String?
    @State private var showAddSheet = false
    @State private var showTakeOrderSheet = false
    @State private var takeOrderTableNumber = 1
    @State private var activeOrder: CafeOrder?
    @State private var orderPendingDeletion: CafeOrder?
    @State private var selectedItem: Item?
    @State private var selectedSection: AppSection?

    let service = FirestoreService()

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selectedSection) { section in
                Label(section.rawValue, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("Cafe Manager")
        } detail: {
            Group {
                switch selectedSection {
                case nil:
                    homeContent
                case .takeOrder:
                    takeOrderContent
                case .inventory:
                    inventoryContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if selectedSection == .inventory {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddItemView { newItem in
                    addItem(newItem)
                }
            }
            .sheet(isPresented: $showTakeOrderSheet) {
                TakeOrderView(
                    items: items,
                    initialTableNumber: takeOrderTableNumber,
                    existingOrder: activeOrder
                ) { existingOrder, tableNumber, selections, completion in
                    completeOrder(
                        existingOrder: existingOrder,
                        tableNumber: tableNumber,
                        selections: selections,
                        completion: completion
                    )
                }
            }
            .sheet(item: $selectedItem) { item in
                EditItemView(item: item) { updatedItem in
                    updateItem(updatedItem)
                }
            }
            .alert("Delete Order?", isPresented: Binding(
                get: { orderPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        orderPendingDeletion = nil
                    }
                }
            )) {
                Button("Delete", role: .destructive) {
                    if let orderPendingDeletion {
                        deleteOrder(orderPendingDeletion)
                    }
                    self.orderPendingDeletion = nil
                }
                Button("Cancel", role: .cancel) {
                    orderPendingDeletion = nil
                }
            } message: {
                if let orderPendingDeletion {
                    Text("Delete the order for table \(orderPendingDeletion.tableNumber) and restore its items to inventory?")
                }
            }
            .onAppear {
                loadItems()
                loadOrders()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var homeContent: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    pageSectionCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cafe Manager")
                                .font(.largeTitle.bold())
                            Text("Manage orders, monitor inventory, and act on stock issues from one place.")
                                .foregroundColor(.secondary)
                        }
                    }

                    pageSectionCard(title: "Quick Actions") {
                        Button {
                            selectedSection = .takeOrder
                        } label: {
                            Label("Go to Take Order", systemImage: AppSection.takeOrder.systemImage)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            selectedSection = .inventory
                        } label: {
                            Label("Go to Inventory", systemImage: AppSection.inventory.systemImage)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    pageSectionCard(title: "Today at a Glance") {
                        Label("\(orders.count) active order\(orders.count == 1 ? "" : "s")", systemImage: "list.bullet.rectangle")
                        Label("\(items.filter { $0.quantity <= $0.threshold }.count) low-stock item\(items.filter { $0.quantity <= $0.threshold }.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle")
                        Label("\(items.count) inventory item\(items.count == 1 ? "" : "s")", systemImage: "shippingbox")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle("Cafe Manager")
        }
    }

    private var takeOrderContent: some View {
        NavigationStack {
            Group {
                if isLoading && items.isEmpty {
                    ProgressView("Loading menu...")
                } else if items.isEmpty {
                    ContentUnavailableView(
                        "No menu items yet",
                        systemImage: "takeoutbag.and.cup.and.straw",
                        description: Text("Add inventory items first, then start taking orders.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            if let errorMessage {
                                pageSectionCard {
                                    Text(errorMessage)
                                        .foregroundColor(.red)
                                }
                            }

                            pageSectionCard {
                                Button {
                                    activeOrder = nil
                                    takeOrderTableNumber = 1
                                    showTakeOrderSheet = true
                                } label: {
                                    Label("Take Order", systemImage: "takeoutbag.and.cup.and.straw.fill")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            pageSectionCard(title: "Recent Orders") {
                                if isLoadingOrders {
                                    ProgressView("Loading orders...")
                                } else if orders.isEmpty {
                                    Text("Completed orders will appear here.")
                                        .foregroundColor(.secondary)
                                } else {
                                    ForEach(orders) { order in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text("Table \(order.tableNumber)")
                                                    .font(.headline)

                                                Spacer()

                                                Text(order.createdAt.formatted(date: .omitted, time: .shortened))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }

                                            Text(order.items.map { "\($0.name) x\($0.quantity)" }.joined(separator: ", "))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)

                                            Text("\(order.totalItems) item\(order.totalItems == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundColor(.secondary)

                                            Button("Order More") {
                                                activeOrder = order
                                                takeOrderTableNumber = order.tableNumber
                                                showTakeOrderSheet = true
                                            }
                                            .font(.subheadline.weight(.semibold))

                                            Button("Delete Order", role: .destructive) {
                                                orderPendingDeletion = order
                                            }
                                            .font(.subheadline.weight(.semibold))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 4)

                                        if order.id != orders.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Take Order")
        }
    }

    private var inventoryContent: some View {
        NavigationStack {
            Group {
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

                        Section("Inventory") {
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
                            AssistantView(items: items, orders: orders)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Inventory")
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

    func loadOrders() {
        isLoadingOrders = true
        service.fetchOrders { result in
            DispatchQueue.main.async {
                isLoadingOrders = false

                switch result {
                case .success(let fetchedOrders):
                    orders = fetchedOrders
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

    func completeOrder(
        existingOrder: CafeOrder?,
        tableNumber: Int,
        selections: [OrderSelection],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard !selections.isEmpty else {
            completion(.failure(FirestoreServiceError.emptyOrder))
            return
        }

        var inventoryByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var insufficientStockItems: [String] = []
        var updatedItems: [Item] = []

        for selection in selections {
            guard var currentItem = inventoryByID[selection.item.id] else {
                insufficientStockItems.append(selection.item.name)
                continue
            }

            if selection.quantity > currentItem.quantity {
                insufficientStockItems.append(currentItem.name)
                continue
            }

            currentItem.quantity -= selection.quantity
            inventoryByID[currentItem.id] = currentItem
            updatedItems.append(currentItem)
        }

        guard insufficientStockItems.isEmpty else {
            completion(.failure(FirestoreServiceError.insufficientStock(insufficientStockItems)))
            return
        }

        service.completeOrder(
            existingOrder: existingOrder,
            tableNumber: tableNumber,
            orderedItems: selections,
            updatedItems: updatedItems
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    errorMessage = nil
                    loadItems()
                    loadOrders()
                    completion(.success(()))
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }

    func deleteOrder(_ order: CafeOrder) {
        var inventoryByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var restoredItems: [Item] = []

        for orderedItem in order.items {
            guard var currentItem = inventoryByID[orderedItem.itemID] else {
                continue
            }

            currentItem.quantity += orderedItem.quantity
            inventoryByID[currentItem.id] = currentItem
            restoredItems.append(currentItem)
        }

        service.deleteOrder(order, restoredItems: restoredItems) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    errorMessage = nil
                    loadItems()
                    loadOrders()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private func pageSectionCard<Content: View>(
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
}
