import Foundation

enum ChartTransposer {
    static func transposedChart(_ chart: Chart, for view: TranspositionView) -> Chart {
        var copy = chart
        copy.defaultTranspositionView = view
        copy.systems = chart.systems.map { system in
            var systemCopy = system
            systemCopy.measures = system.measures.map { measure in
                var measureCopy = measure
                measureCopy.chordEvents = measure.chordEvents.map { $0.transposed(for: view) }
                return measureCopy
            }
            return systemCopy
        }
        copy.updatedAt = .now
        return copy
    }
}
