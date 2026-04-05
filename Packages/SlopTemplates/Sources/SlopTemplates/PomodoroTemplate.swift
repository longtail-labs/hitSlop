import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct PomodoroChecklistItem: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Item") var title: String = ""
    @Field("Done") var isDone: Bool = false
}

@SlopData
public struct PomodoroData {
    @SlopKit.Section("Overview") @Field("Title") var title: String = "Pomodoro Timer"
    @Field("Current Task") var currentTask: String = "Finish export polish"
    @Field("Phase", options: ["Focus", "Break"]) var phase: String = "Focus"
    @Field("Focus Minutes") var focusMinutes: Double = 25
    @Field("Break Minutes") var breakMinutes: Double = 5
    @Field("Remaining Minutes") var remainingMinutes: Double = 14
    @Field("Remaining Seconds") var remainingSeconds: Double = 42
    @Field("Sessions Completed") var sessionsCompleted: Double = 3
    @Field("Target Sessions") var targetSessions: Double = 6
    @SlopKit.Section("Checklist") @Field("Checklist") var checklist: [PomodoroChecklistItem] = PomodoroData.defaultChecklist

    var totalSeconds: Double {
        (phase == "Focus" ? focusMinutes : breakMinutes) * 60
    }

    var remainingTotalSeconds: Double {
        (remainingMinutes * 60) + remainingSeconds
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return max(0, min(1, 1 - (remainingTotalSeconds / totalSeconds)))
    }

    var timerString: String {
        String(format: "%02d:%02d", Int(remainingMinutes), Int(remainingSeconds))
    }
}

extension PomodoroData {
    static var defaultChecklist: [PomodoroChecklistItem] {
        func item(_ title: String, _ done: Bool) -> PomodoroChecklistItem {
            var value = PomodoroChecklistItem()
            value.title = title
            value.isDone = done
            return value
        }

        return [
            item("Review export output", true),
            item("Fix theme regression", true),
            item("Write cleanup pass", false),
        ]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.pomodoro",
    name: "Pomodoro",
    description: "Run a simple focus timer with work sessions and break cycles.",
    version: "1.0.0",
    width: 360, height: 460,
    minWidth: 320, minHeight: 340,
    shape: .roundedRect(radius: 24),
    theme: "sunset",
    alwaysOnTop: true,
    categories: ["productivity"]
)
struct PomodoroView: View {
    @TemplateData var data: PomodoroData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget
    @State private var isRunning = false

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if renderTarget == .interactive {
                ScrollView(showsIndicators: false) { interactiveContent }
            } else {
                exportContent
            }
        }
        .background(theme.background)
        .onReceive(ticker) { _ in
            guard isRunning else { return }
            tick()
        }
    }

    private func tick() {
        if data.remainingSeconds > 0 {
            data.remainingSeconds -= 1
        } else if data.remainingMinutes > 0 {
            data.remainingMinutes -= 1
            data.remainingSeconds = 59
        } else {
            // Timer reached 0 — switch phase
            isRunning = false
            if data.phase == "Focus" {
                data.sessionsCompleted += 1
                data.phase = "Break"
                data.remainingMinutes = data.breakMinutes
            } else {
                data.phase = "Focus"
                data.remainingMinutes = data.focusMinutes
            }
            data.remainingSeconds = 0
        }
    }

    private func resetTimer() {
        isRunning = false
        let mins = data.phase == "Focus" ? data.focusMinutes : data.breakMinutes
        data.remainingMinutes = mins
        data.remainingSeconds = 0
    }

    private var interactiveContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Title", text: $data.title)
                        .font(theme.title(size: 22))
                        .foregroundStyle(theme.foreground)
                        .textFieldStyle(.plain)
                    TextField("Current task", text: $data.currentTask)
                        .foregroundStyle(theme.secondary)
                        .textFieldStyle(.plain)
                }
                Spacer()
                Picker("Phase", selection: $data.phase) {
                    Text("Focus").tag("Focus")
                    Text("Break").tag("Break")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 120)
                .onChange(of: data.phase) { _, _ in
                    resetTimer()
                }
            }

            VStack(spacing: 12) {
                Text(data.timerString)
                    .font(theme.title(size: 54))
                    .foregroundStyle(theme.foreground)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.surface)
                            .frame(height: 12)
                        Capsule()
                            .fill(theme.accent)
                            .frame(width: proxy.size.width * data.progress, height: 12)
                    }
                }
                .frame(height: 12)

                // Timer controls
                HStack(spacing: 16) {
                    Button {
                        isRunning.toggle()
                    } label: {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(theme.font(size: 22))
                            .foregroundStyle(theme.accent)
                            .frame(width: 48, height: 48)
                            .background(
                                Circle().fill(theme.accent.opacity(0.15))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        resetTimer()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(theme.font(size: 14, weight: .medium))
                            .foregroundStyle(theme.secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(theme.surface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("COMPLETED")
                        .font(theme.mono(size: 10, weight: .bold))
                        .foregroundStyle(theme.secondary)
                    TextField("0", value: $data.sessionsCompleted, format: .number)
                        .font(theme.title(size: 20))
                        .foregroundStyle(theme.foreground)
                        .textFieldStyle(.plain)
                        .frame(width: 50)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("TARGET")
                        .font(theme.mono(size: 10, weight: .bold))
                        .foregroundStyle(theme.secondary)
                    TextField("0", value: $data.targetSessions, format: .number)
                        .font(theme.title(size: 20))
                        .foregroundStyle(theme.foreground)
                        .textFieldStyle(.plain)
                        .frame(width: 50)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("FOCUS MIN")
                        .font(theme.mono(size: 10, weight: .bold))
                        .foregroundStyle(theme.secondary)
                    TextField("25", value: $data.focusMinutes, format: .number)
                        .font(theme.title(size: 20))
                        .foregroundStyle(theme.foreground)
                        .textFieldStyle(.plain)
                        .frame(width: 50)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 4) {
                    Text("BREAK MIN")
                        .font(theme.mono(size: 10, weight: .bold))
                        .foregroundStyle(theme.secondary)
                    TextField("5", value: $data.breakMinutes, format: .number)
                        .font(theme.title(size: 20))
                        .foregroundStyle(theme.foreground)
                        .textFieldStyle(.plain)
                        .frame(width: 50)
                }
            }

            Divider().background(theme.divider)

            VStack(alignment: .leading, spacing: 10) {
                Text("Session Checklist")
                    .font(theme.mono(size: 10, weight: .bold))
                    .foregroundStyle(theme.secondary)
                ForEach($data.checklist) { $item in
                    HStack(spacing: 10) {
                        Button {
                            withAnimation { item.isDone.toggle() }
                        } label: {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isDone ? theme.accent : theme.secondary)
                        }
                        .buttonStyle(.plain)
                        TextField("Item", text: $item.title)
                            .foregroundStyle(theme.foreground)
                            .textFieldStyle(.plain)
                        Button {
                            withAnimation { data.checklist.removeAll { $0.id == item.id } }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(theme.font(size: 12))
                                .foregroundStyle(theme.secondary.opacity(0.3))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    withAnimation { data.checklist.append(PomodoroChecklistItem()) }
                } label: {
                    Label("Add Item", systemImage: "plus")
                        .font(.caption)
                        .foregroundStyle(theme.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
    }

    private var exportContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(data.title)
                        .font(theme.title(size: 22))
                        .foregroundStyle(theme.foreground)
                    Text(data.currentTask)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(data.phase.uppercased())
                    .font(theme.mono(size: 10, weight: .bold))
                    .foregroundStyle(theme.background)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(theme.accent))
            }

            VStack(spacing: 12) {
                Text(data.timerString)
                    .font(theme.title(size: 54))
                    .foregroundStyle(theme.foreground)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(theme.surface)
                            .frame(height: 12)
                        Capsule()
                            .fill(theme.accent)
                            .frame(width: proxy.size.width * data.progress, height: 12)
                    }
                }
                .frame(height: 12)
            }

            HStack {
                metric("Completed", "\(Int(data.sessionsCompleted))")
                Spacer()
                metric("Target", "\(Int(data.targetSessions))")
            }

            Divider().background(theme.divider)

            VStack(alignment: .leading, spacing: 10) {
                Text("Session Checklist")
                    .font(theme.mono(size: 10, weight: .bold))
                    .foregroundStyle(theme.secondary)
                ForEach(data.checklist) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(item.isDone ? theme.accent : theme.secondary)
                        Text(item.title)
                            .foregroundStyle(theme.foreground)
                    }
                }
            }
        }
        .padding(24)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(theme.mono(size: 10, weight: .bold))
                .foregroundStyle(theme.secondary)
            Text(value)
                .font(theme.title(size: 20))
                .foregroundStyle(theme.foreground)
        }
    }
}

