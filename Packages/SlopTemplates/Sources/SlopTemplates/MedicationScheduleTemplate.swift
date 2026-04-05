import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct Medication: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Name") var name: String = ""
    @Field("Dosage") var dosage: String = ""
    @Field("Frequency", options: ["Daily", "Twice Daily", "Weekly", "As Needed"]) var frequency: String = "Daily"
    @Field("Time") var time: String = "8:00 AM"
    @Field("Color") var color: String = "#4A90D9"
    @Field("Notes") var notes: String = ""
    @Field("Taken") var taken: Bool = false
}

@SlopData
public struct MedicationScheduleData {
    @SlopKit.Section("Patient")
    @Field("Patient Name") var patientName: String = "My Medications"

    @SlopKit.Section("Medications")
    @Field("Medications") var medications: [Medication] = MedicationScheduleData.defaultMedications

    var takenCount: Int {
        medications.filter { $0.taken }.count
    }

    var totalCount: Int {
        medications.count
    }

    var adherenceRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(takenCount) / Double(totalCount)
    }
}

extension MedicationScheduleData {
    static var defaultMedications: [Medication] {
        func medication(_ name: String, _ dosage: String, _ frequency: String, _ time: String, _ color: String, _ notes: String) -> Medication {
            var m = Medication()
            m.name = name
            m.dosage = dosage
            m.frequency = frequency
            m.time = time
            m.color = color
            m.notes = notes
            return m
        }
        return [
            medication("Vitamin D", "1000 IU", "Daily", "8:00 AM", "#F39C12", "Take with breakfast"),
            medication("Ibuprofen", "200 mg", "As Needed", "12:00 PM", "#E74C3C", "For pain relief"),
            medication("Multivitamin", "1 tablet", "Daily", "8:00 AM", "#27AE60", ""),
            medication("Allergy Med", "10 mg", "Daily", "9:00 AM", "#9B59B6", "Seasonal allergies")
        ]
    }
}

@SlopTemplate(
    id: "com.hitslop.templates.medication-schedule",
    name: "Medication Schedule",
    description: "Keep track of medications, dosages, and daily intake.",
    version: "1.0.0",
    width: 380, height: 520,
    shape: .roundedRect(radius: 16),
    alwaysOnTop: true,
    categories: ["health"]
)
struct MedicationScheduleView: View {
    @TemplateData var data: MedicationScheduleData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        SlopContent {
            VStack(alignment: .leading, spacing: 16) {
                // Patient name header
                SlopTextField("Patient Name", text: $data.patientName)
                    .font(theme.titleFont)
                    .foregroundColor(theme.foreground)

                // Adherence summary
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(data.takenCount) of \(data.totalCount) taken")
                            .font(theme.bodyFont)
                            .foregroundColor(theme.secondary)

                        Spacer()

                        Text(String(format: "%.0f%%", data.adherenceRate * 100))
                            .font(theme.bodyFont.weight(.bold))
                            .foregroundColor(theme.accent)
                    }

                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(theme.divider)
                                .frame(height: 6)
                                .cornerRadius(3)

                            Rectangle()
                                .fill(theme.accent)
                                .frame(width: geometry.size.width * data.adherenceRate, height: 6)
                                .cornerRadius(3)
                        }
                    }
                    .frame(height: 6)
                }

                Rectangle()
                    .fill(theme.divider)
                    .frame(height: 1)

                // Medication list
                ForEach($data.medications) { $medication in
                    medicationCard(medication: $medication)
                }

                // Add medication button
                SlopInteractiveOnly {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            var newMed = Medication()
                            newMed.name = "New Medication"
                            newMed.dosage = ""
                            newMed.frequency = "Daily"
                            newMed.time = "8:00 AM"
                            newMed.color = "#4A90D9"
                            data.medications.append(newMed)
                        }
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Medication")
                        }
                        .font(theme.bodyFont)
                        .foregroundColor(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(24)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func medicationCard(medication: Binding<Medication>) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Color accent bar
            Rectangle()
                .fill(colorFromHex(medication.wrappedValue.color))
                .frame(width: 4)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        SlopTextField("Medication name", text: medication.name)
                            .font(theme.bodyFont.weight(.bold))
                            .foregroundColor(theme.foreground)

                        HStack(spacing: 8) {
                            SlopTextField("Dosage", text: medication.dosage)
                                .font(theme.bodyFont)
                                .foregroundColor(theme.secondary)

                            Text("•")
                                .foregroundColor(theme.divider)

                            Text(medication.wrappedValue.frequency)
                                .font(theme.bodyFont)
                                .foregroundColor(theme.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(theme.accent.opacity(0.1))
                                .cornerRadius(4)

                            Text("•")
                                .foregroundColor(theme.divider)

                            SlopTextField("Time", text: medication.time)
                                .font(theme.bodyFont)
                                .foregroundColor(theme.secondary)
                        }
                    }

                    Spacer()

                    // Taken status indicator
                    if medication.wrappedValue.taken {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(theme.font(size: 24))
                    } else if renderTarget != .interactive {
                        Image(systemName: "circle")
                            .foregroundColor(theme.divider)
                            .font(theme.font(size: 24))
                    }

                    // Interactive buttons
                    SlopInteractiveOnly {
                        HStack(spacing: 8) {
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    medication.wrappedValue.taken.toggle()
                                }
                            }) {
                                Image(systemName: medication.wrappedValue.taken ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(medication.wrappedValue.taken ? .green : theme.secondary)
                                    .font(theme.font(size: 24))
                            }
                            .buttonStyle(.plain)

                            ColorPicker("", selection: Binding(
                                get: { colorFromHex(medication.wrappedValue.color) },
                                set: { newColor in
                                    medication.wrappedValue.color = String(format: "#%02X%02X%02X",
                                        Int(newColor.components.red * 255),
                                        Int(newColor.components.green * 255),
                                        Int(newColor.components.blue * 255))
                                }
                            ))
                            .labelsHidden()
                            .frame(width: 24, height: 24)

                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    data.medications.removeAll { $0.id == medication.wrappedValue.id }
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !medication.wrappedValue.notes.isEmpty {
                    SlopTextField("Notes", text: medication.notes)
                        .font(theme.bodyFont.italic())
                        .foregroundColor(theme.secondary.opacity(0.8))
                        .padding(.top, 4)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 12)
        }
        .background(medication.wrappedValue.taken ? theme.surface.opacity(0.3) : theme.surface)
        .cornerRadius(8)
    }
}

// Helper extension for Color components
extension Color {
    var components: (red: Double, green: Double, blue: Double, opacity: Double) {
        #if canImport(AppKit)
        guard let nsColor = NSColor(self).usingColorSpace(.deviceRGB) else {
            return (0, 0, 0, 1)
        }
        return (
            Double(nsColor.redComponent),
            Double(nsColor.greenComponent),
            Double(nsColor.blueComponent),
            Double(nsColor.alphaComponent)
        )
        #else
        return (0, 0, 0, 1)
        #endif
    }
}
