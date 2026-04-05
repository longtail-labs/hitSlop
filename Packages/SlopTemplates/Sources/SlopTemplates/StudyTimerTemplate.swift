import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct StudySession: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Subject") var subject: String = ""
    @Field("Duration") var duration: Double = 0
    @Field("Date") var date: Date = .now
}

extension StudyTimerData {
    static var defaultSessions: [StudySession] {
        func session(_ subject: String, _ duration: Double, _ year: Int, _ month: Int, _ day: Int) -> StudySession {
            var s = StudySession()
            s.subject = subject
            s.duration = duration
            s.date = makeDate(year, month, day)
            return s
        }
        return [
            session("Physics", 45, 2026, 4, 1),
            session("Chemistry", 60, 2026, 4, 2),
            session("Mathematics", 90, 2026, 4, 3)
        ]
    }

    private static func makeDate(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? .now
    }
}

@SlopData
public struct StudyTimerData {
    @SlopKit.Section("Timer")
    @Field("Subject") var subject: String = "Mathematics"
    @Field("Total Minutes") var totalMinutes: Double = 0

    @SlopKit.Section("History")
    @Field("Sessions") var sessions: [StudySession] = StudyTimerData.defaultSessions

    var totalHours: Double {
        sessions.reduce(0) { $0 + $1.duration } / 60.0
    }

    var sessionCount: Int {
        sessions.count
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.study-timer",
    name: "Study Timer",
    description: "Time your study sessions and track total hours by subject.",
    version: "1.0.0",
    width: 300, height: 360,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["education"]
)
struct StudyTimerView: View {
    @TemplateData var data: StudyTimerData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    @State private var startDate: Date?
    @State private var elapsedSeconds: Double = 0

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isRunning: Bool {
        startDate != nil
    }

    private var displayTime: String {
        let minutes = Int(elapsedSeconds) / 60
        let seconds = Int(elapsedSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Subject input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Subject")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)
                    SlopTextField("Enter subject", text: $data.subject)
                        .textFieldStyle(.plain)
                        .font(theme.bodyFont)
                        .foregroundColor(theme.foreground)
                        .padding(8)
                        .background(theme.surface)
                        .cornerRadius(8)
                }

                // Timer display
                VStack(spacing: 8) {
                    Text(displayTime)
                        .font(theme.mono(size: 56, weight: .bold))
                        .foregroundColor(isRunning ? theme.accent : theme.foreground)
                        .onReceive(ticker) { _ in
                            if let start = startDate {
                                elapsedSeconds = Date().timeIntervalSince(start)
                            }
                        }

                    Text(isRunning ? "Running..." : "Ready")
                        .font(theme.bodyFont)
                        .foregroundColor(theme.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

                // Controls (interactive only)
                if renderTarget == .interactive {
                    SlopInteractiveOnly {
                        HStack(spacing: 12) {
                            Button(action: toggleTimer) {
                                Text(isRunning ? "Pause" : "Start")
                                    .font(theme.bodyFont.weight(.semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(isRunning ? Color.orange : theme.accent)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)

                            Button(action: resetTimer) {
                                Text("Reset")
                                    .font(theme.bodyFont.weight(.semibold))
                                    .foregroundColor(theme.foreground)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(theme.surface)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()
                    .background(theme.divider)

                // Session history
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Sessions")
                        .font(theme.titleFont)
                        .foregroundColor(theme.foreground)

                    ForEach(data.sessions.suffix(5).reversed()) { session in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.subject)
                                    .font(theme.bodyFont)
                                    .foregroundColor(theme.foreground)
                                Text(session.date, style: .date)
                                    .font(theme.font(size: 10))
                                    .foregroundColor(theme.secondary)
                            }

                            Spacer()

                            Text("\(Int(session.duration))m")
                                .font(theme.bodyFont.monospacedDigit())
                                .foregroundColor(theme.accent)
                        }
                        .padding(8)
                        .background(theme.surface)
                        .cornerRadius(6)
                    }
                }

                // Summary stats
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(String(format: "%.1f", data.totalHours))h")
                            .font(theme.titleFont)
                            .foregroundColor(theme.accent)
                        Text("Total Hours")
                            .font(theme.font(size: 10))
                            .foregroundColor(theme.secondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(data.sessionCount)")
                            .font(theme.titleFont)
                            .foregroundColor(theme.accent)
                        Text("Sessions")
                            .font(theme.font(size: 10))
                            .foregroundColor(theme.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
        }
        .background(theme.background)
    }

    private func toggleTimer() {
        if isRunning {
            // Pause and save session
            if let start = startDate {
                let duration = Date().timeIntervalSince(start) / 60.0 // Convert to minutes
                if duration > 0.5 { // Only save if more than 30 seconds
                    var session = StudySession()
                    session.subject = data.subject
                    session.duration = duration
                    session.date = Date()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        data.sessions.append(session)
                        data.totalMinutes += duration
                    }
                }
            }
            startDate = nil
            elapsedSeconds = 0
        } else {
            // Start timer
            startDate = Date()
            elapsedSeconds = 0
        }
    }

    private func resetTimer() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            startDate = nil
            elapsedSeconds = 0
        }
    }
}
