import Foundation

struct StrokeClustererConfiguration: Hashable {
    var maxTimeGap: TimeInterval
    var maxHorizontalGapRatio: Double
    var maxVerticalOverlapMissRatio: Double
    var smallModifierSizeRatio: Double

    static let chordSymbols = StrokeClustererConfiguration(
        maxTimeGap: 0.35,
        maxHorizontalGapRatio: 0.18,
        maxVerticalOverlapMissRatio: 0.18,
        smallModifierSizeRatio: 0.20
    )
}

struct StrokeClusterer {
    var configuration: StrokeClustererConfiguration

    init(configuration: StrokeClustererConfiguration = .chordSymbols) {
        self.configuration = configuration
    }

    func cluster(_ strokes: [InkStroke]) -> [InkCluster] {
        var workingClusters = strokes.enumerated().map { index, stroke in
            MutableInkCluster(strokes: [stroke], originalIndexes: [index])
        }

        var didMerge = true
        while didMerge {
            didMerge = false
            mergeLoop: for lhsIndex in workingClusters.indices {
                for rhsIndex in workingClusters.indices where rhsIndex > lhsIndex {
                    guard shouldMerge(workingClusters[lhsIndex], workingClusters[rhsIndex]) else {
                        continue
                    }

                    let mergedCluster = workingClusters[lhsIndex].merged(with: workingClusters[rhsIndex])
                    workingClusters[lhsIndex] = mergedCluster
                    workingClusters.remove(at: rhsIndex)
                    didMerge = true
                    break mergeLoop
                }
            }
        }

        return workingClusters
            .sorted { lhs, rhs in
                if lhs.bounds.minX != rhs.bounds.minX {
                    return lhs.bounds.minX < rhs.bounds.minX
                }

                if lhs.bounds.minY != rhs.bounds.minY {
                    return lhs.bounds.minY < rhs.bounds.minY
                }

                return (lhs.originalIndexes.min() ?? 0) < (rhs.originalIndexes.min() ?? 0)
            }
            .map { cluster in
                InkCluster(strokes: cluster.strokes)
            }
    }

    private func shouldMerge(_ lhs: MutableInkCluster, _ rhs: MutableInkCluster) -> Bool {
        guard !lhs.isSlashLikeSeparator,
              !rhs.isSlashLikeSeparator,
              timingAllowsMerge(lhs, rhs) else {
            return false
        }

        guard !shouldKeepSeparateAsRightSideModifier(lhs, rhs) else {
            return false
        }

        let horizontalGap = lhs.bounds.horizontalGap(to: rhs.bounds)
        let verticalMiss = lhs.bounds.verticalMiss(to: rhs.bounds)
        let referenceHeight = max(lhs.bounds.height, rhs.bounds.height, 1)
        let referenceWidth = max(lhs.bounds.width, rhs.bounds.width, 1)
        let smallModifierTightening = hasSmallModifier(lhs, rhs) ? 0.75 : 1.0

        let maxHorizontalGap = max(
            2,
            referenceHeight * configuration.maxHorizontalGapRatio * smallModifierTightening
        )
        let maxVerticalMiss = max(
            2,
            referenceWidth * configuration.maxVerticalOverlapMissRatio
        )
        let overlappingGlyphStrokeVerticalMiss = horizontalGap == 0 ? 4.0 : maxVerticalMiss

        return horizontalGap <= maxHorizontalGap
            && verticalMiss <= overlappingGlyphStrokeVerticalMiss
    }

    private func timingAllowsMerge(_ lhs: MutableInkCluster, _ rhs: MutableInkCluster) -> Bool {
        guard let lhsEnd = lhs.endTimeOffset,
              let rhsStart = rhs.startTimeOffset else {
            return true
        }

        let forwardGap = rhsStart - lhsEnd
        if forwardGap >= 0 {
            return forwardGap <= configuration.maxTimeGap
        }

        guard let rhsEnd = rhs.endTimeOffset,
              let lhsStart = lhs.startTimeOffset else {
            return true
        }

        let reverseGap = lhsStart - rhsEnd
        return reverseGap <= configuration.maxTimeGap
    }

    private func hasSmallModifier(_ lhs: MutableInkCluster, _ rhs: MutableInkCluster) -> Bool {
        let smallerArea = min(lhs.bounds.recognitionArea, rhs.bounds.recognitionArea)
        let largerArea = max(lhs.bounds.recognitionArea, rhs.bounds.recognitionArea)
        guard largerArea > 0 else {
            return false
        }

        return smallerArea / largerArea <= configuration.smallModifierSizeRatio
    }

    private func shouldKeepSeparateAsRightSideModifier(
        _ lhs: MutableInkCluster,
        _ rhs: MutableInkCluster
    ) -> Bool {
        isRightSideModifier(lhs, attachedTo: rhs)
            || isRightSideModifier(rhs, attachedTo: lhs)
    }

    private func isRightSideModifier(
        _ modifier: MutableInkCluster,
        attachedTo root: MutableInkCluster
    ) -> Bool {
        let rootArea = root.bounds.recognitionArea
        let modifierArea = modifier.bounds.recognitionArea
        guard root.isRootBodyCandidate,
              modifier.isAccidentalModifierCandidate else {
            return false
        }

        let rootWidth = max(root.bounds.width, 1)
        let rootHeight = max(root.bounds.height, 1)
        let horizontalGap = root.bounds.horizontalGap(to: modifier.bounds)
        let verticalMiss = root.bounds.verticalMiss(to: modifier.bounds)
        let clearlyDetachedToRight = modifier.bounds.minX >= root.bounds.maxX + max(1, rootWidth * 0.04)
        guard rootArea >= modifierArea * 1.2
                || (clearlyDetachedToRight && rootArea >= modifierArea * 0.60) else {
            return false
        }

        let startsAfterRootBody = modifier.bounds.minX >= root.bounds.maxX - max(2, rootWidth * 0.08)
        let closeEnoughToBelongToThisChord = horizontalGap <= rootHeight * 0.45
            && verticalMiss <= rootHeight * 0.55
        let modifierSized = modifierArea / rootArea <= 0.72
            || modifier.bounds.width <= rootWidth * 0.85
            || clearlyDetachedToRight

        return startsAfterRootBody && closeEnoughToBelongToThisChord && modifierSized
    }
}

private struct MutableInkCluster: Hashable {
    var strokes: [InkStroke]
    var originalIndexes: [Int]

    var bounds: InkBounds {
        InkBounds.enclosing(strokes.map(\.bounds))
    }

    var startTimeOffset: TimeInterval? {
        strokes
            .flatMap(\.points)
            .compactMap(\.timeOffset)
            .min()
    }

    var endTimeOffset: TimeInterval? {
        strokes
            .flatMap(\.points)
            .compactMap(\.timeOffset)
            .max()
    }

    var isRootBodyCandidate: Bool {
        bounds.width >= 8
            && bounds.height >= 16
            && bounds.recognitionArea >= 220
    }

    var isAccidentalModifierCandidate: Bool {
        bounds.width >= 1
            && (bounds.height >= 4 || bounds.width >= 8)
            && bounds.recognitionArea >= 4
            && strokes.count <= 6
    }

    var isSlashLikeSeparator: Bool {
        guard strokes.count == 1,
              let firstPoint = strokes[0].points.first,
              let lastPoint = strokes[0].points.last else {
            return false
        }

        let bounds = strokes[0].bounds
        let width = max(bounds.width, 1)
        let height = max(bounds.height, 1)
        let slopeMagnitude = height / width
        let dx = lastPoint.x - firstPoint.x
        let dy = lastPoint.y - firstPoint.y

        return slopeMagnitude >= 0.65
            && slopeMagnitude <= 4.0
            && strokes[0].straightness >= 0.72
            && dx * dy < 0
            && width >= 4
            && height >= 8
    }

    func merged(with other: MutableInkCluster) -> MutableInkCluster {
        MutableInkCluster(
            strokes: strokes + other.strokes,
            originalIndexes: originalIndexes + other.originalIndexes
        )
    }
}

private extension InkBounds {
    var recognitionArea: Double {
        max(width, 1) * max(height, 1)
    }

    func horizontalGap(to other: InkBounds) -> Double {
        if maxX < other.minX {
            return other.minX - maxX
        }

        if other.maxX < minX {
            return minX - other.maxX
        }

        return 0
    }

    func verticalMiss(to other: InkBounds) -> Double {
        if maxY < other.minY {
            return other.minY - maxY
        }

        if other.maxY < minY {
            return minY - other.maxY
        }

        return 0
    }
}

private extension InkStroke {
    var straightness: Double {
        guard let firstPoint = points.first,
              let lastPoint = points.last else {
            return 0
        }

        let pathLength = zip(points, points.dropFirst())
            .map { start, end in
                start.clusterDistance(to: end)
            }
            .reduce(0, +)
        guard pathLength > 0 else {
            return 0
        }

        return firstPoint.clusterDistance(to: lastPoint) / pathLength
    }
}

private extension InkPoint {
    func clusterDistance(to other: InkPoint) -> Double {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}
