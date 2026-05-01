import SwiftUI

struct AssistantView: View {
    var items: [Item]
    @StateObject private var viewModel = AssistantViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            let insights = viewModel.insights(for: items)

            Text("Smart Assistant")
                .font(.title2)
                .bold()

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
