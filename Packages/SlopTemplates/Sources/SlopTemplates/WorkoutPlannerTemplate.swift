import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct WorkoutSet: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Reps") var reps: Double = 10
    @Field("Weight") var weight: Double = 0
    @Field("Done") var done: Bool = false
}

@SlopData
public struct WorkoutExercise: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Sets") var sets: [WorkoutSet] = []

    var volume: Double {
        sets.reduce(0.0) { $0 + ($1.reps * $1.weight) }
    }

    var completedSets: Int {
        sets.filter { $0.done }.count
    }
}

@SlopData
public struct WorkoutPlannerData {
    @SlopKit.Section("Workout")
    @Field("Workout Name") var workoutName: String = "Push Day"
    @Field("Date") var date: Date = .now

    @SlopKit.Section("Exercises")
    @Field("Exercises") var exercises: [WorkoutExercise] = WorkoutPlannerData.defaultExercises

    var totalVolume: Double {
        exercises.reduce(0.0) { $0 + $1.volume }
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var completedSetsCount: Int {
        exercises.reduce(0) { $0 + $1.completedSets }
    }

    var completionPercentage: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSetsCount) / Double(totalSets) * 100.0
    }
}

extension WorkoutPlannerData {
    static var defaultExercises: [WorkoutExercise] {
        func set(_ reps: Double, _ weight: Double, _ done: Bool) -> WorkoutSet {
            var s = WorkoutSet()
            s.reps = reps
            s.weight = weight
            s.done = done
            return s
        }

        func exercise(_ name: String, _ sets: [WorkoutSet]) -> WorkoutExercise {
            var e = WorkoutExercise()
            e.name = name
            e.sets = sets
            return e
        }

        return [
            exercise("Bench Press", [
                set(10, 135, true),
                set(8, 155, true),
                set(6, 175, false)
            ]),
            exercise("Overhead Press", [
                set(10, 95, true),
                set(8, 105, false),
                set(6, 115, false)
            ]),
            exercise("Dips", [
                set(12, 0, true),
                set(10, 25, false),
                set(8, 45, false)
            ])
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.workout-planner",
    name: "Workout Planner",
    description: "Log exercises, sets, and reps to track your training volume.",
    version: "1.0.0",
    width: 400, height: 600,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["health"]
)
struct WorkoutPlannerView: View {
    @TemplateData var data: WorkoutPlannerData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Header Section
                VStack(alignment: .leading, spacing: 8) {
                    SlopTextField("Workout Name", text: $data.workoutName)
                        .font(theme.titleFont)
                        .foregroundStyle(theme.foreground)

                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .foregroundStyle(theme.secondary)
                        SlopEditable($data.date) { value in
                            Text(value, style: .date)
                                .font(theme.bodyFont)
                                .foregroundStyle(theme.secondary)
                        } editor: { $value in
                            DatePicker("", selection: $value, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                }

                // Stats Row
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Volume")
                            .font(.caption)
                            .foregroundStyle(theme.secondary)
                        Text(formatVolume(data.totalVolume))
                            .font(.headline)
                            .foregroundStyle(theme.accent)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sets")
                            .font(.caption)
                            .foregroundStyle(theme.secondary)
                        Text("\(data.completedSetsCount) / \(data.totalSets)")
                            .font(.headline)
                            .foregroundStyle(theme.foreground)
                    }

                    Spacer()
                }

                // Progress Bar
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(theme.surface)
                                .frame(height: 8)
                                .clipShape(Capsule())

                            Rectangle()
                                .fill(theme.accent)
                                .frame(width: geometry.size.width * CGFloat(data.completionPercentage / 100.0), height: 8)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(height: 8)

                    Text("\(Int(data.completionPercentage))% complete")
                        .font(.caption2)
                        .foregroundStyle(theme.secondary)
                }

                Rectangle()
                    .fill(theme.divider)
                    .frame(height: 1)

                // Exercises Section
                ForEach($data.exercises) { $exercise in
                    ExerciseSection(exercise: $exercise, theme: theme, renderTarget: renderTarget, onRemove: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            data.exercises.removeAll { $0.id == exercise.id }
                        }
                    })
                }

                SlopInteractiveOnly {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            var newExercise = WorkoutExercise()
                            newExercise.name = "New Exercise"
                            newExercise.sets = [WorkoutSet()]
                            data.exercises.append(newExercise)
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                        }
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                }

                Rectangle()
                    .fill(theme.divider)
                    .frame(height: 1)

                // Summary Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.headline)
                        .foregroundStyle(theme.foreground)

                    HStack {
                        Text("Total Volume:")
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.secondary)
                        Spacer()
                        Text(formatVolume(data.totalVolume))
                            .font(theme.bodyFont)
                            .fontWeight(.medium)
                            .foregroundStyle(theme.foreground)
                    }

                    HStack {
                        Text("Completion:")
                            .font(theme.bodyFont)
                            .foregroundStyle(theme.secondary)
                        Spacer()
                        Text("\(Int(data.completionPercentage))%")
                            .font(theme.bodyFont)
                            .fontWeight(.medium)
                            .foregroundStyle(theme.foreground)
                    }
                }
                .padding(12)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(24)
        }
        .background(theme.background)
    }

    private func formatVolume(_ volume: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: volume)) ?? "\(Int(volume))"
    }
}

struct ExerciseSection: View {
    @Binding var exercise: WorkoutExercise
    let theme: SlopTheme
    let renderTarget: SlopRenderTarget
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise Header
            HStack {
                SlopTextField("Exercise name", text: $exercise.name)
                    .font(.headline)
                    .foregroundStyle(theme.foreground)

                Spacer()

                SlopInteractiveOnly {
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .foregroundStyle(theme.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Sets Table Header
            HStack(spacing: 8) {
                Text("Set")
                    .font(.caption)
                    .foregroundStyle(theme.secondary)
                    .frame(width: 40, alignment: .leading)

                Text("Reps")
                    .font(.caption)
                    .foregroundStyle(theme.secondary)
                    .frame(width: 60, alignment: .center)

                Text("Weight")
                    .font(.caption)
                    .foregroundStyle(theme.secondary)
                    .frame(width: 70, alignment: .center)

                Spacer()

                Text("Done")
                    .font(.caption)
                    .foregroundStyle(theme.secondary)
                    .frame(width: 50, alignment: .center)
            }
            .padding(.horizontal, 8)

            // Sets Rows
            ForEach(Array($exercise.sets.enumerated()), id: \.element.id) { index, $set in
                SetRow(setNumber: index + 1, set: $set, theme: theme, renderTarget: renderTarget, onRemove: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        exercise.sets.removeAll { $0.id == set.id }
                    }
                })
            }

            // Add Set Button
            SlopInteractiveOnly {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        exercise.sets.append(WorkoutSet())
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Set")
                    }
                    .font(.caption)
                    .foregroundStyle(theme.accent)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }

            // Volume Subtotal
            HStack {
                Text("Volume:")
                    .font(.caption)
                    .foregroundStyle(theme.secondary)
                Spacer()
                Text(formatVolume(exercise.volume))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 8)
        }
        .padding(12)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatVolume(_ volume: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: volume)) ?? "\(Int(volume))"
    }
}

struct SetRow: View {
    let setNumber: Int
    @Binding var set: WorkoutSet
    let theme: SlopTheme
    let renderTarget: SlopRenderTarget
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(setNumber)")
                .font(.caption)
                .foregroundStyle(theme.secondary)
                .frame(width: 40, alignment: .leading)

            SlopNumberField("0", value: $set.reps)
                .font(.caption)
                .foregroundStyle(theme.foreground)
                .frame(width: 60)
                .multilineTextAlignment(.center)

            HStack(spacing: 2) {
                SlopNumberField("0", value: $set.weight)
                    .font(.caption)
                    .foregroundStyle(theme.foreground)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                Text("lb")
                    .font(.caption2)
                    .foregroundStyle(theme.secondary)
            }
            .frame(width: 70)

            Spacer()

            SlopInteractiveOnly {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        set.done.toggle()
                    }
                }) {
                    Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(set.done ? .green : theme.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 50, alignment: .center)
            }

            if renderTarget != .interactive {
                Image(systemName: set.done ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(set.done ? .green : theme.secondary)
                    .frame(width: 50, alignment: .center)
            }

            SlopInteractiveOnly {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(theme.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(theme.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
