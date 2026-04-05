import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct KeyResult: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Key Result") var name: String = ""
    @Field("Current Value") var currentValue: Double = 0
    @Field("Target Value") var targetValue: Double = 100
    @Field("Unit") var unit: String = "%"

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(1.0, currentValue / targetValue)
    }
}

@SlopData
public struct Objective: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Objective Title") var title: String = ""
    @Field("Key Results") var keyResults: [KeyResult] = []

    var objectiveProgress: Double {
        guard !keyResults.isEmpty else { return 0 }
        let total = keyResults.reduce(0.0) { $0 + $1.progress }
        return total / Double(keyResults.count)
    }
}

@SlopData
public struct OKRTrackerData {
    @SlopKit.Section("Overview")
    @Field("Quarter") var quarter: String = "Q2 2026"
    @Field("Team") var team: String = "Engineering"

    @SlopKit.Section("Objectives")
    @Field("Objectives") var objectives: [Objective] = OKRTrackerData.defaultObjectives

    var overallProgress: Double {
        guard !objectives.isEmpty else { return 0 }
        let total = objectives.reduce(0.0) { $0 + $1.objectiveProgress }
        return total / Double(objectives.count)
    }

    var totalKeyResults: Int {
        objectives.reduce(0) { $0 + $1.keyResults.count }
    }

    var completedKeyResults: Int {
        objectives.reduce(0) { count, obj in
            count + obj.keyResults.filter { $0.progress >= 1.0 }.count
        }
    }
}

extension OKRTrackerData {
    static var defaultObjectives: [Objective] {
        func objective(_ title: String, _ keyResults: [KeyResult]) -> Objective {
            var o = Objective()
            o.title = title
            o.keyResults = keyResults
            return o
        }

        func kr(_ name: String, _ current: Double, _ target: Double, _ unit: String = "%") -> KeyResult {
            var k = KeyResult()
            k.name = name
            k.currentValue = current
            k.targetValue = target
            k.unit = unit
            return k
        }

        return [
            objective("Ship New Template System", [
                kr("Build 20 templates", 14, 20, "templates"),
                kr("Component coverage", 85, 100),
                kr("User satisfaction", 4.2, 5.0, "/5"),
            ]),
            objective("Improve Performance", [
                kr("Reduce load time", 1.2, 0.5, "s"),
                kr("Frame rate target", 58, 60, "fps"),
            ]),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.okr-tracker",
    name: "OKR Tracker",
    description: "Track Objectives and Key Results with progress monitoring.",
    version: "1.0.0",
    width: 400, height: 600,
    minWidth: 360, minHeight: 500,
    shape: .roundedRect(radius: 16),
    theme: "terminal",
    alwaysOnTop: false,
    categories: ["work"]
)
struct OKRTrackerView: View {
    @TemplateData var data: OKRTrackerData
    @Environment(\.slopTheme) private var theme

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        SlopTextField("Quarter", text: $data.quarter)
                            .font(theme.title(size: 20))
                            .foregroundStyle(theme.foreground)

                        Spacer()

                        SlopTextField("Team", text: $data.team)
                            .font(theme.font(size: 12, weight: .medium))
                            .foregroundStyle(theme.secondary)
                    }
                }

                // Overall metrics
                HStack(spacing: 10) {
                    MetricPill("\(data.completedKeyResults)/\(data.totalKeyResults) KRs", tint: theme.accent)
                    MetricPill("\(data.objectives.count) OKRs", tint: theme.secondary)
                    Spacer()
                }

                // Overall progress
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        SectionHeader("Overall Progress")
                        Spacer()
                        Text("\(Int(data.overallProgress * 100))%")
                            .font(theme.font(size: 12, weight: .bold))
                            .foregroundStyle(theme.accent)
                            .contentTransition(.numericText())
                    }

                    ProgressBar(
                        progress: data.overallProgress,
                        fillColor: theme.accent,
                        backgroundColor: theme.surface,
                        height: 10
                    )
                }

                Divider().background(theme.divider)

                // Objectives
                if data.objectives.isEmpty {
                    EmptyState(
                        icon: "target",
                        title: "No objectives yet",
                        subtitle: "Add your first OKR to start tracking"
                    )
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach($data.objectives) { $objective in
                                VStack(alignment: .leading, spacing: 12) {
                                    // Objective header
                                    HStack(spacing: 8) {
                                        SlopTextField("Objective", text: $objective.title)
                                            .font(theme.font(size: 15, weight: .bold))
                                            .foregroundStyle(theme.foreground)

                                        Spacer()

                                        RemoveButton {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                data.objectives.removeAll { $0.id == objective.id }
                                            }
                                        }
                                    }

                                    // Objective progress
                                    HStack(spacing: 8) {
                                        ProgressBar(
                                            progress: objective.objectiveProgress,
                                            fillColor: theme.accent,
                                            backgroundColor: theme.surface,
                                            height: 6
                                        )
                                        .frame(maxWidth: .infinity)

                                        Text("\(Int(objective.objectiveProgress * 100))%")
                                            .font(theme.mono(size: 10))
                                            .foregroundStyle(theme.secondary)
                                    }

                                    // Key Results
                                    if !objective.keyResults.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            SectionHeader("Key Results")
                                                .padding(.top, 4)

                                            ForEach($objective.keyResults) { $kr in
                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack {
                                                        SlopTextField("KR", text: $kr.name)
                                                            .font(theme.font(size: 12))
                                                            .foregroundStyle(theme.foreground)

                                                        Spacer()

                                                        RemoveButton {
                                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                                objective.keyResults.removeAll { $0.id == kr.id }
                                                            }
                                                        }
                                                    }

                                                    HStack(spacing: 12) {
                                                        // Current value
                                                        HStack(spacing: 4) {
                                                            SlopNumberField("0", value: $kr.currentValue, format: "%.1f")
                                                                .font(theme.font(size: 11, weight: .bold))
                                                                .foregroundStyle(theme.accent)
                                                                .frame(width: 50, alignment: .trailing)

                                                            Text("/")
                                                                .font(.caption2)
                                                                .foregroundStyle(theme.secondary)

                                                            SlopNumberField("0", value: $kr.targetValue, format: "%.1f")
                                                                .font(theme.font(size: 11))
                                                                .foregroundStyle(theme.secondary)
                                                                .frame(width: 50, alignment: .leading)

                                                            SlopTextField("unit", text: $kr.unit)
                                                                .font(.caption2)
                                                                .foregroundStyle(theme.secondary)
                                                                .frame(width: 40)
                                                        }

                                                        Spacer()

                                                        MetricPill(
                                                            "\(Int(kr.progress * 100))%",
                                                            tint: kr.progress >= 1.0 ? .green : theme.accent
                                                        )
                                                    }

                                                    ProgressBar(
                                                        progress: kr.progress,
                                                        fillColor: kr.progress >= 1.0 ? .green : theme.accent,
                                                        backgroundColor: theme.surface,
                                                        height: 4
                                                    )
                                                }
                                                .padding(10)
                                                .background(theme.surface.opacity(0.5))
                                                .cornerRadius(6)
                                            }

                                            AddItemButton("Add Key Result") {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    objective.keyResults.append(KeyResult())
                                                }
                                            }
                                        }
                                        .padding(.leading, 12)
                                    }
                                }
                                .padding(14)
                                .background(theme.surface)
                                .cornerRadius(10)
                            }

                            AddItemButton("Add Objective") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    data.objectives.append(Objective())
                                }
                            }
                        }
                    }
                }

                Divider().background(theme.divider)

                // Summary
                VStack(spacing: 4) {
                    SummaryRow(
                        label: "Objectives",
                        value: "\(data.objectives.count)",
                        valueColor: theme.foreground
                    )

                    SummaryRow(
                        label: "Key Results",
                        value: "\(data.totalKeyResults)",
                        valueColor: theme.foreground
                    )

                    SummaryRow(
                        label: "Completed KRs",
                        value: "\(data.completedKeyResults)",
                        valueColor: theme.accent,
                        isBold: true
                    )
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }
}

