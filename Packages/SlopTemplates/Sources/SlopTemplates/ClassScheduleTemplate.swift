import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct ClassEntry: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Professor") var professor: String = ""
    @Field("Room") var room: String = ""
    @Field("Day", options: ["Mon", "Tue", "Wed", "Thu", "Fri"]) var day: String = "Mon"
    @Field("Start Hour") var startHour: Double = 9
    @Field("End Hour") var endHour: Double = 10
    @Field("Color") var color: String = "#4A90D9"
}

extension ClassScheduleData {
    static var defaultClasses: [ClassEntry] {
        func classEntry(_ name: String, _ professor: String, _ room: String, _ day: String, _ startHour: Double, _ endHour: Double, _ color: String) -> ClassEntry {
            var entry = ClassEntry()
            entry.name = name
            entry.professor = professor
            entry.room = room
            entry.day = day
            entry.startHour = startHour
            entry.endHour = endHour
            entry.color = color
            return entry
        }
        return [
            classEntry("Computer Science 101", "Dr. Smith", "Building A-201", "Mon", 9, 10.5, "#4A90D9"),
            classEntry("Mathematics", "Prof. Johnson", "Building B-105", "Tue", 10, 11.5, "#E74C3C"),
            classEntry("Physics", "Dr. Williams", "Science Lab 3", "Wed", 13, 15, "#2ECC71"),
            classEntry("History", "Prof. Davis", "Building C-301", "Thu", 14, 15.5, "#F39C12")
        ]
    }
}

@SlopData
public struct ClassScheduleData {
    @SlopKit.Section("Schedule")
    @Field("Title") var title: String = "My Schedule"
    @Field("Semester") var semester: String = "Fall 2026"
    @Field("Classes") var classes: [ClassEntry] = ClassScheduleData.defaultClasses

    var totalCredits: Int {
        classes.count
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.class-schedule",
    name: "Class Schedule",
    description: "View your weekly class timetable in a clean grid layout.",
    version: "1.0.0",
    width: 520, height: 600,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["education"]
)
struct ClassScheduleView: View {
    @TemplateData var data: ClassScheduleData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    @State private var draggedClassId: String?
    @State private var dragOffset: CGSize = .zero

    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri"]
    private let startHour = 8
    private let endHour = 18
    private let hourHeight: CGFloat = 60

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    SlopTextField("Schedule Title", text: $data.title)
                        .font(theme.titleFont)
                        .foregroundColor(theme.foreground)

                    SlopTextField("Semester", text: $data.semester)
                        .font(.subheadline)
                        .foregroundColor(theme.secondary)
                }

                // Weekly grid
                scheduleGrid

                // Class list and controls
                SlopInteractiveOnly {
                    VStack(alignment: .leading, spacing: 12) {
                        Divider()
                            .background(theme.divider)

                        HStack {
                            Text("Classes (\(data.totalCredits))")
                                .font(.headline)
                                .foregroundColor(theme.foreground)

                            Spacer()

                            Button(action: addClass) {
                                Label("Add Class", systemImage: "plus.circle.fill")
                                    .font(theme.bodyFont)
                                    .foregroundColor(theme.accent)
                            }
                            .buttonStyle(.plain)
                        }

                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(Array(data.classes.enumerated()), id: \.element.id) { index, classEntry in
                                    classListRow(classEntry: classEntry, index: index)
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private var scheduleGrid: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
                Text("")
                    .frame(width: 60)

                ForEach(days, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(theme.foreground)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)

            // Grid with time slots
            GeometryReader { geometry in
                let dayWidth = (geometry.size.width - 60) / CGFloat(days.count)

                ZStack(alignment: .topLeading) {
                    // Background grid lines
                    VStack(spacing: 0) {
                        ForEach(startHour..<endHour, id: \.self) { hour in
                            HStack(spacing: 0) {
                                Text(formatHour(hour))
                                    .font(.caption2)
                                    .foregroundColor(theme.secondary)
                                    .frame(width: 60, alignment: .trailing)
                                    .padding(.trailing, 8)

                                Rectangle()
                                    .fill(theme.divider.opacity(0.3))
                                    .frame(height: 1)
                            }
                            .frame(height: hourHeight)
                        }
                    }

                    // Vertical day dividers
                    HStack(spacing: 0) {
                        Color.clear.frame(width: 60)
                        ForEach(0..<days.count, id: \.self) { index in
                            Rectangle()
                                .fill(theme.divider.opacity(0.2))
                                .frame(width: 1)
                            if index < days.count - 1 {
                                Color.clear.frame(width: dayWidth - 1)
                            }
                        }
                    }

                    // Class blocks
                    ForEach(data.classes) { classEntry in
                        if let dayIndex = days.firstIndex(of: classEntry.day) {
                            classBlock(classEntry: classEntry, dayIndex: dayIndex, dayWidth: dayWidth)
                                .opacity(draggedClassId == classEntry.id ? 0.6 : 1.0)
                                .offset(draggedClassId == classEntry.id ? dragOffset : .zero)
                                .zIndex(draggedClassId == classEntry.id ? 10 : 0)
                                .gesture(
                                    renderTarget == .interactive ?
                                    DragGesture(coordinateSpace: .named("scheduleGrid"))
                                        .onChanged { value in
                                            draggedClassId = classEntry.id
                                            dragOffset = value.translation
                                        }
                                        .onEnded { value in
                                            applyDrag(classId: classEntry.id, translation: value.translation, dayWidth: dayWidth)
                                            draggedClassId = nil
                                            dragOffset = .zero
                                        }
                                    : nil
                                )
                        }
                    }
                }
            }
            .frame(height: CGFloat(endHour - startHour) * hourHeight)
            .coordinateSpace(name: "scheduleGrid")
        }
        .padding(12)
        .background(theme.surface)
        .cornerRadius(12)
    }

    @ViewBuilder
    private func classBlock(classEntry: ClassEntry, dayIndex: Int, dayWidth: CGFloat) -> some View {
        let xOffset = 60 + CGFloat(dayIndex) * dayWidth + 4
        let yOffset = (classEntry.startHour - Double(startHour)) * Double(hourHeight)
        let height = (classEntry.endHour - classEntry.startHour) * Double(hourHeight) - 4

        VStack(alignment: .leading, spacing: 2) {
            Text(classEntry.name)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(2)

            Text(classEntry.room)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
        }
        .padding(6)
        .frame(width: dayWidth - 8, height: CGFloat(height), alignment: .topLeading)
        .background(colorFromHex(classEntry.color))
        .cornerRadius(6)
        .offset(x: xOffset, y: CGFloat(yOffset))
    }

    @ViewBuilder
    private func classListRow(classEntry: ClassEntry, index: Int) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(colorFromHex(classEntry.color))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(classEntry.name)
                    .font(.caption)
                    .foregroundColor(theme.foreground)

                Text("\(classEntry.day) \(formatHour(Int(classEntry.startHour)))-\(formatHour(Int(classEntry.endHour))) • \(classEntry.room)")
                    .font(.caption2)
                    .foregroundColor(theme.secondary)
            }

            Spacer()

            Button(action: {
                removeClass(at: index)
            }) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(theme.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(theme.surface)
        .cornerRadius(6)
    }

    private func formatHour(_ hour: Int) -> String {
        let hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        let period = hour >= 12 ? "PM" : "AM"
        return "\(hour12)\(period)"
    }

    private func addClass() {
        var newClass = ClassEntry()
        newClass.name = "New Class"
        newClass.professor = "Professor"
        newClass.room = "Room"
        newClass.day = "Mon"
        newClass.startHour = 9
        newClass.endHour = 10
        newClass.color = "#4A90D9"
        data.classes.append(newClass)
    }

    private func removeClass(at index: Int) {
        guard data.classes.indices.contains(index) else { return }
        data.classes.remove(at: index)
    }

    private func applyDrag(classId: String, translation: CGSize, dayWidth: CGFloat) {
        guard let idx = data.classes.firstIndex(where: { $0.id == classId }) else { return }
        let classEntry = data.classes[idx]
        let duration = classEntry.endHour - classEntry.startHour

        // Calculate day offset
        let dayShift = Int((translation.width / dayWidth).rounded())
        guard let currentDayIdx = days.firstIndex(of: classEntry.day) else { return }
        let newDayIdx = min(max(currentDayIdx + dayShift, 0), days.count - 1)

        // Calculate hour offset
        let hourShift = translation.height / hourHeight
        let newStart = (classEntry.startHour + hourShift)
        // Snap to half-hour
        let snappedStart = (newStart * 2).rounded() / 2
        let clampedStart = min(max(snappedStart, Double(startHour)), Double(endHour) - duration)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            data.classes[idx].day = days[newDayIdx]
            data.classes[idx].startHour = clampedStart
            data.classes[idx].endHour = clampedStart + duration
        }
    }
}
