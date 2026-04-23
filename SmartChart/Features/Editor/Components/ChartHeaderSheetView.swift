import SwiftUI

struct ChartHeaderSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var chart: Chart

    @State private var draftTitle: String
    @State private var draftComposerCredit: String
    @State private var draftStyleNote: String

    init(chart: Binding<Chart>) {
        self._chart = chart
        _draftTitle = State(initialValue: chart.wrappedValue.title)
        _draftComposerCredit = State(initialValue: chart.wrappedValue.composerCredit ?? "")
        _draftStyleNote = State(initialValue: chart.wrappedValue.styleNote ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Chart") {
                    TextField("Title", text: $draftTitle)
                    TextField("Composer / Credit", text: $draftComposerCredit)
                    TextField("Style Note", text: $draftStyleNote)
                }
            }
            .navigationTitle("Header")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        chart.title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Untitled Chart"
                            : draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        chart.composerCredit = normalizedText(draftComposerCredit)
                        chart.styleNote = normalizedText(draftStyleNote)
                        chart.updatedAt = .now
                        dismiss()
                    }
                }
            }
        }
    }

    private func normalizedText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
