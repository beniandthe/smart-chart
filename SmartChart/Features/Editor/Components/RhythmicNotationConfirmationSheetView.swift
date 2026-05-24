import SwiftUI

struct PendingRhythmicNotationConfirmation: Identifiable {
    let id = UUID()
    let measureID: UUID
    let measureIndex: Int
    let meter: Meter
    let values: [RhythmValue]
    let drawingData: Data

    var displayMeasureNumber: Int {
        measureIndex + 1
    }

    var requiredBeatCount: Double {
        meter.measureLengthInWholeNotes / meter.beatUnitWholeNoteLength
    }

    var recognizedBeatCount: Double {
        values.reduce(0) { partialResult, value in
            partialResult + value.wholeNoteLength / meter.beatUnitWholeNoteLength
        }
    }
}

struct RhythmicNotationConfirmationSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let confirmation: PendingRhythmicNotationConfirmation
    let onAccept: () -> Void
    let onRewrite: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Measure \(confirmation.displayMeasureNumber)")
                        .font(.title3.weight(.semibold))
                    Text("The app read your handwriting as this rhythm. Accept it if it is right, or keep editing the ink in the measure.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Read as")
                            .font(.headline)
                        Spacer()
                        Text("\(formattedBeats(confirmation.recognizedBeatCount)) / \(formattedBeats(confirmation.requiredBeatCount)) beats")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    FlowLayout(spacing: 8, rowSpacing: 8) {
                        ForEach(Array(confirmation.values.enumerated()), id: \.offset) { _, value in
                            Text(value.confirmationLabel)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(value.isRest ? Color.orange.opacity(0.15) : Color.blue.opacity(0.13))
                                .foregroundStyle(value.isRest ? Color.orange : Color.blue)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(spacing: 10) {
                    Button {
                        onAccept()
                        dismiss()
                    } label: {
                        Text("Use This Rhythm")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        onRewrite()
                        dismiss()
                    } label: {
                        Text("Clear Measure & Rewrite")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer(minLength: 0)
            }
            .padding(24)
            .navigationTitle("Confirm Rhythm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep Editing") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(420), .medium])
    }

    private func formattedBeats(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.0001 {
            return String(Int(value.rounded()))
        }

        return String(format: "%.1f", value)
    }
}

private extension RhythmValue {
    var confirmationLabel: String {
        switch self {
        case .slash:
            return "slash"
        case .eighth:
            return "eighth"
        case .eighthRest:
            return "eighth rest"
        case .quarter:
            return "quarter"
        case .quarterRest:
            return "quarter rest"
        case .dottedQuarter:
            return "dotted quarter"
        case .half:
            return "half"
        case .halfRest:
            return "half rest"
        case .dottedHalf:
            return "dotted half"
        case .whole:
            return "whole"
        case .wholeRest:
            return "whole rest"
        case .tiedContinuation:
            return "tie"
        }
    }
}
