import SwiftUI

struct RhythmicNotationAcceptanceSheetView: View {
    @State private var selectedPrimitive: RhythmicNotationPrimitive = RhythmicNotationPrimitive.supportedUniversalGuidePrimitives.first ?? .quarterNote

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                List {
                    Section("Supported Now") {
                        ForEach(RhythmicNotationPrimitive.supportedUniversalGuidePrimitives) { primitive in
                            Button {
                                selectedPrimitive = primitive
                            } label: {
                                HStack(spacing: 12) {
                                    Text(primitive.shortLabel)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(Color(red: 0.15, green: 0.33, blue: 0.64))
                                        .frame(width: 34, height: 34)
                                        .background(Color(red: 0.90, green: 0.95, blue: 1.0))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(primitive.displayTitle)
                                            .foregroundStyle(.primary)
                                        Text("Universal guide defined")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.green)
                                }
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(
                                selectedPrimitive == primitive
                                ? Color(red: 0.92, green: 0.96, blue: 1.0)
                                : Color.clear
                            )
                        }
                    }

                    if !RhythmicNotationPrimitive.pendingUniversalGuidePrimitives.isEmpty {
                        Section("Pending Guide") {
                            ForEach(RhythmicNotationPrimitive.pendingUniversalGuidePrimitives) { primitive in
                                HStack(spacing: 12) {
                                    Text(primitive.shortLabel)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 34, height: 34)
                                        .background(Color(red: 0.95, green: 0.95, blue: 0.93))
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(primitive.displayTitle)
                                        Text("Guide not defined from reference set yet")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "clock")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 360)
                .listStyle(.insetGrouped)

                Divider()

                if let guide = selectedPrimitive.universalGuide {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(guide.primitive.displayTitle)
                                .font(.title2.weight(.semibold))
                            Text(guide.acceptanceSummary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        guideSection(
                            title: "Must Contain",
                            color: Color(red: 0.89, green: 0.95, blue: 0.90),
                            items: guide.mustContain
                        )

                        guideSection(
                            title: "Accepted Variations",
                            color: Color(red: 0.93, green: 0.95, blue: 1.0),
                            items: guide.allowedVariations
                        )

                        guideSection(
                            title: "Reject When",
                            color: Color(red: 0.99, green: 0.93, blue: 0.92),
                            items: guide.rejectWhen
                        )

                        Spacer(minLength: 0)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ContentUnavailableView(
                        "Guide Pending",
                        systemImage: "clock",
                        description: Text("This rhythm symbol has not been defined in the built-in universal guide yet.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Universal Rhythm Guide")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func guideSection(title: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 6, height: 6)
                            .padding(.top, 7)

                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
