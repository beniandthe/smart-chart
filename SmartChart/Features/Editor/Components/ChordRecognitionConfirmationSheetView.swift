import SwiftUI

struct ChordRecognitionConfirmationSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let confirmation: ChordRecognitionProposal
    let supportedMatches: [ChordRecognitionMatch]
    let onUseSuggestedChord: () -> Void
    let onUseChord: (ChordRecognitionMatch) -> Void
    let onKeepEditing: () -> Void

    private let chordGridColumns = [
        GridItem(.adaptive(minimum: 54), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Measure \(confirmation.displayMeasureNumber)")
                            .font(.title3.weight(.semibold))
                        Text("This read is plausible but not strong enough to auto-place. Use the suggestion, pick the right chord, or keep editing the ink.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Suggested")
                                .font(.headline)
                            Spacer()
                            Text("\(Int((confirmation.confidence * 100).rounded()))%")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            onUseSuggestedChord()
                            dismiss()
                        } label: {
                            HStack {
                                Text(confirmation.symbol.displayText)
                                    .font(.title2.weight(.bold))
                                Spacer()
                                Text("Use This Chord")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose Instead")
                            .font(.headline)

                        LazyVGrid(columns: chordGridColumns, spacing: 8) {
                            ForEach(supportedMatches, id: \.displayText) { match in
                                Button {
                                    onUseChord(match)
                                    dismiss()
                                } label: {
                                    Text(match.displayText)
                                        .font(.subheadline.weight(.bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Confirm Chord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep Editing") {
                        onKeepEditing()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(470), .medium, .large])
        .presentationContentInteraction(.scrolls)
    }
}
