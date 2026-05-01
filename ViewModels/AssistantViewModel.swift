import Combine
import Foundation

struct AssistantInsight: Identifiable {
    let id: String
    let title: String
    let message: String
    let severity: InsightSeverity
}

enum InsightSeverity {
    case info
    case warning
    case critical
}

final class AssistantViewModel: ObservableObject {
    func insights(for items: [Item]) -> [AssistantInsight] {
        guard !items.isEmpty else {
            return []
        }

        var results: [AssistantInsight] = []
        let outOfStockItems = items.filter { $0.quantity == 0 }
        let lowStockItems = items
            .filter { $0.quantity > 0 && $0.quantity <= $0.threshold }
            .sorted { stockGap(for: $0) > stockGap(for: $1) }
        let invalidThresholdItems = items.filter { $0.threshold <= 0 }

        if !outOfStockItems.isEmpty {
            let names = outOfStockItems.map(\.name).joined(separator: ", ")
            results.append(
                AssistantInsight(
                    id: "out-of-stock",
                    title: "Urgent reorder",
                    message: "\(names) \(outOfStockItems.count == 1 ? "is" : "are") out of stock. Create a purchase order now.",
                    severity: .critical
                )
            )
        }

        if let nextRisk = lowStockItems.first {
            results.append(
                AssistantInsight(
                    id: "next-risk-\(nextRisk.id)",
                    title: "Next restock priority",
                    message: "\(nextRisk.name) is \(stockGap(for: nextRisk)) units below its target buffer.",
                    severity: .warning
                )
            )
        }

        if lowStockItems.count > 1 {
            let names = lowStockItems.prefix(3).map(\.name).joined(separator: ", ")
            results.append(
                AssistantInsight(
                    id: "bundle-order",
                    title: "Bundle supplier order",
                    message: "Group \(names) into one restock run to clear \(lowStockItems.count) low-stock items together.",
                    severity: .info
                )
            )
        }

        if !invalidThresholdItems.isEmpty {
            let names = invalidThresholdItems.map(\.name).joined(separator: ", ")
            results.append(
                AssistantInsight(
                    id: "invalid-threshold",
                    title: "Data needs review",
                    message: "\(names) \(invalidThresholdItems.count == 1 ? "has" : "have") no usable threshold. Set a minimum stock level to improve alerts.",
                    severity: .warning
                )
            )
        }

        return results
    }

    private func stockGap(for item: Item) -> Int {
        max(item.threshold - item.quantity, 0)
    }
}
