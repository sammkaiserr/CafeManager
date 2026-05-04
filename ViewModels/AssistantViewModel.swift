import Combine
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

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
    @Published private(set) var aiBriefing: String?
    @Published private(set) var assistantStatus: String?
    @Published private(set) var isGenerating = false

    func insights(for items: [Item], orders: [CafeOrder]) -> [AssistantInsight] {
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

        let recentDemand = recentDemandByItemID(from: orders)
        let highDemandLowStockItems = lowStockItems
            .filter { recentDemand[$0.id, default: 0] > 0 }
            .sorted { recentDemand[$0.id, default: 0] > recentDemand[$1.id, default: 0] }

        if let demandRisk = highDemandLowStockItems.first {
            let recentOrders = recentDemand[demandRisk.id, default: 0]
            results.append(
                AssistantInsight(
                    id: "demand-risk-\(demandRisk.id)",
                    title: "Selling now, running low",
                    message: "\(demandRisk.name) sold \(recentOrders) time\(recentOrders == 1 ? "" : "s") recently and is already near its stock limit.",
                    severity: .critical
                )
            )
        }

        let slowMovingItems = slowMovingItems(from: items, orders: orders)
        if let slowMovingItem = slowMovingItems.first {
            results.append(
                AssistantInsight(
                    id: "slow-moving-\(slowMovingItem.id)",
                    title: "Slow-moving stock",
                    message: "\(slowMovingItem.name) has \(slowMovingItem.quantity) units on hand and no recent orders. Pause reordering or feature it in a promotion.",
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

    private func recentDemandByItemID(from orders: [CafeOrder]) -> [String: Int] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -1, to: Date()) ?? .distantPast
        let recentOrders = orders.filter { $0.createdAt >= cutoffDate }

        var demandByItemID: [String: Int] = [:]
        for order in recentOrders {
            for item in order.items {
                demandByItemID[item.itemID, default: 0] += item.quantity
            }
        }

        return demandByItemID
    }

    private func slowMovingItems(from items: [Item], orders: [CafeOrder]) -> [Item] {
        let calendar = Calendar.current
        let cutoffDate = calendar.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        let activeItemIDs = Set(
            orders
                .filter { $0.createdAt >= cutoffDate }
                .flatMap(\.items)
                .map(\.itemID)
        )

        return items
            .filter { !activeItemIDs.contains($0.id) }
            .filter { $0.quantity >= max($0.threshold * 3, 10) }
            .sorted { $0.quantity > $1.quantity }
    }

    @MainActor
    func refreshBriefing(for items: [Item], orders: [CafeOrder]) async {
        guard !items.isEmpty else {
            aiBriefing = nil
            assistantStatus = nil
            isGenerating = false
            return
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                await generateBriefing(for: items, orders: orders)
            case .unavailable(let reason):
                aiBriefing = nil
                assistantStatus = statusMessage(for: reason)
                isGenerating = false
            }
        } else {
            aiBriefing = nil
            assistantStatus = "AI briefing needs a newer OS version."
            isGenerating = false
        }
        #else
        aiBriefing = nil
        assistantStatus = "Foundation Models is unavailable in this build."
        isGenerating = false
        #endif
    }
}
#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
private extension AssistantViewModel {
    func generateBriefing(for items: [Item], orders: [CafeOrder]) async {
        isGenerating = true
        assistantStatus = nil

        let prompt = inventoryPrompt(for: items, orders: orders)
        let session = LanguageModelSession(
            model: .default,
            instructions: """
            You are an operations assistant for a cafe manager.
            Review inventory data and produce a short action briefing.
            Focus on what needs attention first, what can be bundled into one supplier run, what is actively selling, and what stock appears slow-moving.
            Do not invent sales rates, dates, supplier names, or missing facts.
            Keep the response under 90 words and use plain English.
            """
        )

        do {
            let response = try await session.respond(
                to: prompt,
                options: GenerationOptions(temperature: 0.2)
            )
            aiBriefing = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            aiBriefing = nil
            assistantStatus = errorMessage(for: error)
        }

        isGenerating = false
    }

    func inventoryPrompt(for items: [Item], orders: [CafeOrder]) -> String {
        let lines = items
            .sorted { stockGap(for: $0) > stockGap(for: $1) }
            .map { item in
                "\(item.name): quantity \(item.quantity), threshold \(item.threshold)"
            }
            .joined(separator: "\n")
        let demandByItemID = recentDemandByItemID(from: orders)
        let recentDemandLines = items
            .filter { demandByItemID[$0.id, default: 0] > 0 }
            .sorted { demandByItemID[$0.id, default: 0] > demandByItemID[$1.id, default: 0] }
            .prefix(5)
            .map { item in
                "\(item.name): \(demandByItemID[item.id, default: 0]) ordered in the last 24 hours"
            }
            .joined(separator: "\n")

        return """
        Build an inventory briefing for this cafe.
        Inventory records:
        \(lines)
        Recent order signals:
        \(recentDemandLines.isEmpty ? "No recent orders recorded." : recentDemandLines)
        """
    }

    func statusMessage(for availability: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch availability {
        case .deviceNotEligible:
            return "AI briefing is unavailable on this device."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence to generate an AI inventory briefing."
        case .modelNotReady:
            return "The on-device model is still getting ready. Inventory signals are shown below in the meantime."
        @unknown default:
            return "AI briefing is unavailable right now."
        }
    }

    func errorMessage(for error: Error) -> String {
        if let generationError = error as? LanguageModelSession.GenerationError {
            switch generationError {
            case .unsupportedLanguageOrLocale:
                return "The AI model could not process this inventory briefing language."
            default:
                return "The AI briefing could not be generated right now."
            }
        }

        return "The AI briefing could not be generated right now."
    }
}
#endif
