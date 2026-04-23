import SwiftUI

struct ChartSetupSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var chart: Chart

    @State private var draftKey: DocumentKey
    @State private var numerator: Int
    @State private var denominator: Int

    init(chart: Binding<Chart>) {
        self._chart = chart
        _draftKey = State(initialValue: chart.wrappedValue.documentKey)
        _numerator = State(initialValue: chart.wrappedValue.defaultMeter.numerator)
        _denominator = State(initialValue: chart.wrappedValue.defaultMeter.denominator)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    keySection
                    meterSection
                    notationSection
                }
                .padding(24)
            }
            .navigationTitle(chart.hasCompletedInitialSetup ? "Page Setup" : "New Chart")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(!chart.hasCompletedInitialSetup)
            .toolbar {
                if chart.hasCompletedInitialSetup {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(chart.hasCompletedInitialSetup ? "Apply" : "Create Blank Page") {
                        chart.completeInitialSetup(
                            title: chart.title,
                            key: draftKey,
                            meter: Meter(numerator: numerator, denominator: denominator),
                            staffStyle: .fiveLine
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(DocumentKey.commonCreationKeys, id: \.self) { key in
                    Button {
                        draftKey = key
                    } label: {
                        Text(key.displayText)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(draftKey == key ? .blue : .secondary.opacity(0.3))
                }
            }
        }
    }

    private var meterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Signature")
                .font(.headline)

            HStack(spacing: 14) {
                Stepper(value: $numerator, in: 1...12) {
                    Text("\(numerator)")
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .frame(minWidth: 32)
                }

                Text("/")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                Picker("Denominator", selection: $denominator) {
                    ForEach([2, 4, 8, 16], id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var notationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notation")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Jazz Chord Notation")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text("Locked for now so the whole app stays focused on one real-book style page workflow.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
