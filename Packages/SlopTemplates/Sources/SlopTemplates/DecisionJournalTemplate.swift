import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct Decision: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Title") var title: String = ""
    @Field("Date", editor: .date) var date: Date = .now
    @Field("Context", editor: .multiLine) var context: String = ""
    @Field("Expected Outcome", editor: .multiLine) var expectedOutcome: String = ""
    @Field("Actual Outcome", editor: .multiLine) var actualOutcome: String = ""
    @Field("What I Learned", editor: .multiLine) var learned: String = ""

    var isReviewed: Bool { !actualOutcome.isEmpty }
}

@SlopData
public struct DecisionJournalData {
    @SlopKit.Section("Journal")
    @Field("Title") var title: String = "Decision Journal"
    @Field("Decisions") var decisions: [Decision] = DecisionJournalData.defaultDecisions

    var totalDecisions: Int { decisions.count }
    var reviewedCount: Int { decisions.filter(\.isReviewed).count }
    var pendingReview: Int { totalDecisions - reviewedCount }
}

extension DecisionJournalData {
    private static func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
    }

    static var defaultDecisions: [Decision] {
        var d1 = Decision()
        d1.title = "Switch to new framework"
        d1.date = makeDate(2026, 3, 15)
        d1.context = "Current framework is outdated, team wants to modernize"
        d1.expectedOutcome = "Better performance, easier maintenance, happier team"
        d1.actualOutcome = "Migration took 3 weeks, performance improved 40%, team loves it"
        d1.learned = "Migration always takes longer than expected, but worth it for long-term gains"

        var d2 = Decision()
        d2.title = "Hire additional designer"
        d2.date = makeDate(2026, 4, 1)
        d2.context = "Product roadmap growing, design bottleneck identified"
        d2.expectedOutcome = "Faster iteration, higher quality designs"
        d2.actualOutcome = ""
        d2.learned = ""

        return [d1, d2]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.decision-journal",
    name: "Decision Journal",
    description: "Log decisions with expected vs. actual outcomes to improve judgment over time.",
    version: "1.0.0",
    width: 420, height: 640,
    minWidth: 380, minHeight: 520,
    shape: .roundedRect(radius: 16),
    theme: "paper-ledger",
    alwaysOnTop: false,
    categories: ["personal"]
)
struct DecisionJournalView: View {
    @TemplateData var data: DecisionJournalData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                SlopTemplateHeader(
                    titlePlaceholder: "Decision journal",
                    title: $data.title
                )

                HStack(spacing: 10) {
                    MetricPill("\(data.totalDecisions) decisions", tint: theme.accent)
                    MetricPill("\(data.reviewedCount) reviewed", tint: theme.secondary)
                    MetricPill("\(data.pendingReview) pending", tint: theme.foreground.opacity(0.5))
                    Spacer()
                }

                if data.totalDecisions > 0 {
                    SlopSurfaceCard {
                        VStack(spacing: 8) {
                            SummaryRow(
                                label: "Total Logged",
                                value: "\(data.totalDecisions)",
                                valueColor: theme.foreground
                            )
                            SummaryRow(
                                label: "Reviewed",
                                value: "\(data.reviewedCount)",
                                valueColor: theme.accent
                            )
                            SummaryRow(
                                label: "Awaiting Review",
                                value: "\(data.pendingReview)",
                                valueColor: theme.secondary
                            )
                        }
                    }
                }

                Divider().background(theme.divider)

                SlopRecordListSection(
                    title: "Decisions",
                    isEmpty: data.decisions.isEmpty,
                    addLabel: "Log Decision",
                    onAdd: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.decisions.insert(Decision(), at: 0)
                        }
                    },
                    emptyState: {
                        EmptyState(
                            icon: "list.clipboard",
                            title: "No decisions logged",
                            subtitle: "Start tracking your important decisions"
                        )
                    },
                    content: {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach($data.decisions) { $decision in
                                    decisionCard(decision: $decision)
                                }
                            }
                        }
                    }
                )
            }
            .padding(24)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func decisionCard(decision: Binding<Decision>) -> some View {
        SlopSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        SlopTextField("Decision title", text: decision.title)
                            .font(theme.font(size: 16, weight: .bold))
                            .foregroundStyle(theme.foreground)

                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(theme.font(size: 10, weight: .bold))
                                .foregroundStyle(theme.secondary)
                            SlopDateField(decision.date)

                            if decision.wrappedValue.isReviewed {
                                Spacer()
                                MetricPill("reviewed", tint: theme.accent)
                            }
                        }
                    }

                    Spacer()

                    RemoveButton {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.decisions.removeAll { $0.id == decision.wrappedValue.id }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader("Context")
                    SlopTextArea("Why this decision mattered", text: decision.context, minHeight: 72)
                }

                Divider().background(theme.divider.opacity(0.5))

                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader("Expected Outcome")
                    SlopTextArea("What I expected to happen", text: decision.expectedOutcome, minHeight: 72)
                }

                Divider().background(theme.divider.opacity(0.5))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        SectionHeader("Actual Outcome")
                        if !decision.wrappedValue.isReviewed {
                            Spacer()
                            Text("pending review")
                                .font(theme.mono(size: 9, weight: .medium))
                                .foregroundStyle(theme.secondary.opacity(0.5))
                                .italic()
                        }
                    }
                    SlopTextArea("What actually happened", text: decision.actualOutcome, minHeight: 72)
                        .foregroundStyle(decision.wrappedValue.isReviewed ? theme.accent : theme.secondary.opacity(0.85))
                }

                if decision.wrappedValue.isReviewed {
                    Divider().background(theme.divider.opacity(0.5))

                    VStack(alignment: .leading, spacing: 4) {
                        SectionHeader("What I Learned")
                        SlopTextArea("Key takeaways", text: decision.learned, minHeight: 72)
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    decision.wrappedValue.isReviewed ? theme.accent.opacity(0.2) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

