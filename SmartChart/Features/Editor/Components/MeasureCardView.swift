import SwiftUI

struct MeasureCardView: View {
    @Binding var measure: Measure
    let meter: Meter
    let cues: [CueText]
    let transpositionView: TranspositionView
    let fontPreset: ChartFontPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("M\(measure.index)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(meter.displayText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(measure.chordEvents) { chordEvent in
                    let displayedEvent = chordEvent.transposed(for: transpositionView)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayedEvent.symbol.displayText)
                            .font(fontPreset.chordFont)

                        Text("\(displayedEvent.startPosition.displayText) · \(displayedEvent.duration.displayText)")
                            .font(fontPreset.cueFont)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if measure.chordEvents.isEmpty {
                    Button {
                        measure.addDemoChordEvent()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                                .font(.title3)

                            Text("Add demo hit")
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 72)
                    }
                    .buttonStyle(.plain)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [6]))
                    }
                }
            }

            let timingIssues = MeasureTimingValidator.issues(in: measure, defaultMeter: meter)
            if !timingIssues.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Timing Check")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)

                    ForEach(timingIssues) { issue in
                        Text(issue.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !cues.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(cues) { cue in
                        Text(cue.text)
                            .font(fontPreset.cueFont)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !measure.chordEvents.isEmpty {
                Button("Clear Measure") {
                    measure.chordEvents.removeAll()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(width: 200, alignment: .topLeading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
