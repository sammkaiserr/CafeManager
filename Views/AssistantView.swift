import SwiftUI

struct AssistantView: View {
    var items: [Item]
    @StateObject private var viewModel = AssistantViewModel()

    private var refreshKey: String {
        items
            .sorted { $0.id < $1.id }
            .map { "\($0.id)-\($0.quantity)-\($0.threshold)" }
            .joined(separator: "|")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let insights = viewModel.insights(for: items)

            Text("Smart Assistant")
                .font(.title2)
                .bold()

            if viewModel.isGenerating {
                ProgressView("Generating AI inventory briefing...")
            }

            if let aiBriefing = viewModel.aiBriefing {
                VStack(alignment: .leading, spacing: 6) {
                    Text("AI Briefing")
                        .font(.headline)
                    Text(aiBriefing)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else if let assistantStatus = viewModel.assistantStatus {
                Text(assistantStatus)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if insights.isEmpty {
                Text("No urgent inventory actions right now.")
                    .foregroundColor(.gray)
            }

            ForEach(insights) { insight in
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.headline)
                        .foregroundStyle(color(for: insight.severity))
                    Text(insight.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(color(for: insight.severity).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .task(id: refreshKey) {
            await viewModel.refreshBriefing(for: items)
        }
    }

    private func color(for severity: InsightSeverity) -> Color {
        switch severity {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}
