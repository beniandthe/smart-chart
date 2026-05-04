import CoreGraphics
import XCTest
@testable import SmartChart

final class ChordRecognitionTests: XCTestCase {
    func testChordSymbolRecognizerMatchesCompatibilityRecognizer() {
        let sample = handwrittenCSample()
        let modernReport = ChordSymbolRecognizer.evaluate(
            textCandidates: [],
            inkSample: sample
        )
        let compatibilityReport = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: sample
        )

        XCTAssertEqual(modernReport.bestMatch?.displayText, compatibilityReport.bestMatch?.displayText)
        XCTAssertEqual(modernReport.debugSummary, compatibilityReport.debugSummary)
    }

    func testStructuralEvidenceTracksTextRootAccidentalAndQuality() throws {
        let candidate = BasicMajorChordRecognitionCandidate(
            method: .textOCRExact,
            match: try XCTUnwrap(BasicMajorChordCompendium.match("Bb-")),
            confidence: 0.94,
            debugSummary: "Vision text candidate: Bbmin"
        )
        let evidence = candidate.structuralEvidence

        XCTAssertEqual(evidence.sources(for: .root), [.text])
        XCTAssertEqual(evidence.sources(for: .accidental), [.text])
        XCTAssertEqual(evidence.sources(for: .quality), [.text])
    }

    func testStructuralEvidenceDoesNotSmuggleAccidentalOrQualityFromLearnedWholeSymbol() throws {
        let candidate = BasicMajorChordRecognitionCandidate(
            method: .confirmedExample,
            match: try XCTUnwrap(BasicMajorChordCompendium.match("B#-")),
            confidence: 0.91,
            debugSummary: "confirmed family B#- best=0.91"
        )
        let evidence = candidate.structuralEvidence

        XCTAssertEqual(evidence.sources(for: .root), [.learnedExample])
        XCTAssertTrue(evidence.sources(for: .accidental).isEmpty)
        XCTAssertTrue(evidence.sources(for: .quality).isEmpty)
    }

    func testStructuralEvidenceTracksVisualAccidentalAndMinorSuffixSupport() throws {
        let candidate = BasicMajorChordRecognitionCandidate(
            method: .strokeRootShape,
            match: try XCTUnwrap(BasicMajorChordCompendium.match("C#-")),
            confidence: 0.88,
            debugSummary: "C+# rootAccidentalShape minorSuffixShape rootMethod=strokeRootShape"
        )
        let evidence = candidate.structuralEvidence

        XCTAssertTrue(evidence.sources(for: .root).contains(.visualRoot))
        XCTAssertEqual(evidence.sources(for: .accidental), [.visualAccidental])
        XCTAssertEqual(evidence.sources(for: .quality), [.visualQuality])
    }

    func testBasicMajorChordRecognizerCapturesHandwrittenCWhenOCRHasNoCandidates() throws {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: handwrittenCSample()
        )

        XCTAssertEqual(report.bestMatch?.displayText, "C")
        XCTAssertTrue(
            report.candidates.contains { $0.method == .strokeRootShape && $0.match.displayText == "C" },
            report.debugSummary
        )
        XCTAssertTrue(
            report.candidates.contains { $0.method == .rasterTemplate && $0.match.displayText == "C" },
            report.debugSummary
        )
        XCTAssertFalse(report.candidates.contains { $0.method == .textOCRExact })
    }

    func testBasicMajorChordRecognizerCapturesHandwrittenDWhenOCRHasNoCandidates() {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: closedDSample()
        )

        XCTAssertEqual(report.bestMatch?.displayText, "D", report.debugSummary)
        XCTAssertTrue(
            report.candidates.contains { $0.method == .strokeRootShape && $0.match.displayText == "D" },
            report.debugSummary
        )
        XCTAssertTrue(
            report.candidates.contains { $0.method == .rasterTemplate && $0.match.displayText == "D" },
            report.debugSummary
        )
        XCTAssertFalse(report.candidates.contains { $0.match.displayText == "C" }, report.debugSummary)
    }

    func testBasicMajorChordRecognizerDoesNotTreatLiveOneStrokeDAsE() {
        for sample in [liveOneStrokeDSample(), liveWideOneStrokeDSample()] {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [],
                inkSample: sample
            )

            XCTAssertEqual(report.bestMatch?.displayText, "D", report.debugSummary)
            XCTAssertFalse(report.candidates.contains { $0.match.displayText == "E" }, report.debugSummary)
        }
    }

    func testBasicMajorChordRecognizerCapturesHandwrittenBWithoutFallingThroughToD() {
        for sample in [handwrittenBSample(), oneStrokeBSample()] {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [],
                inkSample: sample
            )

            XCTAssertEqual(report.bestMatch?.displayText, "B", report.debugSummary)
            XCTAssertTrue(
                report.candidates.contains { $0.method == .strokeRootShape && $0.match.displayText == "B" },
                report.debugSummary
            )
            XCTAssertFalse(report.candidates.contains { $0.match.displayText == "D" }, report.debugSummary)
        }
    }

    func testBasicMajorChordRecognizerProvidesVisualFallbacksForNaturalMajorRoots() {
        let samples: [(String, BasicMajorChordInkSample)] = [
            ("A", handwrittenASample()),
            ("B", handwrittenBSample()),
            ("C", handwrittenCSample()),
            ("D", closedDSample()),
            ("E", handwrittenESample()),
            ("F", handwrittenFSample()),
            ("G", handwrittenGSample())
        ]

        for (expectedSymbol, sample) in samples {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [],
                inkSample: sample
            )
            XCTAssertEqual(report.bestMatch?.displayText, expectedSymbol, "\(expectedSymbol): \(report.debugSummary)")
        }
    }

    func testBasicMajorChordRecognizerCapturesHandwrittenSharpAndFlatRoots() {
        let samples: [(String, BasicMajorChordInkSample)] = [
            ("A", handwrittenASample()),
            ("B", handwrittenBSample()),
            ("C", handwrittenCSample()),
            ("D", closedDSample()),
            ("E", handwrittenESample()),
            ("F", handwrittenFSample()),
            ("G", handwrittenGSample())
        ]

        for (root, rootSample) in samples {
            for accidental in [Accidental.sharp, .flat] {
                let expectedSymbol = "\(root)\(accidental.rawValue)"
                let report = BasicMajorChordRecognizer.evaluate(
                    textCandidates: [],
                    inkSample: chordSample(root: rootSample, accidental: accidental)
                )

                XCTAssertEqual(
                    report.bestMatch?.displayText,
                    expectedSymbol,
                    "\(expectedSymbol): \(report.debugSummary)"
                )
                XCTAssertTrue(
                    report.candidates.contains {
                        $0.match.displayText == expectedSymbol
                            && $0.debugSummary.contains("rootAccidentalShape")
                    },
                    "\(expectedSymbol): \(report.debugSummary)"
                )
            }
        }
    }

    func testBasicMajorChordRecognizerAcceptsMinorTextAliases() {
        let cases: [(input: String, expected: String)] = [
            ("C-", "C-"),
            ("Cm", "C-"),
            ("Cmin", "C-"),
            ("C minor", "C-"),
            ("Bbmin", "Bb-"),
            ("F sharp m", "F#-")
        ]

        for testCase in cases {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [testCase.input],
                inkSample: nil
            )

            XCTAssertEqual(report.bestMatch?.displayText, testCase.expected, "\(testCase.input): \(report.debugSummary)")
            XCTAssertTrue(report.shouldAutoAcceptBestCandidate, "\(testCase.input): \(report.debugSummary)")
        }
    }

    func testBasicMajorChordRecognizerRejectsMajorTextSuffixAliases() {
        for input in ["CM", "Cmaj", "C major", "Bbmaj"] {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [input],
                inkSample: nil
            )

            XCTAssertNil(report.bestMatch, "\(input): \(report.debugSummary)")
        }
    }

    func testBasicMajorChordRecognizerCapturesHandwrittenMinorDashSuffix() {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: minorDashChordSample(root: handwrittenCSample())
        )

        XCTAssertEqual(report.bestMatch?.displayText, "C-", report.debugSummary)
        XCTAssertTrue(
            report.candidates.contains {
                $0.match.displayText == "C-"
                    && $0.debugSummary.contains("minorSuffixShape")
            },
            report.debugSummary
        )
    }

    func testBasicMajorChordRecognizerCapturesShortAngledMinorDashSuffix() {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: minorShortAngledDashChordSample(root: handwrittenCSample())
        )

        XCTAssertEqual(report.bestMatch?.displayText, "C-", report.debugSummary)
        XCTAssertTrue(
            report.candidates.contains {
                $0.match.displayText == "C-"
                    && $0.debugSummary.contains("minorSuffixShape")
            },
            report.debugSummary
        )
    }

    func testBasicMajorChordRecognizerCapturesAccidentalMinorDashSuffix() {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: minorDashChordSample(root: chordSample(root: handwrittenCSample(), accidental: .sharp))
        )

        XCTAssertEqual(report.bestMatch?.displayText, "C#-", report.debugSummary)
        XCTAssertTrue(
            report.candidates.contains {
                $0.match.displayText == "C#-"
                    && $0.debugSummary.contains("minorSuffixShape")
            },
            report.debugSummary
        )
    }

    func testBasicMajorChordRecognizerCapturesMinorDashBelowSharpAccidental() {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: minorDashBelowAccidentalChordSample(root: handwrittenFSample(), accidental: .sharp)
        )

        XCTAssertEqual(report.bestMatch?.displayText, "F#-", report.debugSummary)
        XCTAssertTrue(
            report.candidates.contains {
                $0.match.displayText == "F#-"
                    && $0.debugSummary.contains("minorSuffixShape")
            },
            report.debugSummary
        )
    }

    func testBasicMajorChordRecognizerCapturesMinorDashBelowFlatAccidental() {
        let samples: [(String, BasicMajorChordInkSample)] = [
            ("Ab-", minorDashBelowAccidentalChordSample(root: handwrittenASample(), accidental: .flat)),
            ("Cb-", minorDashBelowAccidentalChordSample(root: handwrittenCSample(), accidental: .flat)),
            ("Db-", minorDashBelowAccidentalChordSample(root: closedDSample(), accidental: .flat)),
            ("Eb-", minorDashBelowAccidentalChordSample(root: handwrittenESample(), accidental: .flat)),
            ("Gb-", minorDashBelowAccidentalChordSample(root: handwrittenGSample(), accidental: .flat))
        ]

        for (expectedSymbol, sample) in samples {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [],
                inkSample: sample
            )

            XCTAssertEqual(report.bestMatch?.displayText, expectedSymbol, "\(expectedSymbol): \(report.debugSummary)")
            XCTAssertTrue(
                report.candidates.contains {
                    $0.match.displayText == expectedSymbol
                        && $0.debugSummary.contains("minorSuffixShape")
                },
                "\(expectedSymbol): \(report.debugSummary)"
            )
        }
    }

    func testMinorAccidentalRecognizerPreservesLatestSimulatorCorrections() {
        let samples: [(expected: String, sample: BasicMajorChordInkSample)] = [
            ("Bb-", latestBFlatMinorReadAsDFlatMinorSample()),
            ("Bb-", latestBFlatMinorReadAsEFlatMinorSample()),
            ("F#-", latestFSharpMinorReadAsDSharpMinorSample()),
            ("Eb-", latestEFlatMinorReadAsFFlatSample()),
            ("Gb-", latestGFlatMinorReadAsCMinorSample()),
            ("E#-", latestESharpMinorReadAsESharpSample())
        ]

        for (expectedSymbol, sample) in samples {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [],
                inkSample: sample
            )

            XCTAssertEqual(report.bestMatch?.displayText, expectedSymbol, "\(expectedSymbol): \(report.debugSummary)")
            XCTAssertTrue(
                report.candidates.contains {
                    $0.match.displayText == expectedSymbol
                        && $0.debugSummary.contains("minorSuffixShape")
                },
                "\(expectedSymbol): \(report.debugSummary)"
            )
        }
    }

    func testBasicMajorChordRecognizerCapturesCompactHandwrittenMAsMinorSuffix() {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: minorMSuffixChordSample(root: handwrittenCSample())
        )

        XCTAssertEqual(report.bestMatch?.displayText, "C-", report.debugSummary)
        XCTAssertTrue(
            report.candidates.contains {
                $0.match.displayText == "C-"
                    && $0.debugSummary.contains("minorSuffixShape")
            },
            report.debugSummary
        )
    }

    func testBasicMajorChordRecognizerCapturesHandwrittenMinWordSuffix() {
        let samples: [(String, BasicMajorChordInkSample)] = [
            ("B-", minorMinWordSuffixChordSample(root: handwrittenBSample())),
            ("D-", minorMinWordSuffixChordSample(root: closedDSample()))
        ]

        for (expectedSymbol, sample) in samples {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [],
                inkSample: sample
            )

            XCTAssertEqual(report.bestMatch?.displayText, expectedSymbol, "\(expectedSymbol): \(report.debugSummary)")
            XCTAssertTrue(
                report.candidates.contains {
                    $0.match.displayText == expectedSymbol
                        && $0.debugSummary.contains("minorSuffixShape")
                },
                "\(expectedSymbol): \(report.debugSummary)"
            )
        }
    }

    func testBasicMajorChordRecognizerKeepsSharpAccidentalsFromBecomingMinorDash() {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: chordSample(root: handwrittenCSample(), accidental: .sharp)
        )

        XCTAssertEqual(report.bestMatch?.displayText, "C#", report.debugSummary)
        XCTAssertFalse(report.candidates.contains { $0.match.displayText == "C#-" }, report.debugSummary)
    }

    func testAccidentalRootDoesNotLetNaturalTextCandidateWin() {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: ["C"],
            inkSample: chordSample(root: handwrittenCSample(), accidental: .sharp)
        )

        XCTAssertEqual(report.bestMatch?.displayText, "C#", report.debugSummary)
        XCTAssertTrue(
            report.candidates.contains {
                $0.match.displayText == "C"
                    && $0.debugSummary.contains("accidentalContextPenalty=")
            },
            report.debugSummary
        )
    }

    func testAccidentalRecognizerAcceptsWobblySharpCrossbars() {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: wobblySharpChordSample(root: handwrittenCSample())
        )

        XCTAssertEqual(report.bestMatch?.displayText, "C#", report.debugSummary)
        XCTAssertTrue(
            report.candidates.contains {
                $0.match.displayText == "C#"
                    && $0.debugSummary.contains("rootAccidentalShape")
            },
            report.debugSummary
        )
    }

    func testAccidentalRecognizerAcceptsWideFlatBowls() {
        for (expectedSymbol, rootSample) in [
            ("Bb", handwrittenBSample()),
            ("Db", closedDSample()),
            ("Eb", handwrittenESample()),
            ("Ab", handwrittenASample())
        ] {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [],
                inkSample: wideFlatChordSample(root: rootSample)
            )

            XCTAssertEqual(report.bestMatch?.displayText, expectedSymbol, "\(expectedSymbol): \(report.debugSummary)")
            XCTAssertTrue(
                report.candidates.contains {
                    $0.match.displayText == expectedSymbol
                        && $0.debugSummary.contains("rootAccidentalShape")
                },
                "\(expectedSymbol): \(report.debugSummary)"
            )
        }
    }

    func testAccidentalRecognizerPrefersBroadSharpOverFlatInterpretation() {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: broadSharpChordSample(root: handwrittenFSample())
        )

        XCTAssertEqual(report.bestMatch?.displayText, "F#", report.debugSummary)
        XCTAssertFalse(
            report.candidates.contains {
                $0.match.displayText == "Fb"
                    || $0.match.displayText == "Bb"
            },
            report.debugSummary
        )
    }

    func testAccidentalRecognizerHandlesLatestSimulatorBaseRootCorrections() {
        let samples: [(String, BasicMajorChordInkSample)] = [
            ("C#", liveCSharpReadAsEbSample()),
            ("Db", liveDFlatReadAsBFlatSample()),
            ("Gb", liveGFlatReadAsESample())
        ]

        for (expectedSymbol, sample) in samples {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [],
                inkSample: sample
            )

            XCTAssertEqual(report.bestMatch?.displayText, expectedSymbol, "\(expectedSymbol): \(report.debugSummary)")
            XCTAssertTrue(
                report.candidates.contains {
                    $0.match.displayText == expectedSymbol
                        && $0.debugSummary.contains("rootAccidentalShape")
                },
                "\(expectedSymbol): \(report.debugSummary)"
            )
        }
    }

    func testAccidentalRecognitionUsesConfirmedRootLearningBeforeRecombining() throws {
        let rootSample = liveAuditSample58()
        let match = try XCTUnwrap(BasicMajorChordCompendium.match("A"))
        let example = ChordRecognitionLearningExample(
            match: match,
            ink: ChordRecognitionLearningInk(sample: rootSample)
        )
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: chordSample(root: rootSample, accidental: .flat),
            confirmedExamples: [example]
        )

        XCTAssertEqual(report.bestMatch?.displayText, "Ab", report.debugSummary)
        XCTAssertTrue(
            report.candidates.contains {
                $0.match.displayText == "Ab"
                    && $0.debugSummary.contains("rootMethod=confirmedExample")
            },
            report.debugSummary
        )
    }

    func testBasicMajorChordRecognizerCapturesLiveHandwrittenEAttemptsThatWereMisreadAsBAndC() {
        for sample in [liveEReadAsBSample(), liveEReadAsCSample(), liveEReadAsBAgainSample()] {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [],
                inkSample: sample
            )

            XCTAssertEqual(report.bestMatch?.displayText, "E", report.debugSummary)
            XCTAssertTrue(report.shouldAutoAcceptBestCandidate, report.debugSummary)
        }
    }

    func testRecognitionReportAutoAcceptsClearVisualPrimaryMatch() throws {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: handwrittenCSample()
        )

        XCTAssertEqual(report.bestMatch?.displayText, "C", report.debugSummary)
        XCTAssertTrue(report.shouldAutoAcceptBestCandidate, report.debugSummary)
        XCTAssertFalse(report.candidates.contains { $0.method == .textOCRExact })
    }

    func testRecognitionReportRoutesAmbiguousVisualMatchToConfirmation() throws {
        let cMatch = try XCTUnwrap(BasicMajorChordCompendium.match("C"))
        let gMatch = try XCTUnwrap(BasicMajorChordCompendium.match("G"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: cMatch,
                confidence: 0.61,
                debugSummary: "soft C candidate"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .rasterTemplate,
                match: gMatch,
                confidence: 0.58,
                debugSummary: "nearby G candidate"
            )
        ])

        XCTAssertEqual(report.bestMatch?.displayText, "C")
        XCTAssertFalse(report.shouldAutoAcceptBestCandidate)
        XCTAssertTrue(report.shouldOfferBestCandidateConfirmation)
    }

    func testRecognitionReportRoutesCloseVisualRacesToConfirmation() throws {
        let examples: [(best: String, runnerUp: String, bestConfidence: Double, runnerUpConfidence: Double)] = [
            ("A", "G", 0.90, 0.89),
            ("B", "G", 0.95, 0.89),
            ("D", "E", 0.91, 0.86),
            ("F", "C", 0.87, 0.84),
            ("G", "E", 0.89, 0.82)
        ]

        for example in examples {
            let bestMatch = try XCTUnwrap(BasicMajorChordCompendium.match(example.best))
            let runnerUpMatch = try XCTUnwrap(BasicMajorChordCompendium.match(example.runnerUp))
            let report = BasicMajorChordRecognitionReport(candidates: [
                BasicMajorChordRecognitionCandidate(
                    method: .strokeRootShape,
                    match: bestMatch,
                    confidence: example.bestConfidence,
                    debugSummary: "close best candidate"
                ),
                BasicMajorChordRecognitionCandidate(
                    method: .strokeRootShape,
                    match: runnerUpMatch,
                    confidence: example.runnerUpConfidence,
                    debugSummary: "close runner-up candidate"
                )
            ])

            XCTAssertEqual(report.bestMatch?.displayText, example.best)
            XCTAssertFalse(report.shouldAutoAcceptBestCandidate, "\(example.best)/\(example.runnerUp): \(report.debugSummary)")
            XCTAssertTrue(report.shouldOfferBestCandidateConfirmation, "\(example.best)/\(example.runnerUp): \(report.debugSummary)")
        }
    }

    func testRecognitionReportRoutesCloseAccidentalVisualRacesToConfirmation() throws {
        let cSharpMatch = try XCTUnwrap(BasicMajorChordCompendium.match("C#"))
        let dSharpMatch = try XCTUnwrap(BasicMajorChordCompendium.match("D#"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: cSharpMatch,
                confidence: 0.86,
                debugSummary: "close C# visual candidate"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: dSharpMatch,
                confidence: 0.75,
                debugSummary: "close D# visual candidate"
            )
        ])

        XCTAssertEqual(report.bestMatch?.displayText, "C#", report.debugSummary)
        XCTAssertFalse(report.shouldAutoAcceptBestCandidate, report.debugSummary)
        XCTAssertTrue(report.shouldOfferBestCandidateConfirmation, report.debugSummary)
    }

    func testLiveChordAuditSamplesWithCloseVisualRacesRequireConfirmation() {
        let samples = [
            liveAuditSample6(),
            liveAuditSample12(),
            liveAuditSample24(),
            liveAuditSample38(),
            liveAuditSample58()
        ]

        for sample in samples {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: [],
                inkSample: sample
            )

            XCTAssertNotNil(report.bestMatch, report.debugSummary)
            XCTAssertFalse(report.shouldAutoAcceptBestCandidate, report.debugSummary)
            XCTAssertTrue(report.shouldOfferBestCandidateConfirmation, report.debugSummary)
        }
    }

    func testConfirmedLearningExampleAutoAcceptsMatchingFutureInk() throws {
        let sample = liveAuditSample58()
        let baselineReport = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: sample
        )
        XCTAssertEqual(baselineReport.bestMatch?.displayText, "A", baselineReport.debugSummary)
        XCTAssertFalse(baselineReport.shouldAutoAcceptBestCandidate, baselineReport.debugSummary)

        let match = try XCTUnwrap(BasicMajorChordCompendium.match("A"))
        let example = ChordRecognitionLearningExample(
            match: match,
            ink: ChordRecognitionLearningInk(sample: sample),
            sourceMethod: baselineReport.bestCandidate?.method.rawValue,
            sourceConfidence: baselineReport.bestCandidate?.confidence,
            sourceReportSummary: baselineReport.debugSummary
        )
        let learnedReport = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: sample,
            confirmedExamples: [example]
        )

        XCTAssertEqual(learnedReport.bestMatch?.displayText, "A", learnedReport.debugSummary)
        XCTAssertTrue(
            learnedReport.candidates.contains { $0.method == .confirmedExample && $0.match.displayText == "A" },
            learnedReport.debugSummary
        )
        XCTAssertTrue(learnedReport.shouldAutoAcceptBestCandidate, learnedReport.debugSummary)
    }

    #if canImport(UIKit)
    func testBundledBaseChordLearningSeedIsAvailableInAppBundle() throws {
        let seedExamples = ChordRecognitionLearningStore.bundledSeedExamples()
        let countsBySymbol = Dictionary(grouping: seedExamples, by: \.displayText)
            .mapValues(\.count)

        XCTAssertGreaterThanOrEqual(seedExamples.count, 400)
        for symbol in ["A", "B", "C", "D", "E", "F", "G"] {
            XCTAssertGreaterThanOrEqual(countsBySymbol[symbol, default: 0], 50, symbol)
        }
    }

    func testBundledBaseChordLearningSeedIsCompactedBeforeRecognitionUse() throws {
        let seedExamples = ChordRecognitionLearningStore.bundledSeedExamples()
        let activeSeedExamples = ChordRecognitionLearningStore.activeExamples(
            userExamples: [],
            seedExamples: seedExamples
        )
        let countsBySymbol = Dictionary(grouping: activeSeedExamples, by: \.displayText)
            .mapValues(\.count)

        XCTAssertLessThan(activeSeedExamples.count, seedExamples.count)
        XCTAssertLessThanOrEqual(activeSeedExamples.count, 28)
        for symbol in ["A", "B", "C", "D", "E", "F", "G"] {
            XCTAssertLessThanOrEqual(countsBySymbol[symbol, default: 0], 4, symbol)
        }
        XCTAssertTrue(activeSeedExamples.allSatisfy { $0.wasCorrection != true })
    }
    #endif

    func testActiveLearningSetCapsUserExamplesBySymbol() throws {
        let gFlatMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("Gb-"))
        let aFlatMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("Ab-"))
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let confirmations = (0..<8).map { index in
            ChordRecognitionLearningExample(
                createdAt: baseDate.addingTimeInterval(TimeInterval(index)),
                match: gFlatMinorMatch,
                ink: ChordRecognitionLearningInk(sample: latestGFlatMinorReadAsCMinorSample()),
                sourceMethod: "confirmation-\(index)"
            )
        }
        let corrections = (0..<8).map { index in
            ChordRecognitionLearningExample(
                createdAt: baseDate.addingTimeInterval(TimeInterval(100 + index)),
                match: gFlatMinorMatch,
                ink: ChordRecognitionLearningInk(sample: latestGFlatMinorReadAsCMinorSample()),
                sourceMethod: "correction-\(index)",
                suggestedDisplayText: aFlatMinorMatch.displayText,
                suggestedMethod: BasicMajorChordRecognitionMethod.confirmedExample.rawValue,
                suggestedConfidence: 0.98,
                wasCorrection: true
            )
        }

        let activeExamples = ChordRecognitionLearningStore.activeExamples(
            userExamples: confirmations + corrections,
            seedExamples: []
        )
        let activeGFlatMinorExamples = activeExamples.filter { $0.displayText == "Gb-" }
        let activeSourceMethods = Set(activeGFlatMinorExamples.compactMap(\.sourceMethod))

        XCTAssertEqual(activeGFlatMinorExamples.count, 6)
        XCTAssertEqual(activeGFlatMinorExamples.filter { $0.wasCorrection == true }.count, 3)
        XCTAssertEqual(activeGFlatMinorExamples.filter { $0.wasCorrection != true }.count, 3)
        XCTAssertTrue(activeSourceMethods.isSuperset(of: [
            "confirmation-5",
            "confirmation-6",
            "confirmation-7",
            "correction-5",
            "correction-6",
            "correction-7"
        ]))
        XCTAssertFalse(activeSourceMethods.contains("confirmation-0"))
        XCTAssertFalse(activeSourceMethods.contains("correction-0"))
    }

    func testActiveLearningSetPrefersUserExamplesOverNaturalSeedTopUps() throws {
        let cMatch = try XCTUnwrap(BasicMajorChordCompendium.match("C"))
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let seedExamples = (0..<12).map { index in
            ChordRecognitionLearningExample(
                createdAt: baseDate.addingTimeInterval(TimeInterval(index)),
                match: cMatch,
                ink: ChordRecognitionLearningInk(sample: handwrittenCSample()),
                sourceMethod: "seed-\(index)"
            )
        }
        let userExamples = (0..<4).map { index in
            ChordRecognitionLearningExample(
                createdAt: baseDate.addingTimeInterval(TimeInterval(100 + index)),
                match: cMatch,
                ink: ChordRecognitionLearningInk(sample: handwrittenCSample()),
                sourceMethod: "user-\(index)"
            )
        }

        let seedOnlyActiveExamples = ChordRecognitionLearningStore.activeExamples(
            userExamples: [],
            seedExamples: seedExamples
        )
        let userBackedActiveExamples = ChordRecognitionLearningStore.activeExamples(
            userExamples: userExamples,
            seedExamples: seedExamples
        )
        let seedOnlyCExamples = seedOnlyActiveExamples.filter { $0.displayText == "C" }
        let userBackedCExamples = userBackedActiveExamples.filter { $0.displayText == "C" }

        XCTAssertEqual(seedOnlyCExamples.count, 4)
        XCTAssertTrue(seedOnlyCExamples.allSatisfy { $0.sourceMethod?.hasPrefix("seed-") == true })
        XCTAssertEqual(userBackedCExamples.count, 3)
        XCTAssertTrue(userBackedCExamples.allSatisfy { $0.sourceMethod?.hasPrefix("user-") == true })
    }

    func testConfirmedLearningExampleCanOverrideInitialSuggestionWhenUserCorrectsIt() throws {
        let sample = liveAuditSample58()
        let correctedMatch = try XCTUnwrap(BasicMajorChordCompendium.match("G"))
        let example = ChordRecognitionLearningExample(
            match: correctedMatch,
            ink: ChordRecognitionLearningInk(sample: sample),
            sourceMethod: "manualCorrection",
            sourceConfidence: nil,
            sourceReportSummary: "user chose G instead of initial suggestion"
        )
        let learnedReport = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: sample,
            confirmedExamples: [example]
        )

        XCTAssertEqual(learnedReport.bestMatch?.displayText, "G", learnedReport.debugSummary)
        XCTAssertTrue(learnedReport.shouldAutoAcceptBestCandidate, learnedReport.debugSummary)
    }

    func testConfirmedLearningExampleDoesNotHijackDissimilarInk() throws {
        let aMatch = try XCTUnwrap(BasicMajorChordCompendium.match("A"))
        let example = ChordRecognitionLearningExample(
            match: aMatch,
            ink: ChordRecognitionLearningInk(sample: handwrittenASample())
        )
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: handwrittenGSample(),
            confirmedExamples: [example]
        )

        XCTAssertEqual(report.bestMatch?.displayText, "G", report.debugSummary)
        XCTAssertFalse(
            report.candidates.contains { $0.method == .confirmedExample && $0.match.displayText == "A" },
            report.debugSummary
        )
    }

    func testConfirmedLearningFamilyMatchesSimilarGestureBelowOldExactThreshold() throws {
        let aMatch = try XCTUnwrap(BasicMajorChordCompendium.match("A"))
        let originalA = handwrittenASample()
        let relatedA = looseOneStrokeASample()
        let similarity = ChordRecognitionLearningInk(sample: relatedA)
            .similarity(to: ChordRecognitionLearningInk(sample: originalA))
        let example = ChordRecognitionLearningExample(
            match: aMatch,
            ink: ChordRecognitionLearningInk(sample: originalA)
        )
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: relatedA,
            confirmedExamples: [example]
        )

        XCTAssertLessThan(similarity, 0.76)
        XCTAssertGreaterThan(similarity, 0.50)
        XCTAssertTrue(
            report.candidates.contains { $0.method == .confirmedExample && $0.match.displayText == "A" },
            report.debugSummary
        )
    }

    func testConfirmedBoundaryReportsInnerAndOuterHitPercentages() throws {
        let cMatch = try XCTUnwrap(BasicMajorChordCompendium.match("C"))
        let examples = (0..<5).map { _ in
            ChordRecognitionLearningExample(
                match: cMatch,
                ink: ChordRecognitionLearningInk(sample: handwrittenCSample())
            )
        }
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: handwrittenCSample(),
            confirmedExamples: examples
        )
        let boundaryCandidate = try XCTUnwrap(
            report.candidates.first { $0.method == .confirmedBoundary && $0.match.displayText == "C" },
            report.debugSummary
        )

        XCTAssertGreaterThan(boundaryCandidate.confidence, 0.80)
        XCTAssertTrue(boundaryCandidate.debugSummary.contains("innerHit="), boundaryCandidate.debugSummary)
        XCTAssertTrue(boundaryCandidate.debugSummary.contains("outerContainment="), boundaryCandidate.debugSummary)
    }

    func testConfirmedBoundaryConfidenceDoesNotSaturateEveryOverlappingLetter() throws {
        let examples = try boundaryTrainingExamples(repetitions: 6)
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: handwrittenGSample(),
            confirmedExamples: examples
        )
        let boundaryCandidates = report.candidates.filter { $0.method == .confirmedBoundary }

        XCTAssertGreaterThanOrEqual(boundaryCandidates.count, 3, report.debugSummary)
        XCTAssertLessThanOrEqual(
            boundaryCandidates.map(\.confidence).max() ?? 0,
            0.89,
            report.debugSummary
        )
        XCTAssertTrue(
            boundaryCandidates.contains { $0.debugSummary.contains("negativeHit=") && $0.debugSummary.contains("separation=") },
            report.debugSummary
        )
    }

    func testCorrectedBoundaryNegativesSuppressKnownFalsePositiveFamily() throws {
        let bMatch = try XCTUnwrap(BasicMajorChordCompendium.match("B"))
        let gMatch = try XCTUnwrap(BasicMajorChordCompendium.match("G"))
        let examples =
            (0..<6).flatMap { _ in
                [
                    ChordRecognitionLearningExample(
                        match: bMatch,
                        ink: ChordRecognitionLearningInk(sample: handwrittenBSample())
                    ),
                    ChordRecognitionLearningExample(
                        match: gMatch,
                        ink: ChordRecognitionLearningInk(sample: handwrittenGSample())
                    ),
                    ChordRecognitionLearningExample(
                        match: gMatch,
                        ink: ChordRecognitionLearningInk(sample: handwrittenGSample()),
                        suggestedDisplayText: "B",
                        suggestedMethod: BasicMajorChordRecognitionMethod.confirmedBoundary.rawValue,
                        wasCorrection: true
                    )
                ]
            }
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: handwrittenGSample(),
            confirmedExamples: examples
        )
        let gBoundary = try XCTUnwrap(
            report.candidates.first { $0.method == .confirmedBoundary && $0.match.displayText == "G" },
            report.debugSummary
        )
        let bBoundary = report.candidates.first { $0.method == .confirmedBoundary && $0.match.displayText == "B" }

        if let bBoundary {
            XCTAssertLessThan(bBoundary.confidence, gBoundary.confidence, report.debugSummary)
            XCTAssertTrue(bBoundary.debugSummary.contains("negativeHit="), bBoundary.debugSummary)
        }
    }

    func testConfirmedCorrectionsDemoteRepeatedStrokeFalsePositive() throws {
        let bMatch = try XCTUnwrap(BasicMajorChordCompendium.match("B"))
        let gMatch = try XCTUnwrap(BasicMajorChordCompendium.match("G"))
        let baselineReport = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: handwrittenBSample()
        )
        let baselineB = try XCTUnwrap(
            baselineReport.candidates.first { $0.method == .strokeRootShape && $0.match.displayText == "B" },
            baselineReport.debugSummary
        )
        let correctedExamples =
            (0..<4).map { _ in
                ChordRecognitionLearningExample(
                    match: gMatch,
                    ink: ChordRecognitionLearningInk(sample: handwrittenBSample()),
                    suggestedDisplayText: bMatch.displayText,
                    suggestedMethod: BasicMajorChordRecognitionMethod.strokeRootShape.rawValue,
                    suggestedConfidence: baselineB.confidence,
                    wasCorrection: true
                )
            }

        let learnedReport = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: handwrittenBSample(),
            confirmedExamples: correctedExamples
        )
        let learnedB = try XCTUnwrap(
            learnedReport.candidates.first { $0.method == .strokeRootShape && $0.match.displayText == "B" },
            learnedReport.debugSummary
        )

        XCTAssertLessThan(learnedB.confidence, baselineB.confidence, learnedReport.debugSummary)
        XCTAssertTrue(learnedB.debugSummary.contains("learnedCorrectionPenalty="), learnedB.debugSummary)
        XCTAssertEqual(learnedReport.bestMatch?.displayText, "G", learnedReport.debugSummary)
    }

    func testCorrectedConfirmedExamplesSuppressRepeatedFalsePositiveFamily() throws {
        let bMatch = try XCTUnwrap(BasicMajorChordCompendium.match("B"))
        let gMatch = try XCTUnwrap(BasicMajorChordCompendium.match("G"))
        let sample = handwrittenBSample()
        let examples = [
            ChordRecognitionLearningExample(
                match: bMatch,
                ink: ChordRecognitionLearningInk(sample: sample)
            ),
            ChordRecognitionLearningExample(
                match: gMatch,
                ink: ChordRecognitionLearningInk(sample: sample),
                suggestedDisplayText: bMatch.displayText,
                suggestedMethod: BasicMajorChordRecognitionMethod.confirmedExample.rawValue,
                suggestedConfidence: 0.96,
                wasCorrection: true
            ),
            ChordRecognitionLearningExample(
                match: gMatch,
                ink: ChordRecognitionLearningInk(sample: sample),
                suggestedDisplayText: bMatch.displayText,
                suggestedMethod: BasicMajorChordRecognitionMethod.confirmedBoundary.rawValue,
                suggestedConfidence: 0.94,
                wasCorrection: true
            )
        ]

        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: sample,
            confirmedExamples: examples
        )
        let learnedB = try XCTUnwrap(
            report.candidates.first { $0.method == .confirmedExample && $0.match.displayText == "B" },
            report.debugSummary
        )

        XCTAssertEqual(report.bestMatch?.displayText, "G", report.debugSummary)
        XCTAssertTrue(learnedB.debugSummary.contains("confirmedNegativePenalty="), learnedB.debugSummary)
    }

    func testConfirmedBoundaryDoesNotEmitForDissimilarLetterOutsideEnvelope() throws {
        let cMatch = try XCTUnwrap(BasicMajorChordCompendium.match("C"))
        let examples = (0..<5).map { _ in
            ChordRecognitionLearningExample(
                match: cMatch,
                ink: ChordRecognitionLearningInk(sample: handwrittenCSample())
            )
        }
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: handwrittenASample(),
            confirmedExamples: examples
        )

        XCTAssertFalse(
            report.candidates.contains { $0.method == .confirmedBoundary && $0.match.displayText == "C" },
            report.debugSummary
        )
    }

    func testHighConfidenceConfirmedCorrectionCanOutrankConflictingVisualGuess() throws {
        let bMatch = try XCTUnwrap(BasicMajorChordCompendium.match("B"))
        let gMatch = try XCTUnwrap(BasicMajorChordCompendium.match("G"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: bMatch,
                confidence: 0.99,
                debugSummary: "conflicting visual B"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .confirmedExample,
                match: gMatch,
                confidence: 1,
                debugSummary: "exact confirmed G"
            )
        ])

        XCTAssertEqual(report.bestMatch?.displayText, "G", report.debugSummary)
        XCTAssertTrue(report.shouldAutoAcceptBestCandidate, report.debugSummary)
    }

    func testPenalizedVisualGuessLosesCloseRaceToConfirmedExample() throws {
        let bMatch = try XCTUnwrap(BasicMajorChordCompendium.match("B"))
        let gMatch = try XCTUnwrap(BasicMajorChordCompendium.match("G"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: bMatch,
                confidence: 0.88,
                debugSummary: "B stroke learnedCorrectionPenalty=0.07"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .confirmedExample,
                match: gMatch,
                confidence: 0.84,
                debugSummary: "confirmed G"
            )
        ])

        XCTAssertEqual(report.bestCandidate?.method, .confirmedExample, report.debugSummary)
        XCTAssertEqual(report.bestMatch?.displayText, "G", report.debugSummary)
    }

    func testAgreementBoostCannotFlipCloseConfirmedExampleLeader() throws {
        let bMatch = try XCTUnwrap(BasicMajorChordCompendium.match("B"))
        let dMatch = try XCTUnwrap(BasicMajorChordCompendium.match("D"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .confirmedExample,
                match: bMatch,
                confidence: 0.83,
                debugSummary: "confirmed B"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .rasterTemplate,
                match: bMatch,
                confidence: 0.76,
                debugSummary: "supporting B raster"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .confirmedExample,
                match: dMatch,
                confidence: 0.86,
                debugSummary: "confirmed D"
            )
        ])

        XCTAssertEqual(report.bestCandidate?.method, .confirmedExample, report.debugSummary)
        XCTAssertEqual(report.bestMatch?.displayText, "D", report.debugSummary)
    }

    func testMinorNaturalRootShapeCandidateWinsCloseLearnedFamilyRace() throws {
        let cMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("C-"))
        let gMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("G-"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .confirmedExample,
                match: cMinorMatch,
                confidence: 0.87,
                debugSummary: "confirmed C- family overpull"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: gMinorMatch,
                confidence: 0.84,
                debugSummary: "G- minorSuffixShape rootMethod=strokeRootShape root=0.86 suffix=0.88"
            )
        ])

        XCTAssertEqual(report.bestCandidate?.method, .strokeRootShape, report.debugSummary)
        XCTAssertEqual(report.bestMatch?.displayText, "G-", report.debugSummary)
        XCTAssertFalse(report.shouldAutoAcceptBestCandidate, report.debugSummary)
    }

    func testMinorNaturalResolverKeepsStrongLearnedWinner() throws {
        let cMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("C-"))
        let gMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("G-"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .confirmedExample,
                match: cMinorMatch,
                confidence: 0.98,
                debugSummary: "strong confirmed C- family"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: gMinorMatch,
                confidence: 0.94,
                debugSummary: "G- minorSuffixShape rootMethod=strokeRootShape root=0.89 suffix=0.91"
            )
        ])

        XCTAssertEqual(report.bestCandidate?.method, .confirmedExample, report.debugSummary)
        XCTAssertEqual(report.bestMatch?.displayText, "C-", report.debugSummary)
    }

    func testMinorNaturalResolverIgnoresPenalizedRootShapeCandidate() throws {
        let cMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("C-"))
        let gMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("G-"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .confirmedExample,
                match: cMinorMatch,
                confidence: 0.87,
                debugSummary: "confirmed C- family"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: gMinorMatch,
                confidence: 0.84,
                debugSummary: "G- minorSuffixShape rootMethod=strokeRootShape learnedCorrectionPenalty=0.07"
            )
        ])

        XCTAssertEqual(report.bestCandidate?.method, .confirmedExample, report.debugSummary)
        XCTAssertEqual(report.bestMatch?.displayText, "C-", report.debugSummary)
    }

    func testBFlatMinorResolverDoesNotSuppressAFlatMinorCandidate() throws {
        let aFlatMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("Ab-"))
        let bFlatMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("Bb-"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: aFlatMinorMatch,
                confidence: 0.90,
                debugSummary: "Ab- minorSuffixShape rootMethod=strokeRootShape rootSummary={A+b rootAccidentalShape}"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .rasterTemplate,
                match: bFlatMinorMatch,
                confidence: 0.82,
                debugSummary: "Bb- minorSuffixShape rootSummary={B+b rootAccidentalShape rootStrokes=2 flatMinorSecondaryBRootRescueAgainst=A}"
            )
        ])

        XCTAssertEqual(report.bestMatch?.displayText, "Ab-", report.debugSummary)
    }

    func testFlatMinorRescueYieldsToStrongDirectVisualFlatRootCandidate() throws {
        let scenarios: [(rescued: String, direct: String, directRoot: String, directConfidence: Double, directMethod: BasicMajorChordRecognitionMethod)] = [
            ("Ab-", "Cb-", "C", 0.985, .confirmedExample),
            ("Bb-", "Db-", "D", 0.897, .strokeRootShape),
            ("Ab-", "Eb-", "E", 0.882, .strokeRootShape),
            ("Ab-", "Gb-", "G", 0.890, .strokeRootShape)
        ]

        for scenario in scenarios {
            let rescuedMatch = try XCTUnwrap(BasicMajorChordCompendium.match(scenario.rescued))
            let directMatch = try XCTUnwrap(BasicMajorChordCompendium.match(scenario.direct))
            let rescueRoot = scenario.rescued.hasPrefix("B") ? "B" : "A"
            let report = BasicMajorChordRecognitionReport(candidates: [
                BasicMajorChordRecognitionCandidate(
                    method: .confirmedExample,
                    match: rescuedMatch,
                    confidence: 0.985,
                    debugSummary: "\(scenario.rescued) minorSuffixShape rootSummary={\(rescueRoot)+b rootAccidentalShape flatMinorSecondary\(rescueRoot)RootRescueAgainst=D gap=0.090}"
                ),
                BasicMajorChordRecognitionCandidate(
                    method: scenario.directMethod,
                    match: directMatch,
                    confidence: scenario.directConfidence,
                    debugSummary: "\(scenario.direct) minorSuffixShape rootMethod=\(scenario.directMethod.rawValue) rootSummary={\(scenario.directRoot)+b rootAccidentalShape}"
                )
            ])

            XCTAssertEqual(report.bestMatch?.displayText, scenario.direct, "\(scenario.direct): \(report.debugSummary)")
        }
    }

    func testFlatMinorDirectRootResolverDoesNotUndoBFlatCloseRacePenalty() throws {
        let bFlatMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("Bb-"))
        let dFlatMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("Db-"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: bFlatMinorMatch,
                confidence: 0.905,
                debugSummary: "Bb- minorSuffixShape rootSummary={B+b rootAccidentalShape flatMinorSecondaryBRootRescueAgainst=D gap=0.090}"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: dFlatMinorMatch,
                confidence: 0.904,
                debugSummary: "Db- minorSuffixShape rootMethod=strokeRootShape rootSummary={D+b rootAccidentalShape} bbFlatMinorCloseRacePenalty=Db- gap=0.025"
            )
        ])

        XCTAssertEqual(report.bestMatch?.displayText, "Bb-", report.debugSummary)
    }

    func testFlatMinorDirectRootResolverIgnoresUntrackedAFlatNeighbor() throws {
        let aFlatMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("Ab-"))
        let fFlatMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("Fb-"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .confirmedExample,
                match: aFlatMinorMatch,
                confidence: 0.985,
                debugSummary: "Ab- minorSuffixShape rootSummary={A+b rootAccidentalShape flatMinorSecondaryARootRescueAgainst=F gap=0.090}"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: fFlatMinorMatch,
                confidence: 0.900,
                debugSummary: "Fb- minorSuffixShape rootMethod=strokeRootShape rootSummary={F+b rootAccidentalShape}"
            )
        ])

        XCTAssertEqual(report.bestMatch?.displayText, "Ab-", report.debugSummary)
    }

    func testFinalCorrectionPenaltyDemotesLearnedFlatMinorFalsePositive() throws {
        let sample = latestGFlatMinorReadAsCMinorSample()
        let aFlatMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("Ab-"))
        let gFlatMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("Gb-"))
        let examples = [
            ChordRecognitionLearningExample(
                match: gFlatMinorMatch,
                ink: ChordRecognitionLearningInk(sample: sample),
                suggestedDisplayText: aFlatMinorMatch.displayText,
                suggestedMethod: BasicMajorChordRecognitionMethod.confirmedExample.rawValue,
                suggestedConfidence: 0.985,
                wasCorrection: true
            )
        ]

        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [aFlatMinorMatch.displayText],
            inkSample: sample,
            confirmedExamples: examples
        )
        let demotedAFlat = try XCTUnwrap(
            report.candidates.first { $0.match.displayText == "Ab-" },
            report.debugSummary
        )

        XCTAssertTrue(demotedAFlat.debugSummary.contains("learnedCorrectionPenalty"), demotedAFlat.debugSummary)
        XCTAssertEqual(report.bestMatch?.displayText, "Gb-", report.debugSummary)
    }

    func testRecognitionReportAutoAcceptsClearVisualRaces() throws {
        let bMatch = try XCTUnwrap(BasicMajorChordCompendium.match("B"))
        let cMatch = try XCTUnwrap(BasicMajorChordCompendium.match("C"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: bMatch,
                confidence: 0.95,
                debugSummary: "clear B candidate"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: cMatch,
                confidence: 0.74,
                debugSummary: "distant C candidate"
            )
        ])

        XCTAssertEqual(report.bestMatch?.displayText, "B")
        XCTAssertTrue(report.shouldAutoAcceptBestCandidate, report.debugSummary)
    }

    func testChordRecognitionDecisionPolicyKeepsV3ConfirmationFirst() throws {
        let bMatch = try XCTUnwrap(BasicMajorChordCompendium.match("B"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: bMatch,
                confidence: 0.95,
                debugSummary: "clear B candidate"
            )
        ])

        XCTAssertTrue(report.shouldAutoAcceptBestCandidate, report.debugSummary)
        XCTAssertFalse(
            ChordRecognitionDecisionPolicy.shouldAppendAutomatically(
                report: report,
                userRequiresConfirmation: false
            )
        )
        XCTAssertTrue(
            ChordRecognitionDecisionPolicy.requiresConfirmation(
                report: report,
                userRequiresConfirmation: false
            )
        )
    }

    func testChordRecognitionIntentAuditFlagsLearnedAccidentalWithoutStructuralEvidence() throws {
        let bSharpMinorMatch = try XCTUnwrap(BasicMajorChordCompendium.match("B#-"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .confirmedExample,
                match: bSharpMinorMatch,
                confidence: 0.91,
                debugSummary: "confirmed family B#- best=0.87 support=2.0"
            )
        ])

        XCTAssertEqual(report.bestMatch?.displayText, "B#-", report.debugSummary)
        XCTAssertTrue(
            ChordRecognitionIntentAudit.summary(for: report).contains("symbol=B#-")
        )
        XCTAssertTrue(
            ChordRecognitionIntentAudit.warnings(for: report).contains("missingAccidentalEvidence")
        )
        XCTAssertTrue(
            ChordRecognitionIntentAudit.warnings(for: report).contains("wholeSymbolLearnedMatchWithoutStructure")
        )
    }

    func testRecognitionReportDoesNotAutoAcceptRasterOnlyGuesses() throws {
        let cMatch = try XCTUnwrap(BasicMajorChordCompendium.match("C"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .rasterTemplate,
                match: cMatch,
                confidence: 0.84,
                debugSummary: "raster-only C candidate"
            )
        ])

        XCTAssertEqual(report.bestMatch?.displayText, "C")
        XCTAssertFalse(report.shouldAutoAcceptBestCandidate)
        XCTAssertTrue(report.shouldOfferBestCandidateConfirmation)
    }

    func testBasicMajorChordRecognizerDoesNotTreatHandwrittenCAsD() {
        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: handwrittenCSample()
        )

        XCTAssertEqual(report.bestMatch?.displayText, "C", report.debugSummary)
        XCTAssertFalse(report.candidates.contains { $0.match.displayText == "D" }, report.debugSummary)
    }

    func testTestHarnessComparesOCRAndVisualMethodAccuracy() {
        let harnessResult = ChordRecognitionHarness.evaluate([
            ChordRecognitionHarnessCase(
                name: "ocr-only C",
                expectedDisplayText: "C",
                textCandidates: ["C"],
                inkSample: nil
            ),
            ChordRecognitionHarnessCase(
                name: "handwritten C with empty OCR",
                expectedDisplayText: "C",
                textCandidates: [],
                inkSample: handwrittenCSample()
            ),
            ChordRecognitionHarnessCase(
                name: "handwritten B with empty OCR",
                expectedDisplayText: "B",
                textCandidates: [],
                inkSample: handwrittenBSample()
            ),
            ChordRecognitionHarnessCase(
                name: "ocr D with non-C ink",
                expectedDisplayText: "D",
                textCandidates: ["D"],
                inkSample: closedDSample()
            ),
            ChordRecognitionHarnessCase(
                name: "handwritten D with empty OCR",
                expectedDisplayText: "D",
                textCandidates: [],
                inkSample: closedDSample()
            )
        ])

        XCTAssertEqual(harnessResult.totalCases, 5)
        XCTAssertEqual(harnessResult.ensembleCorrect, 5)
        XCTAssertEqual(harnessResult.correctByMethod[.textOCRExact], 2)
        XCTAssertGreaterThanOrEqual(harnessResult.correctByMethod[.strokeRootShape, default: 0], 3)
        XCTAssertGreaterThanOrEqual(harnessResult.correctByMethod[.rasterTemplate, default: 0], 3)
        XCTAssertEqual(harnessResult.attemptedByMethod[.textOCRExact], 2)
    }

    func testTelemetryPersistsRecognitionRecordsAsJSONLines() throws {
        let telemetryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("chord-recognition.jsonl")
        defer {
            try? FileManager.default.removeItem(at: telemetryURL.deletingLastPathComponent())
        }

        let report = BasicMajorChordRecognizer.evaluate(
            textCandidates: [],
            inkSample: handwrittenCSample()
        )
        let record = ChordRecognitionTelemetryRecord(
            chartID: UUID(),
            measureID: UUID(),
            insertionFraction: 0.25,
            outcome: .recognized,
            textCandidates: [],
            report: report,
            inkSample: handwrittenCSample(),
            confirmedExampleCount: 12,
            recognitionDurationMillis: 4.5
        )

        try ChordRecognitionTelemetryStore.append(record, to: telemetryURL)

        let records = try ChordRecognitionTelemetryStore.records(from: telemetryURL)
        let persistedRecord = try XCTUnwrap(records.first)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(persistedRecord.outcome, .recognized)
        XCTAssertEqual(persistedRecord.schemaVersion, 3)
        XCTAssertNotNil(persistedRecord.recognitionSessionID)
        XCTAssertEqual(persistedRecord.bestDisplayText, "C")
        XCTAssertEqual(persistedRecord.methodCandidates.first?.displayText, persistedRecord.bestDisplayText)
        XCTAssertEqual(persistedRecord.resolvedReportSummary?.contains(":C@"), true)
        XCTAssertTrue(persistedRecord.rawMethodCandidates?.contains { $0.method == "strokeRootShape" } == true)
        XCTAssertTrue(persistedRecord.rawMethodCandidates?.contains { $0.method == "rasterTemplate" } == true)
        XCTAssertEqual(persistedRecord.inkMetrics?.strokeCount, 1)
        XCTAssertGreaterThan(persistedRecord.inkMetrics?.pointCount ?? 0, 8)
        XCTAssertEqual(persistedRecord.confirmedExampleCount, 12)
        XCTAssertEqual(persistedRecord.recognitionDurationMillis, 4.5)
        XCTAssertEqual(persistedRecord.wouldAutoAccept, report.shouldAutoAcceptBestCandidate)
        XCTAssertEqual(persistedRecord.confidenceMargin, report.bestConfidenceMargin)
        XCTAssertEqual(persistedRecord.intentSummary?.contains("symbol=C"), true)
        XCTAssertEqual(persistedRecord.intentWarnings, [])
    }

    func testTelemetryStoresResolvedCandidatesSeparatelyFromRawCandidates() throws {
        let telemetryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("chord-recognition.jsonl")
        defer {
            try? FileManager.default.removeItem(at: telemetryURL.deletingLastPathComponent())
        }

        let rescuedFlatMinor = try XCTUnwrap(BasicMajorChordCompendium.match("Ab-"))
        let directFlatMinor = try XCTUnwrap(BasicMajorChordCompendium.match("Gb-"))
        let report = BasicMajorChordRecognitionReport(candidates: [
            BasicMajorChordRecognitionCandidate(
                method: .confirmedExample,
                match: rescuedFlatMinor,
                confidence: 0.985,
                debugSummary: "confirmed family Ab- support=5.0 flatMinorSecondaryARootRescueAgainst=G gap=0.060"
            ),
            BasicMajorChordRecognitionCandidate(
                method: .strokeRootShape,
                match: directFlatMinor,
                confidence: 0.900,
                debugSummary: "Gb- minorSuffixShape rootMethod=strokeRootShape root=0.89 rootSummary={G+b rootAccidentalShape}"
            )
        ])
        let record = ChordRecognitionTelemetryRecord(
            chartID: UUID(),
            measureID: UUID(),
            insertionFraction: 0.5,
            outcome: .confirmationOffered,
            textCandidates: [],
            report: report,
            inkSample: nil
        )

        try ChordRecognitionTelemetryStore.append(record, to: telemetryURL)

        let persistedRecord = try XCTUnwrap(ChordRecognitionTelemetryStore.records(from: telemetryURL).first)
        XCTAssertEqual(persistedRecord.bestDisplayText, "Gb-")
        XCTAssertEqual(persistedRecord.methodCandidates.first?.displayText, "Gb-")
        XCTAssertEqual(persistedRecord.rawMethodCandidates?.first?.displayText, "Ab-")
        XCTAssertEqual(persistedRecord.resolvedReportSummary?.contains("strokeRootShape:Gb-"), true)
        XCTAssertEqual(persistedRecord.reportSummary.contains("confirmedExample:Ab-"), true)
    }

    func testConfirmedChordLearningStorePersistsExamplesAsJSONLines() throws {
        let learningURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("chord-learning.jsonl")
        defer {
            try? FileManager.default.removeItem(at: learningURL.deletingLastPathComponent())
        }

        let match = try XCTUnwrap(BasicMajorChordCompendium.match("E"))
        let telemetryID = UUID()
        let example = ChordRecognitionLearningExample(
            match: match,
            ink: ChordRecognitionLearningInk(sample: handwrittenESample()),
            sourceMethod: "confirmation",
            sourceConfidence: 0.81,
            sourceReportSummary: "user confirmed E",
            suggestedDisplayText: "B",
            suggestedMethod: "strokeRootShape",
            suggestedConfidence: 0.76,
            wasCorrection: true,
            sourceTelemetryID: telemetryID
        )

        try ChordRecognitionLearningStore.append(example, to: learningURL)

        let records = try ChordRecognitionLearningStore.records(from: learningURL)
        let persistedRecord = try XCTUnwrap(records.first)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(persistedRecord.displayText, "E")
        XCTAssertEqual(persistedRecord.rawInput, "E")
        XCTAssertEqual(persistedRecord.sourceMethod, "confirmation")
        XCTAssertEqual(persistedRecord.suggestedDisplayText, "B")
        XCTAssertEqual(persistedRecord.suggestedMethod, "strokeRootShape")
        XCTAssertEqual(persistedRecord.suggestedConfidence, 0.76)
        XCTAssertEqual(persistedRecord.wasCorrection, true)
        XCTAssertEqual(persistedRecord.sourceTelemetryID, telemetryID)
        XCTAssertEqual(persistedRecord.effectiveWeight, 2.5)
        XCTAssertGreaterThan(persistedRecord.ink.sampledNormalizedStrokes.flatMap { $0 }.count, 8)
    }

    private func handwrittenCSample() -> BasicMajorChordInkSample {
        let points = stride(from: 0, through: 32, by: 1).map { index -> CGPoint in
            let t = CGFloat(index) / 32
            let angle = 0.78 + (5.50 - 0.78) * t
            let wobble = sin(t * .pi * 5) * 1.5
            return CGPoint(
                x: 50 + cos(angle) * 27 + wobble,
                y: 50 + sin(angle) * 34
            )
        }

        return BasicMajorChordInkSample(strokes: [points])
    }

    private func handwrittenASample() -> BasicMajorChordInkSample {
        BasicMajorChordInkSample(strokes: [
            line(from: CGPoint(x: 10, y: 90), to: CGPoint(x: 50, y: 10)),
            line(from: CGPoint(x: 50, y: 10), to: CGPoint(x: 90, y: 90)),
            line(from: CGPoint(x: 30, y: 55), to: CGPoint(x: 70, y: 55))
        ])
    }

    private func looseOneStrokeASample() -> BasicMajorChordInkSample {
        BasicMajorChordInkSample(strokes: [
            polyline([
                CGPoint(x: 13, y: 92),
                CGPoint(x: 28, y: 61),
                CGPoint(x: 43, y: 23),
                CGPoint(x: 53, y: 11),
                CGPoint(x: 65, y: 41),
                CGPoint(x: 81, y: 88)
            ], pointsPerSegment: 6),
            polyline([
                CGPoint(x: 32, y: 61),
                CGPoint(x: 49, y: 57),
                CGPoint(x: 72, y: 54)
            ], pointsPerSegment: 5)
        ])
    }

    private func handwrittenBSample() -> BasicMajorChordInkSample {
        BasicMajorChordInkSample(strokes: [
            line(from: CGPoint(x: 15, y: 10), to: CGPoint(x: 15, y: 90)),
            polyline([
                CGPoint(x: 15, y: 10),
                CGPoint(x: 58, y: 10),
                CGPoint(x: 82, y: 26),
                CGPoint(x: 64, y: 45),
                CGPoint(x: 15, y: 50)
            ]),
            polyline([
                CGPoint(x: 15, y: 50),
                CGPoint(x: 70, y: 50),
                CGPoint(x: 88, y: 72),
                CGPoint(x: 62, y: 92),
                CGPoint(x: 15, y: 90)
            ])
        ])
    }

    private func oneStrokeBSample() -> BasicMajorChordInkSample {
        BasicMajorChordInkSample(strokes: [polyline([
            CGPoint(x: 18, y: 12),
            CGPoint(x: 14, y: 42),
            CGPoint(x: 12, y: 90),
            CGPoint(x: 20, y: 54),
            CGPoint(x: 46, y: 16),
            CGPoint(x: 80, y: 14),
            CGPoint(x: 92, y: 28),
            CGPoint(x: 64, y: 42),
            CGPoint(x: 22, y: 50),
            CGPoint(x: 90, y: 50),
            CGPoint(x: 92, y: 70),
            CGPoint(x: 68, y: 92),
            CGPoint(x: 20, y: 92)
        ])])
    }

    private func closedDSample() -> BasicMajorChordInkSample {
        let stem = stride(from: 0, through: 18, by: 1).map { index in
            CGPoint(x: 25, y: 18 + CGFloat(index) * 3.4)
        }
        let bowl = stride(from: -90, through: 90, by: 6).map { degrees -> CGPoint in
            let angle = CGFloat(degrees) * .pi / 180
            return CGPoint(
                x: 25 + cos(angle) * 34,
                y: 50 + sin(angle) * 32
            )
        }

        return BasicMajorChordInkSample(strokes: [stem, bowl])
    }

    private func liveOneStrokeDSample() -> BasicMajorChordInkSample {
        BasicMajorChordInkSample(strokes: [[
            CGPoint(x: 0, y: 0.3409090909090909),
            CGPoint(x: 0.05, y: 0.13636363636363635),
            CGPoint(x: 0.18, y: 0),
            CGPoint(x: 0.46, y: 0),
            CGPoint(x: 0.76, y: 0.045454545454545456),
            CGPoint(x: 0.95, y: 0.22727272727272727),
            CGPoint(x: 1, y: 0.5),
            CGPoint(x: 0.92, y: 0.7272727272727273),
            CGPoint(x: 0.68, y: 0.9090909090909091),
            CGPoint(x: 0.36, y: 1),
            CGPoint(x: 0.16, y: 0.8636363636363636)
        ]])
    }

    private func liveWideOneStrokeDSample() -> BasicMajorChordInkSample {
        BasicMajorChordInkSample(strokes: [[
            CGPoint(x: 0.09090909090909091, y: 0.21428571428571427),
            CGPoint(x: 0.12, y: 0.07142857142857142),
            CGPoint(x: 0.30, y: 0),
            CGPoint(x: 0.58, y: 0),
            CGPoint(x: 0.82, y: 0.10714285714285714),
            CGPoint(x: 1, y: 0.35714285714285715),
            CGPoint(x: 0.98, y: 0.6071428571428571),
            CGPoint(x: 0.80, y: 0.8214285714285714),
            CGPoint(x: 0.48, y: 1),
            CGPoint(x: 0.15, y: 0.8928571428571429),
            CGPoint(x: 0, y: 0.6964285714285714)
        ]])
    }

    private func handwrittenESample() -> BasicMajorChordInkSample {
        BasicMajorChordInkSample(strokes: [
            line(from: CGPoint(x: 15, y: 10), to: CGPoint(x: 15, y: 90)),
            line(from: CGPoint(x: 15, y: 10), to: CGPoint(x: 82, y: 10)),
            line(from: CGPoint(x: 15, y: 50), to: CGPoint(x: 66, y: 50)),
            line(from: CGPoint(x: 15, y: 90), to: CGPoint(x: 84, y: 90))
        ])
    }

    private func liveEReadAsBSample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.21695190674191964, y: 0.05172413793103448),
                CGPoint(x: 0.3118668271368385, y: 0.017241379310344827),
                CGPoint(x: 0.5486935729378931, y: 0.013860242120150862),
                CGPoint(x: 0.8576276194076218, y: 0),
                CGPoint(x: 0.9288138097038109, y: 0)
            ],
            [
                CGPoint(x: 0.14576571644573053, y: 0.1724137931034483),
                CGPoint(x: 0.14576571644573053, y: 0.27586206896551724),
                CGPoint(x: 0.14576571644573053, y: 0.39655172413793105),
                CGPoint(x: 0.0745795261495414, y: 0.5689655172413793),
                CGPoint(x: 0.0745795261495414, y: 0.7241379310344828),
                CGPoint(x: 0.0745795261495414, y: 0.8448275862068966),
                CGPoint(x: 0, y: 0.9911151754445043),
                CGPoint(x: 0.0745795261495414, y: 1),
                CGPoint(x: 0.16698891046836145, y: 0.9922895760371767),
                CGPoint(x: 0.31103116568255584, y: 0.9572001490099676),
                CGPoint(x: 0.4542392077292167, y: 0.9137931034482759),
                CGPoint(x: 0.5466485920480367, y: 0.8870207687904095),
                CGPoint(x: 0.6703033146938828, y: 0.8715999208647629),
                CGPoint(x: 0.7627126990127029, y: 0.8448275862068966),
                CGPoint(x: 0.9288138097038109, y: 0.8448275862068966)
            ],
            [
                CGPoint(x: 0.3118668271368385, y: 0.5689655172413793),
                CGPoint(x: 0.3830530174330276, y: 0.5),
                CGPoint(x: 0.6203403184203247, y: 0.4482758620689655),
                CGPoint(x: 0.834607101529246, y: 0.4268530483903556),
                CGPoint(x: 1, y: 0.39655172413793105)
            ]
        ])
    }

    private func liveEReadAsCSample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.22897174271107404, y: 0.05357142857142857),
                CGPoint(x: 0.4399495176367409, y: 0.004330771309988839),
                CGPoint(x: 0.6028036250329776, y: 0),
                CGPoint(x: 0.7663550735488103, y: 0)
            ],
            [
                CGPoint(x: 0.22897174271107404, y: 0.14285714285714285),
                CGPoint(x: 0.22897174271107404, y: 0.23214285714285715),
                CGPoint(x: 0.13551377213059815, y: 0.375),
                CGPoint(x: 0.0848602822163754, y: 0.5277622767857143),
                CGPoint(x: 0.06542029419524126, y: 0.6964285714285714),
                CGPoint(x: 0.00934494142477201, y: 0.807143075125558),
                CGPoint(x: 0, y: 0.8642856052943638),
                CGPoint(x: 0.08808744572076407, y: 0.9420978001185826),
                CGPoint(x: 0.2063045911855512, y: 0.9686164855957031),
                CGPoint(x: 0.29906522064643093, y: 1),
                CGPoint(x: 0.4781934729441628, y: 1),
                CGPoint(x: 0.6728971029683345, y: 1),
                CGPoint(x: 0.8130840588390482, y: 1),
                CGPoint(x: 0.9065420294195241, y: 0.9880954197474888),
                CGPoint(x: 1, y: 0.9642857142857143)
            ],
            [
                CGPoint(x: 0.22897174271107404, y: 0.4107142857142857),
                CGPoint(x: 0.22897174271107404, y: 0.3392857142857143),
                CGPoint(x: 0.29906522064643093, y: 0.3392857142857143),
                CGPoint(x: 0.46261666916226374, y: 0.32142857142857145),
                CGPoint(x: 0.6728971029683345, y: 0.2857142857142857)
            ]
        ])
    }

    private func liveEReadAsBAgainSample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.16279069767441862, y: 0.06451612903225806),
                CGPoint(x: 0.23255813953488372, y: 0.06451612903225806),
                CGPoint(x: 0.46511627906976744, y: 0.04301058861517137),
                CGPoint(x: 0.6976744186046512, y: 0.03225806451612903),
                CGPoint(x: 1, y: 0)
            ],
            [
                CGPoint(x: 0.23255813953488372, y: 0.11290322580645161),
                CGPoint(x: 0.23255813953488372, y: 0.24193548387096775),
                CGPoint(x: 0.23255813953488372, y: 0.4032258064516129),
                CGPoint(x: 0.16279069767441862, y: 0.6451612903225806),
                CGPoint(x: 0.09302325581395349, y: 0.8387096774193549),
                CGPoint(x: 0.02080021348110465, y: 0.9282708937121976),
                CGPoint(x: 0, y: 1),
                CGPoint(x: 0.10852760492369186, y: 1),
                CGPoint(x: 0.23255813953488372, y: 1),
                CGPoint(x: 0.4146984011627907, y: 0.9910534274193549),
                CGPoint(x: 0.627906976744186, y: 0.967741935483871),
                CGPoint(x: 0.7184746320857558, y: 0.9426968482232863),
                CGPoint(x: 0.8375698355741279, y: 0.9326575494581654),
                CGPoint(x: 0.9302325581395349, y: 0.9193548387096774),
                CGPoint(x: 1, y: 0.8548387096774194)
            ],
            [
                CGPoint(x: 0.3023255813953488, y: 0.43548387096774194),
                CGPoint(x: 0.46511627906976744, y: 0.43548387096774194),
                CGPoint(x: 0.627906976744186, y: 0.3870967741935484),
                CGPoint(x: 0.6976744186046512, y: 0.3548387096774194)
            ]
        ])
    }

    private func liveAuditSample6() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.2978723404255319, y: 0.18543322564340053),
                CGPoint(x: 0.2978723404255319, y: 0.1401795159569228),
                CGPoint(x: 0.28085132355385639, y: 0.22465319944058931),
                CGPoint(x: 0.21276595744680851, y: 0.33627892459832637),
                CGPoint(x: 0.21276595744680851, y: 0.53237833323972994),
                CGPoint(x: 0.085106382978723402, y: 0.72847774188113357),
                CGPoint(x: 0.068085366107047879, y: 0.87027260682985574),
                CGPoint(x: 0, y: 1),
                CGPoint(x: 0, y: 0.93966172041802964),
                CGPoint(x: 0, y: 0.83406973114958161),
                CGPoint(x: 0.020641570395611701, y: 0.72481938381962596),
                CGPoint(x: 0.085106382978723402, y: 0.60780118271719286),
                CGPoint(x: 0.21276595744680851, y: 0.44187091386677446),
                CGPoint(x: 0.2978723404255319, y: 0.26085607512086345),
                CGPoint(x: 0.42553191489361702, y: 0.094925806270445057),
                CGPoint(x: 0.44057643159906917, y: 0),
                CGPoint(x: 0.55319148936170215, y: 0.064756666479459893),
                CGPoint(x: 0.58865291514295215, y: 0.12006660264808593),
                CGPoint(x: 0.63829787234042556, y: 0.18543322564340053),
                CGPoint(x: 0.65600066489361697, y: 0.26922329748476947),
                CGPoint(x: 0.7021276595744681, y: 0.36644806438931155),
                CGPoint(x: 0.78014227684507975, y: 0.4871246235532522),
                CGPoint(x: 0.85106382978723405, y: 0.60780118271719286),
                CGPoint(x: 0.85106382978723405, y: 0.71339317198564089),
                CGPoint(x: 0.85106382978723405, y: 0.80390059135859637),
                CGPoint(x: 0.86200990068151595, y: 0.89655781973460213),
                CGPoint(x: 0.91489361702127658, y: 0.95474629031352221),
                CGPoint(x: 0.91489361702127658, y: 0.88379292597751857),
                CGPoint(x: 0.91489361702127658, y: 0.83406973114958161),
                CGPoint(x: 1, y: 0.80390059135859637)
            ],
            [
                CGPoint(x: 0.36170212765957449, y: 0.44187091386677446),
                CGPoint(x: 0.21276595744680851, y: 0.44187091386677446),
                CGPoint(x: 0.40534745885970747, y: 0.45218539363601296),
                CGPoint(x: 0.5606481673869681, y: 0.45536545372018233),
                CGPoint(x: 0.70461321891622342, y: 0.45642562719641888),
                CGPoint(x: 0.85106382978723405, y: 0.45695548376226702),
                CGPoint(x: 1, y: 0.44187091386677446)
            ]
        ])
    }

    private func liveAuditSample12() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0, y: 0.056603773584905662),
                CGPoint(x: 0.083333333333333329, y: 0.15094339622641509),
                CGPoint(x: 0.17592705620659721, y: 0.35220106592718159),
                CGPoint(x: 0.27777777777777779, y: 0.56603773584905659),
                CGPoint(x: 0.3611111111111111, y: 0.74213855671432782),
                CGPoint(x: 0.44444444444444442, y: 0.90566037735849059),
                CGPoint(x: 0.44444444444444442, y: 1)
            ],
            [
                CGPoint(x: 0.083333333333333329, y: 0.056603773584905662),
                CGPoint(x: 0.27777777777777779, y: 0.037735849056603772),
                CGPoint(x: 0.55555555555555558, y: 0),
                CGPoint(x: 0.74444580078125, y: 0.011320869877653301),
                CGPoint(x: 1, y: 0.056603773584905662),
                CGPoint(x: 1, y: 0.17610082086527123),
                CGPoint(x: 1, y: 0.28301886792452829),
                CGPoint(x: 0.97688802083333337, y: 0.46123231132075471),
                CGPoint(x: 0.91666666666666663, y: 0.62264150943396224),
                CGPoint(x: 0.55555555555555558, y: 0.81132075471698117),
                CGPoint(x: 0.3611111111111111, y: 0.84905660377358494),
                CGPoint(x: 0.16666666666666666, y: 0.86792452830188682)
            ]
        ])
    }

    private func liveAuditSample24() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.25, y: 0.22222222222222221),
                CGPoint(x: 0.18150711059570312, y: 0.34703318277994794),
                CGPoint(x: 0.125, y: 0.52777777777777779),
                CGPoint(x: 0.071428571428571425, y: 0.75),
                CGPoint(x: 0, y: 0.93055555555555558),
                CGPoint(x: 0, y: 0.98611111111111116),
                CGPoint(x: 0.068903241838727675, y: 0.90291765001085067),
                CGPoint(x: 0.125, y: 0.75),
                CGPoint(x: 0.125, y: 0.64351823594835067),
                CGPoint(x: 0.125, y: 0.52777777777777779),
                CGPoint(x: 0.19119807652064733, y: 0.37906816270616317),
                CGPoint(x: 0.30357142857142855, y: 0.19444444444444445),
                CGPoint(x: 0.32051195417131695, y: 0.087725321451822921),
                CGPoint(x: 0.4107142857142857, y: 0),
                CGPoint(x: 0.4856447492327009, y: 0.013619316948784722),
                CGPoint(x: 0.5892857142857143, y: 0.1388888888888889),
                CGPoint(x: 0.64339011056082585, y: 0.29503546820746529),
                CGPoint(x: 0.6607142857142857, y: 0.45833333333333331),
                CGPoint(x: 0.7678571428571429, y: 0.63888888888888884),
                CGPoint(x: 0.7678571428571429, y: 0.81944444444444442),
                CGPoint(x: 0.7678571428571429, y: 0.91666666666666663),
                CGPoint(x: 0.7678571428571429, y: 1)
            ],
            [
                CGPoint(x: 0.125, y: 0.61111111111111116),
                CGPoint(x: 0.19642857142857142, y: 0.61111111111111116),
                CGPoint(x: 0.35714285714285715, y: 0.61111111111111116),
                CGPoint(x: 0.5, y: 0.61111111111111116),
                CGPoint(x: 0.6607142857142857, y: 0.61111111111111116),
                CGPoint(x: 0.82331357683454243, y: 0.58954450819227433),
                CGPoint(x: 0.9464285714285714, y: 0.58333333333333337),
                CGPoint(x: 1, y: 0.56944444444444442)
            ]
        ])
    }

    private func liveAuditSample38() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.083333333333333329, y: 0.30232558139534882),
                CGPoint(x: 0, y: 0.34883720930232559),
                CGPoint(x: 0, y: 0.46511627906976744),
                CGPoint(x: 0, y: 0.65116279069767447),
                CGPoint(x: 0, y: 0.82945783748183144),
                CGPoint(x: 0, y: 1)
            ],
            [
                CGPoint(x: 0.083333333333333329, y: 0.18604651162790697),
                CGPoint(x: 0.22052001953125, y: 0.15477663971656977),
                CGPoint(x: 0.44444444444444442, y: 0.11627906976744186),
                CGPoint(x: 0.66524251302083337, y: 0.053865654523982558),
                CGPoint(x: 0.91666666666666663, y: 0),
                CGPoint(x: 1, y: 0)
            ],
            [
                CGPoint(x: 0.19444444444444445, y: 0.65116279069767447),
                CGPoint(x: 0, y: 0.72093023255813948),
                CGPoint(x: 0.092593722873263895, y: 0.72093023255813948),
                CGPoint(x: 0.21605088975694445, y: 0.72093023255813948),
                CGPoint(x: 0.3611111111111111, y: 0.72093023255813948),
                CGPoint(x: 0.47139146592881942, y: 0.69203363462936052),
                CGPoint(x: 0.63888888888888884, y: 0.65116279069767447)
            ]
        ])
    }

    private func liveAuditSample56() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.093023255813953487, y: 0.375),
                CGPoint(x: 0.093023255813953487, y: 0.43181818181818182),
                CGPoint(x: 0.093023255813953487, y: 0.54545454545454541),
                CGPoint(x: 0.093023255813953487, y: 0.68181818181818177),
                CGPoint(x: 0.018604367278343022, y: 0.75681790438565344),
                CGPoint(x: 0, y: 0.875),
                CGPoint(x: 0, y: 0.79545454545454541),
                CGPoint(x: 0, y: 0.70454545454545459),
                CGPoint(x: 0, y: 0.625),
                CGPoint(x: 0.093023255813953487, y: 0.45454545454545453),
                CGPoint(x: 0.16279069767441862, y: 0.28409090909090912),
                CGPoint(x: 0.32558139534883723, y: 0.13636363636363635),
                CGPoint(x: 0.32558139534883723, y: 0.022727272727272728),
                CGPoint(x: 0.39534883720930231, y: 0.0037876475941051135),
                CGPoint(x: 0.46511627906976744, y: 0),
                CGPoint(x: 0.53488372093023251, y: 0.056818181818181816),
                CGPoint(x: 0.69767441860465118, y: 0.17045454545454544),
                CGPoint(x: 0.70683536973110461, y: 0.2718082774769176),
                CGPoint(x: 0.76744186046511631, y: 0.43181818181818182),
                CGPoint(x: 0.76744186046511631, y: 0.625),
                CGPoint(x: 0.76744186046511631, y: 0.73863636363636365),
                CGPoint(x: 0.85271223201308144, y: 0.80303053422407666),
                CGPoint(x: 0.93023255813953487, y: 0.86363636363636365),
                CGPoint(x: 0.93023255813953487, y: 0.91287855668501416),
                CGPoint(x: 0.9505615234375, y: 0.94902662797407666),
                CGPoint(x: 1, y: 1)
            ],
            [
                CGPoint(x: 0.32558139534883723, y: 0.56818181818181823),
                CGPoint(x: 0.16279069767441862, y: 0.56818181818181823),
                CGPoint(x: 0.24030960437863372, y: 0.53787855668501416),
                CGPoint(x: 0.34814311182776164, y: 0.52548356489701709),
                CGPoint(x: 0.53488372093023251, y: 0.52272727272727271),
                CGPoint(x: 0.67511412154796513, y: 0.51411992853338073),
                CGPoint(x: 0.76744186046511631, y: 0.51136363636363635)
            ]
        ])
    }

    private func liveAuditSample58() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.21739130434782608, y: 0.38541666666666669),
                CGPoint(x: 0.20766813858695651, y: 0.45723342895507812),
                CGPoint(x: 0.15217391304347827, y: 0.58333333333333337),
                CGPoint(x: 0.086956521739130432, y: 0.73958333333333337),
                CGPoint(x: 0, y: 0.875),
                CGPoint(x: 0, y: 0.94097201029459632),
                CGPoint(x: 0, y: 1),
                CGPoint(x: 0, y: 0.92708333333333337),
                CGPoint(x: 0.079709260360054351, y: 0.80555534362792969),
                CGPoint(x: 0.15217391304347827, y: 0.67708333333333337),
                CGPoint(x: 0.21739130434782608, y: 0.53125),
                CGPoint(x: 0.28260869565217389, y: 0.39583333333333331),
                CGPoint(x: 0.43478260869565216, y: 0.1875),
                CGPoint(x: 0.43478260869565216, y: 0.072916666666666671),
                CGPoint(x: 0.5, y: 0),
                CGPoint(x: 0.5, y: 0.041666666666666664),
                CGPoint(x: 0.58008077870244568, y: 0.13488197326660156),
                CGPoint(x: 0.65217391304347827, y: 0.23958333333333334),
                CGPoint(x: 0.65217391304347827, y: 0.38541666666666669),
                CGPoint(x: 0.80434782608695654, y: 0.52083333333333337),
                CGPoint(x: 0.80434782608695654, y: 0.65625),
                CGPoint(x: 0.93478260869565222, y: 0.76041666666666663),
                CGPoint(x: 0.93478260869565222, y: 0.84375),
                CGPoint(x: 0.98191236413043481, y: 0.89005533854166663),
                CGPoint(x: 1, y: 0.92708333333333337),
                CGPoint(x: 0.93478260869565222, y: 0.875)
            ],
            [
                CGPoint(x: 0.36956521739130432, y: 0.53125),
                CGPoint(x: 0.21739130434782608, y: 0.55208333333333337),
                CGPoint(x: 0.36956521739130432, y: 0.55208333333333337),
                CGPoint(x: 0.52108897333559778, y: 0.52335993448893225),
                CGPoint(x: 0.71739130434782605, y: 0.5),
                CGPoint(x: 0.86956521739130432, y: 0.47916666666666669)
            ]
        ])
    }

    private func liveCSharpReadAsEbSample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.2463768115942029, y: 0.38571428571428573),
                CGPoint(x: 0.2028985507246377, y: 0.37142857142857144),
                CGPoint(x: 0.1289047020069067, y: 0.4492457798549107),
                CGPoint(x: 0.11594202898550725, y: 0.5285714285714286),
                CGPoint(x: 0.07246376811594203, y: 0.6190477643694197),
                CGPoint(x: 0.028985507246376812, y: 0.7142857142857143),
                CGPoint(x: 0.009661909462749094, y: 0.7857142857142857),
                CGPoint(x: 0.003220710201539855, y: 0.8571428571428571),
                CGPoint(x: 0, y: 0.9285714285714286),
                CGPoint(x: 0.033816351406816124, y: 0.9619049072265625),
                CGPoint(x: 0.07407412321671196, y: 0.9825395856584821),
                CGPoint(x: 0.1294312408004982, y: 0.9947762625558035),
                CGPoint(x: 0.2028985507246377, y: 1),
                CGPoint(x: 0.26012586510699726, y: 0.9669110979352679),
                CGPoint(x: 0.32342352383378625, y: 0.9270656040736607),
                CGPoint(x: 0.37681159420289856, y: 0.8857142857142857),
                CGPoint(x: 0.4492753623188406, y: 0.8428571428571429)
            ],
            [
                CGPoint(x: 0.5362318840579711, y: 0.02857142857142857),
                CGPoint(x: 0.5362318840579711, y: 0.07142857142857142),
                CGPoint(x: 0.5362318840579711, y: 0.18571428571428572),
                CGPoint(x: 0.5694624306499094, y: 0.31847011021205357),
                CGPoint(x: 0.5797101449275363, y: 0.42857142857142855),
                CGPoint(x: 0.5797101449275363, y: 0.4714285714285714)
            ],
            [
                CGPoint(x: 0.7101449275362319, y: 0),
                CGPoint(x: 0.7101449275362319, y: 0.07142857142857142),
                CGPoint(x: 0.7536231884057971, y: 0.15714285714285714),
                CGPoint(x: 0.7729470073312953, y: 0.24285714285714285),
                CGPoint(x: 0.782608695652174, y: 0.32857142857142857),
                CGPoint(x: 0.7963575280230978, y: 0.3811968122209821),
                CGPoint(x: 0.8260869565217391, y: 0.44285714285714284)
            ],
            [
                CGPoint(x: 0.4492753623188406, y: 0.32857142857142857),
                CGPoint(x: 0.37681159420289856, y: 0.32857142857142857),
                CGPoint(x: 0.3333333333333333, y: 0.32857142857142857),
                CGPoint(x: 0.38647328252377716, y: 0.3047620500837054),
                CGPoint(x: 0.4623497119848279, y: 0.2795506068638393),
                CGPoint(x: 0.6231884057971014, y: 0.21428571428571427),
                CGPoint(x: 0.7391304347826086, y: 0.18571428571428572),
                CGPoint(x: 0.8260869565217391, y: 0.15714285714285714)
            ],
            [
                CGPoint(x: 0.5362318840579711, y: 0.4),
                CGPoint(x: 0.4492753623188406, y: 0.44285714285714284),
                CGPoint(x: 0.4927536231884058, y: 0.44285714285714284),
                CGPoint(x: 0.6666666666666666, y: 0.38571428571428573),
                CGPoint(x: 0.7874397609544836, y: 0.3333334786551339),
                CGPoint(x: 0.9130434782608695, y: 0.2857142857142857),
                CGPoint(x: 1, y: 0.24285714285714285)
            ]
        ])
    }

    private func liveDFlatReadAsBFlatSample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.15602307079424096, y: 0.3719007889272351),
                CGPoint(x: 0.15602307079424096, y: 0.4314049151555927),
                CGPoint(x: 0.15602307079424096, y: 0.550413167612308),
                CGPoint(x: 0.15602307079424096, y: 0.6694214200690232),
                CGPoint(x: 0.15602307079424096, y: 0.7685948124561341),
                CGPoint(x: 0.15602307079424096, y: 0.8628098303111854),
                CGPoint(x: 0.15602307079424096, y: 0.9074379249824537)
            ],
            [
                CGPoint(x: 0, y: 0.46115697826977153),
                CGPoint(x: 0.05200769026474699, y: 0.4165288835985033),
                CGPoint(x: 0.10401538052949398, y: 0.3867768204843245),
                CGPoint(x: 0.15602307079424096, y: 0.3719007889272351),
                CGPoint(x: 0.21958784921240387, y: 0.36198358588266055),
                CGPoint(x: 0.30434106345314893, y: 0.36859490325222516),
                CGPoint(x: 0.3987256253630603, y: 0.3867768204843245),
                CGPoint(x: 0.4507333156278073, y: 0.4264460866430778),
                CGPoint(x: 0.5027410058925542, y: 0.474380066989356),
                CGPoint(x: 0.5547486961573013, y: 0.5206611044981292),
                CGPoint(x: 0.5942284922827538, y: 0.5873322201732571),
                CGPoint(x: 0.6067563864220482, y: 0.6694214200690232),
                CGPoint(x: 0.5720845929122169, y: 0.7140495147402914),
                CGPoint(x: 0.560527504758801, y: 0.7586776094115596),
                CGPoint(x: 0.5393390689362189, y: 0.8033057040828279),
                CGPoint(x: 0.5027410058925542, y: 0.847933798754096),
                CGPoint(x: 0.4507333156278073, y: 0.87272703335576),
                CGPoint(x: 0.3987256253630603, y: 0.9107438106574636),
                CGPoint(x: 0.3467179350983133, y: 0.9432506271739989),
                CGPoint(x: 0.2947102448335663, y: 0.9669420512108112),
                CGPoint(x: 0.21958784921240387, y: 0.9917352858124752),
                CGPoint(x: 0.15987560986190746, y: 1),
                CGPoint(x: 0.10401538052949398, y: 0.9966941143249901),
                CGPoint(x: 0.05200769026474699, y: 0.9669420512108112)
            ],
            [
                CGPoint(x: 0.6067563864220482, y: 0),
                CGPoint(x: 0.6067563864220482, y: 0.07438015778544702),
                CGPoint(x: 0.6067563864220482, y: 0.17851237868507286),
                CGPoint(x: 0.6156756333517089, y: 0.26988865675354945),
                CGPoint(x: 0.6587640766867953, y: 0.3123966626988775)
            ],
            [
                CGPoint(x: 0.6067563864220482, y: 0.2677685680276093),
                CGPoint(x: 0.6067563864220482, y: 0.19338841024216225),
                CGPoint(x: 0.6934358701966266, y: 0.19338841024216225),
                CGPoint(x: 0.7454435604613736, y: 0.20330561328673677),
                CGPoint(x: 0.7974512507261206, y: 0.2165287020063212),
                CGPoint(x: 0.8665049185739786, y: 0.22584937473271902),
                CGPoint(x: 0.9534743215203615, y: 0.23801650491343046),
                CGPoint(x: 1, y: 0.28603537960483727),
                CGPoint(x: 0.9388572105754895, y: 0.3639025612669323),
                CGPoint(x: 0.8494589409908675, y: 0.3867768204843245),
                CGPoint(x: 0.7598680973578206, y: 0.4082773348441803),
                CGPoint(x: 0.7040226814137475, y: 0.4137782160202439),
                CGPoint(x: 0.6067563864220482, y: 0.4165288835985033)
            ]
        ])
    }

    private func liveGFlatReadAsESample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.1836734693877551, y: 0.35135135135135137),
                CGPoint(x: 0.1714290696747449, y: 0.4162160512563345),
                CGPoint(x: 0.12244897959183673, y: 0.5135135135135135),
                CGPoint(x: 0, y: 0.6621621621621622),
                CGPoint(x: 0.019360600685586735, y: 0.7930240115603885),
                CGPoint(x: 0.061224489795918366, y: 0.918918918918919),
                CGPoint(x: 0.16669323979591838, y: 0.9654771959459459),
                CGPoint(x: 0.23923788265306123, y: 0.9884923986486487),
                CGPoint(x: 0.30612244897959184, y: 1),
                CGPoint(x: 0.38095279615752553, y: 0.9909911284575591),
                CGPoint(x: 0.45033980389030615, y: 0.9681219152502112),
                CGPoint(x: 0.5306122448979592, y: 0.9054054054054054),
                CGPoint(x: 0.5112516442123725, y: 0.8285976100612331),
                CGPoint(x: 0.45075210259885207, y: 0.8028057201488598),
                CGPoint(x: 0.3673469387755102, y: 0.7837837837837838),
                CGPoint(x: 0.30612244897959184, y: 0.7837837837837838),
                CGPoint(x: 0.20065369897959184, y: 0.7762880067567568),
                CGPoint(x: 0.30612244897959184, y: 0.7432432432432432),
                CGPoint(x: 0.38328334263392855, y: 0.6942608807538007),
                CGPoint(x: 0.5306122448979592, y: 0.6081081081081081),
                CGPoint(x: 0.6530612244897959, y: 0.5675675675675675)
            ],
            [
                CGPoint(x: 0.46938775510204084, y: 0.013513513513513514),
                CGPoint(x: 0.5306122448979592, y: 0),
                CGPoint(x: 0.5507426359215561, y: 0.09681619180215371),
                CGPoint(x: 0.6530612244897959, y: 0.1891891891891892),
                CGPoint(x: 0.6530612244897959, y: 0.25675675675675674)
            ],
            [
                CGPoint(x: 0.5918367346938775, y: 0.13513513513513514),
                CGPoint(x: 0.6530612244897959, y: 0.13513513513513514),
                CGPoint(x: 0.7755102040816326, y: 0.12162162162162163),
                CGPoint(x: 0.8915056501116071, y: 0.14795499234586149),
                CGPoint(x: 1, y: 0.1891891891891892),
                CGPoint(x: 1, y: 0.23873860127217061),
                CGPoint(x: 0.9813506457270408, y: 0.29180908203125),
                CGPoint(x: 0.9387755102040817, y: 0.33783783783783783),
                CGPoint(x: 0.789116061463648, y: 0.355855993322424),
                CGPoint(x: 0.6530612244897959, y: 0.36486486486486486),
                CGPoint(x: 0.5510204081632653, y: 0.36486486486486486),
                CGPoint(x: 0.46938775510204084, y: 0.36486486486486486)
            ]
        ])
    }

    private func latestBFlatMinorReadAsDFlatMinorSample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.09836065573770492, y: 0.44871794871794873),
                CGPoint(x: 0.09836065573770492, y: 0.48717948717948717),
                CGPoint(x: 0.09836065573770492, y: 0.5256410256410257),
                CGPoint(x: 0.09836065573770492, y: 0.5897435897435898),
                CGPoint(x: 0.09836065573770492, y: 0.782051282051282),
                CGPoint(x: 0.12664394691342212, y: 0.8979292649489182),
                CGPoint(x: 0.13114754098360656, y: 0.9615384615384616)
            ],
            [
                CGPoint(x: 0, y: 0.41025641025641024),
                CGPoint(x: 0.04918032786885246, y: 0.3717948717948718),
                CGPoint(x: 0.18032786885245902, y: 0.2948717948717949),
                CGPoint(x: 0.32786885245901637, y: 0.27777764736077726),
                CGPoint(x: 0.47540983606557374, y: 0.2564102564102564),
                CGPoint(x: 0.5685865058273566, y: 0.26857268504607373),
                CGPoint(x: 0.6414014472336066, y: 0.301090338291266),
                CGPoint(x: 0.6557377049180327, y: 0.358974358974359),
                CGPoint(x: 0.6405169377561475, y: 0.41501793494591344),
                CGPoint(x: 0.5796258644979508, y: 0.4802195231119792),
                CGPoint(x: 0.5245901639344263, y: 0.5384615384615384),
                CGPoint(x: 0.32786885245901637, y: 0.6153846153846154),
                CGPoint(x: 0.19649818295338115, y: 0.6645589975210336),
                CGPoint(x: 0.13114754098360656, y: 0.7051282051282052),
                CGPoint(x: 0.06488237224641394, y: 0.7014441856971154),
                CGPoint(x: 0.13114754098360656, y: 0.6666666666666666),
                CGPoint(x: 0.26313656666239754, y: 0.6194387582632211),
                CGPoint(x: 0.32786885245901637, y: 0.5897435897435898),
                CGPoint(x: 0.4106775502689549, y: 0.5809772198016827),
                CGPoint(x: 0.48244688940829916, y: 0.5885025415665064),
                CGPoint(x: 0.5737704918032787, y: 0.6282051282051282),
                CGPoint(x: 0.5737704918032787, y: 0.6794871794871795),
                CGPoint(x: 0.5737704918032787, y: 0.7393161088992388),
                CGPoint(x: 0.5737704918032787, y: 0.7948717948717948),
                CGPoint(x: 0.5573770491803278, y: 0.8717948717948718),
                CGPoint(x: 0.4262295081967213, y: 0.9487179487179487),
                CGPoint(x: 0.292328381147541, y: 0.9800681089743589),
                CGPoint(x: 0.18032786885245902, y: 1),
                CGPoint(x: 0.1238163181992828, y: 0.9885328243940305),
                CGPoint(x: 0.06526659355788934, y: 0.9462464161408253)
            ],
            [
                CGPoint(x: 0.6557377049180327, y: 0.08974358974358974),
                CGPoint(x: 0.6557377049180327, y: 0.038461538461538464),
                CGPoint(x: 0.6557377049180327, y: 0),
                CGPoint(x: 0.7049180327868853, y: 0.1367520063351362),
                CGPoint(x: 0.7540983606557377, y: 0.28205128205128205),
                CGPoint(x: 0.8032786885245902, y: 0.3717948717948718)
            ],
            [
                CGPoint(x: 0.7049180327868853, y: 0.28205128205128205),
                CGPoint(x: 0.8032786885245902, y: 0.2564102564102564),
                CGPoint(x: 0.8524590163934426, y: 0.2564102564102564),
                CGPoint(x: 0.9016393442622951, y: 0.2649571345402644),
                CGPoint(x: 0.9508196721311475, y: 0.28062673715444714),
                CGPoint(x: 1, y: 0.2948717948717949),
                CGPoint(x: 1, y: 0.34188021146334135),
                CGPoint(x: 0.9890336834016393, y: 0.38790658804086536),
                CGPoint(x: 0.934752417392418, y: 0.407710931239984),
                CGPoint(x: 0.8524590163934426, y: 0.4230769230769231),
                CGPoint(x: 0.8032786885245902, y: 0.4230769230769231),
                CGPoint(x: 0.7540983606557377, y: 0.4230769230769231)
            ],
            [
                CGPoint(x: 0.7049180327868853, y: 0.7948717948717948),
                CGPoint(x: 0.7049180327868853, y: 0.7435897435897436),
                CGPoint(x: 0.8032786885245902, y: 0.7435897435897436),
                CGPoint(x: 0.9508196721311475, y: 0.7307692307692307)
            ]
        ])
    }

    private func latestBFlatMinorReadAsEFlatMinorSample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.07246376811594203, y: 0.3333333333333333),
                CGPoint(x: 0.07246376811594203, y: 0.4074074074074074),
                CGPoint(x: 0.11594202898550725, y: 0.5740740740740741),
                CGPoint(x: 0.2028985507246377, y: 0.7777777777777778),
                CGPoint(x: 0.2028985507246377, y: 0.9259259259259259),
                CGPoint(x: 0.2028985507246377, y: 1)
            ],
            [
                CGPoint(x: 0, y: 0.2222222222222222),
                CGPoint(x: 0.10627989838088768, y: 0.19753124095775462),
                CGPoint(x: 0.2028985507246377, y: 0.16666666666666666),
                CGPoint(x: 0.3188405797101449, y: 0.16666666666666666),
                CGPoint(x: 0.37681159420289856, y: 0.16666666666666666),
                CGPoint(x: 0.36656387992527173, y: 0.2538350423177083),
                CGPoint(x: 0.319649074388587, y: 0.3272354691116898),
                CGPoint(x: 0.2463768115942029, y: 0.3888888888888889),
                CGPoint(x: 0.21495697463768115, y: 0.4341724537037037),
                CGPoint(x: 0.2168411033740942, y: 0.5134650336371528),
                CGPoint(x: 0.2898550724637681, y: 0.5185185185185185),
                CGPoint(x: 0.3719809711843297, y: 0.5246909812644676),
                CGPoint(x: 0.438003318897192, y: 0.5452677408854166),
                CGPoint(x: 0.4927536231884058, y: 0.5740740740740741),
                CGPoint(x: 0.5224830516870471, y: 0.6422921639901621),
                CGPoint(x: 0.524245994678442, y: 0.7141135886863426),
                CGPoint(x: 0.4927536231884058, y: 0.8148148148148148),
                CGPoint(x: 0.439613231714221, y: 0.8827164261429398),
                CGPoint(x: 0.36876026098278986, y: 0.9300412778501157),
                CGPoint(x: 0.2898550724637681, y: 0.9629629629629629),
                CGPoint(x: 0.21719404579936594, y: 0.9599179868344907),
                CGPoint(x: 0.11594202898550725, y: 0.8703703703703703)
            ],
            [
                CGPoint(x: 0.5362318840579711, y: 0),
                CGPoint(x: 0.5797101449275363, y: 0),
                CGPoint(x: 0.6231884057971014, y: 0.14814814814814814),
                CGPoint(x: 0.6529178342957428, y: 0.24659672489872686),
                CGPoint(x: 0.6666666666666666, y: 0.35185185185185186)
            ],
            [
                CGPoint(x: 0.5934589772984602, y: 0.1978477195457176),
                CGPoint(x: 0.6578661047894022, y: 0.16286101164641203),
                CGPoint(x: 0.7072117017663043, y: 0.1530524359809028),
                CGPoint(x: 0.7536231884057971, y: 0.14814814814814814),
                CGPoint(x: 0.8067635798799819, y: 0.14814814814814814),
                CGPoint(x: 0.8631237969882246, y: 0.1543206108940972),
                CGPoint(x: 0.9130434782608695, y: 0.2037037037037037),
                CGPoint(x: 0.8554475203804348, y: 0.2921131275318287),
                CGPoint(x: 0.7875649272531703, y: 0.3195936414930556),
                CGPoint(x: 0.7101449275362319, y: 0.3333333333333333),
                CGPoint(x: 0.6666666666666666, y: 0.3333333333333333),
                CGPoint(x: 0.6231884057971014, y: 0.3333333333333333),
                CGPoint(x: 0.5797101449275363, y: 0.3333333333333333)
            ],
            [
                CGPoint(x: 0.9130434782608695, y: 0.5185185185185185),
                CGPoint(x: 0.8695652173913043, y: 0.5370370370370371),
                CGPoint(x: 0.9251019021739131, y: 0.5082465277777778),
                CGPoint(x: 1, y: 0.46296296296296297)
            ]
        ])
    }

    private func latestFSharpMinorReadAsDSharpMinorSample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.023255813953488372, y: 0.36),
                CGPoint(x: 0, y: 0.4),
                CGPoint(x: 0, y: 0.5066666666666667),
                CGPoint(x: 0, y: 0.6533333333333333),
                CGPoint(x: 0, y: 0.8266666666666667),
                CGPoint(x: 0, y: 0.915555419921875),
                CGPoint(x: 0, y: 1)
            ],
            [
                CGPoint(x: 0.05813953488372093, y: 0.4533333333333333),
                CGPoint(x: 0.16279069767441862, y: 0.44),
                CGPoint(x: 0.25704139886900434, y: 0.4059627278645833),
                CGPoint(x: 0.32558139534883723, y: 0.38666666666666666),
                CGPoint(x: 0.3714961562045785, y: 0.35088297526041667),
                CGPoint(x: 0.41898044320039973, y: 0.32336222330729164),
                CGPoint(x: 0.46511627906976744, y: 0.30666666666666664)
            ],
            [
                CGPoint(x: 0.05813953488372093, y: 0.7466666666666667),
                CGPoint(x: 0, y: 0.7733333333333333),
                CGPoint(x: 0.05038753775663154, y: 0.7733333333333333),
                CGPoint(x: 0.10206710460574128, y: 0.7733333333333333),
                CGPoint(x: 0.16279069767441862, y: 0.7733333333333333),
                CGPoint(x: 0.25813967682594474, y: 0.765333251953125),
                CGPoint(x: 0.32558139534883723, y: 0.7333333333333333),
                CGPoint(x: 0.3843177972837936, y: 0.6975496419270834),
                CGPoint(x: 0.43023255813953487, y: 0.6666666666666666)
            ],
            [
                CGPoint(x: 0.6627906976744186, y: 0.14666666666666667),
                CGPoint(x: 0.6627906976744186, y: 0.09333333333333334),
                CGPoint(x: 0.6627906976744186, y: 0.18666666666666668),
                CGPoint(x: 0.6627906976744186, y: 0.3466666666666667),
                CGPoint(x: 0.6511627906976745, y: 0.4),
                CGPoint(x: 0.627906976744186, y: 0.4533333333333333)
            ],
            [
                CGPoint(x: 0.8372093023255814, y: 0),
                CGPoint(x: 0.8372093023255814, y: 0.04),
                CGPoint(x: 0.8372093023255814, y: 0.13333333333333333),
                CGPoint(x: 0.8372093023255814, y: 0.27111124674479165),
                CGPoint(x: 0.8372093023255814, y: 0.4),
                CGPoint(x: 0.872093023255814, y: 0.4533333333333333)
            ],
            [
                CGPoint(x: 0.627906976744186, y: 0.4266666666666667),
                CGPoint(x: 0.5697674418604651, y: 0.4266666666666667),
                CGPoint(x: 0.6046511627906976, y: 0.4),
                CGPoint(x: 0.6390874108602834, y: 0.3636629231770833),
                CGPoint(x: 0.7325581395348837, y: 0.3466666666666667),
                CGPoint(x: 0.828987299009811, y: 0.28942789713541667),
                CGPoint(x: 0.9069767441860465, y: 0.22666666666666666)
            ],
            [
                CGPoint(x: 0.6627906976744186, y: 0.44),
                CGPoint(x: 0.627906976744186, y: 0.48),
                CGPoint(x: 0.5465116279069767, y: 0.48),
                CGPoint(x: 0.6354600773301235, y: 0.490294189453125),
                CGPoint(x: 0.7001921187999637, y: 0.4923201497395833),
                CGPoint(x: 0.7674418604651163, y: 0.49333333333333335),
                CGPoint(x: 0.8127260429914608, y: 0.48737060546875),
                CGPoint(x: 0.9069767441860465, y: 0.44)
            ],
            [
                CGPoint(x: 0.7325581395348837, y: 0.9733333333333334),
                CGPoint(x: 0.7674418604651163, y: 0.92),
                CGPoint(x: 0.8023255813953488, y: 0.92),
                CGPoint(x: 0.8488372093023255, y: 0.92),
                CGPoint(x: 0.899224924486737, y: 0.92),
                CGPoint(x: 0.9418604651162791, y: 0.92),
                CGPoint(x: 1, y: 0.9066666666666666)
            ]
        ])
    }

    private func latestEFlatMinorReadAsFFlatSample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.038461538461538464, y: 0.31549888839423057),
                CGPoint(x: 0, y: 0.2704276186236262),
                CGPoint(x: 0.038461538461538464, y: 0.2503957903404691),
                CGPoint(x: 0.08943841396233974, y: 0.2436390428774015),
                CGPoint(x: 0.15384615384615385, y: 0.24038010544322327),
                CGPoint(x: 0.2948717948717949, y: 0.22535634885302183)
            ],
            [
                CGPoint(x: 0.07692307692307693, y: 0.31549888839423057),
                CGPoint(x: 0.07692307692307693, y: 0.3755939147550364),
                CGPoint(x: 0.07692307692307693, y: 0.4907758957836924),
                CGPoint(x: 0.07692307692307693, y: 0.6159740201982596),
                CGPoint(x: 0.0641025641025641, y: 0.7211403163296699),
                CGPoint(x: 0.038461538461538464, y: 0.8263066124610801),
                CGPoint(x: 0.038461538461538464, y: 0.8914097105148415),
                CGPoint(x: 0.02594620142227564, y: 0.9432377277485134),
                CGPoint(x: 0, y: 0.9915679349532961),
                CGPoint(x: 0.04251568134014423, y: 1),
                CGPoint(x: 0.11538461538461539, y: 0.9915679349532961),
                CGPoint(x: 0.15384615384615385, y: 0.9815522500560503),
                CGPoint(x: 0.2040233122996795, y: 0.9676219889330006),
                CGPoint(x: 0.2692307692307692, y: 0.9615204217728931)
            ],
            [
                CGPoint(x: 0.15384615384615385, y: 0.661045289968864),
                CGPoint(x: 0.20512820512820512, y: 0.6309977767884611),
                CGPoint(x: 0.2692307692307692, y: 0.6309977767884611),
                CGPoint(x: 0.3333333333333333, y: 0.6309977767884611),
                CGPoint(x: 0.3717948717948718, y: 0.6309977767884611)
            ],
            [
                CGPoint(x: 0.5641025641025641, y: 0),
                CGPoint(x: 0.5641025641025641, y: 0.07511878295100728),
                CGPoint(x: 0.5641025641025641, y: 0.1552456375949702),
                CGPoint(x: 0.5641025641025641, y: 0.21701002118676124),
                CGPoint(x: 0.5641025641025641, y: 0.2704276186236262)
            ],
            [
                CGPoint(x: 0.6025641025641025, y: 0.28545137521382763),
                CGPoint(x: 0.5758956517928686, y: 0.24627306026054077),
                CGPoint(x: 0.6150418795072116, y: 0.2423442708861073),
                CGPoint(x: 0.6666666666666666, y: 0.24038010544322327),
                CGPoint(x: 0.7157952724358975, y: 0.24871359542685065),
                CGPoint(x: 0.782051282051282, y: 0.2704276186236262),
                CGPoint(x: 0.8164586776342148, y: 0.31207443655181677),
                CGPoint(x: 0.7778891538962339, y: 0.35669776289625454),
                CGPoint(x: 0.6791045360076122, y: 0.3942612807697474),
                CGPoint(x: 0.6408980931991186, y: 0.41186403610323147),
                CGPoint(x: 0.6025218474559295, y: 0.4177313155552825),
                CGPoint(x: 0.5641025641025641, y: 0.4206651845256407),
                CGPoint(x: 0.5641025641025641, y: 0.36057015816483495)
            ],
            [
                CGPoint(x: 0.8589743589743589, y: 0.7962590992806772),
                CGPoint(x: 0.8205128205128205, y: 0.7511878295100728),
                CGPoint(x: 0.8205128205128205, y: 0.7061165597394684),
                CGPoint(x: 0.8589743589743589, y: 0.7061165597394684),
                CGPoint(x: 0.9081029647435898, y: 0.697783069755841),
                CGPoint(x: 1, y: 0.661045289968864)
            ]
        ])
    }

    private func latestGFlatMinorReadAsCMinorSample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0.2839506172839506, y: 0.22857142857142856),
                CGPoint(x: 0.2839506172839506, y: 0.14761919294084822),
                CGPoint(x: 0.24315351321373457, y: 0.13526742117745535),
                CGPoint(x: 0.1728395061728395, y: 0.17142857142857143),
                CGPoint(x: 0.14403241946373457, y: 0.22380937848772323),
                CGPoint(x: 0.10973970389660494, y: 0.274603271484375),
                CGPoint(x: 0.07407407407407407, y: 0.32857142857142857),
                CGPoint(x: 0.037037037037037035, y: 0.4095236642020089),
                CGPoint(x: 0, y: 0.4857142857142857),
                CGPoint(x: 0, y: 0.5809522356305804),
                CGPoint(x: 0, y: 0.6714285714285714),
                CGPoint(x: 0, y: 0.7428571428571429),
                CGPoint(x: 0, y: 0.8),
                CGPoint(x: 0, y: 0.8714285714285714),
                CGPoint(x: 0.09899751639660494, y: 0.9313262939453125),
                CGPoint(x: 0.16460955584490741, y: 0.9619049072265625),
                CGPoint(x: 0.2071337287808642, y: 0.9682538713727679),
                CGPoint(x: 0.2459988064236111, y: 0.9798941476004465),
                CGPoint(x: 0.2839506172839506, y: 1),
                CGPoint(x: 0.32098765432098764, y: 1),
                CGPoint(x: 0.35802469135802467, y: 0.9857142857142858),
                CGPoint(x: 0.40677445023148145, y: 0.924053955078125),
                CGPoint(x: 0.4691358024691358, y: 0.8571428571428571),
                CGPoint(x: 0.4691358024691358, y: 0.7809522356305804),
                CGPoint(x: 0.4691358024691358, y: 0.7222220284598214),
                CGPoint(x: 0.4691358024691358, y: 0.6714285714285714),
                CGPoint(x: 0.43209876543209874, y: 0.6476191929408482),
                CGPoint(x: 0.38342737268518517, y: 0.6047781808035714),
                CGPoint(x: 0.32098765432098764, y: 0.6),
                CGPoint(x: 0.2716049382716049, y: 0.6),
                CGPoint(x: 0.22133909625771606, y: 0.6053056989397322),
                CGPoint(x: 0.1728395061728395, y: 0.6476191929408482),
                CGPoint(x: 0.22212577160493827, y: 0.6696515764508929),
                CGPoint(x: 0.2839506172839506, y: 0.6714285714285714),
                CGPoint(x: 0.3463119695216049, y: 0.6473746163504465),
                CGPoint(x: 0.40350266444830246, y: 0.625315202985491),
                CGPoint(x: 0.49382716049382713, y: 0.5857142857142857)
            ],
            [
                CGPoint(x: 0.49382716049382713, y: 0),
                CGPoint(x: 0.49382716049382713, y: 0.04285714285714286),
                CGPoint(x: 0.49382716049382713, y: 0.11428571428571428),
                CGPoint(x: 0.49382716049382713, y: 0.18571428571428572)
            ],
            [
                CGPoint(x: 0.49382716049382713, y: 0.22857142857142856),
                CGPoint(x: 0.49382716049382713, y: 0.17142857142857143),
                CGPoint(x: 0.5308641975308642, y: 0.17142857142857143),
                CGPoint(x: 0.5679012345679012, y: 0.17142857142857143),
                CGPoint(x: 0.6172839506172839, y: 0.17142857142857143),
                CGPoint(x: 0.6790123456790124, y: 0.17142857142857143),
                CGPoint(x: 0.6902940538194444, y: 0.23437325613839285),
                CGPoint(x: 0.7160493827160493, y: 0.3142857142857143),
                CGPoint(x: 0.6493824146412037, y: 0.3600001743861607),
                CGPoint(x: 0.5950611255787037, y: 0.36761910574776785),
                CGPoint(x: 0.5308641975308642, y: 0.37142857142857144),
                CGPoint(x: 0.49382716049382713, y: 0.3142857142857143)
            ],
            [
                CGPoint(x: 0.7901234567901234, y: 0.7714285714285715),
                CGPoint(x: 0.8518518518518519, y: 0.7857142857142857),
                CGPoint(x: 0.9156539351851852, y: 0.7635044642857143),
                CGPoint(x: 0.9595389660493827, y: 0.7354540143694196),
                CGPoint(x: 1, y: 0.7142857142857143)
            ]
        ])
    }

    private func latestESharpMinorReadAsESharpSample() -> BasicMajorChordInkSample {
        normalizedTelemetrySample([
            [
                CGPoint(x: 0, y: 0.36486486486486486),
                CGPoint(x: 0.06451612903225806, y: 0.32432432432432434),
                CGPoint(x: 0.12903225806451613, y: 0.2972972972972973),
                CGPoint(x: 0.25806451612903225, y: 0.2972972972972973),
                CGPoint(x: 0.34408602150537637, y: 0.2972972972972973),
                CGPoint(x: 0.3978494623655914, y: 0.2972972972972973),
                CGPoint(x: 0.44086021505376344, y: 0.2972972972972973)
            ],
            [
                CGPoint(x: 0.0967741935483871, y: 0.43243243243243246),
                CGPoint(x: 0.0967741935483871, y: 0.47297297297297297),
                CGPoint(x: 0.07211927188340053, y: 0.5500958416913007),
                CGPoint(x: 0.06451612903225806, y: 0.6486486486486487),
                CGPoint(x: 0.010606335055443549, y: 0.7815617741765203),
                CGPoint(x: 0, y: 0.9054054054054054),
                CGPoint(x: 0.004808651503696236, y: 0.974399875950169),
                CGPoint(x: 0.06451612903225806, y: 1),
                CGPoint(x: 0.0967741935483871, y: 0.9909907160578547),
                CGPoint(x: 0.12903225806451613, y: 0.9789791622677365),
                CGPoint(x: 0.17097850512432797, y: 0.9653221336570946),
                CGPoint(x: 0.22580645161290322, y: 0.9594594594594594),
                CGPoint(x: 0.2652331936743952, y: 0.9594594594594594),
                CGPoint(x: 0.3223417548723118, y: 0.9566279230891047),
                CGPoint(x: 0.40860215053763443, y: 0.9459459459459459),
                CGPoint(x: 0.44086021505376344, y: 0.9459459459459459)
            ],
            [
                CGPoint(x: 0.16129032258064516, y: 0.7297297297297297),
                CGPoint(x: 0.25806451612903225, y: 0.6891891891891891),
                CGPoint(x: 0.33691734396001344, y: 0.6846849596178209),
                CGPoint(x: 0.40860215053763443, y: 0.6756756756756757)
            ],
            [
                CGPoint(x: 0.7526881720430108, y: 0.08108108108108109),
                CGPoint(x: 0.7526881720430108, y: 0.04054054054054054),
                CGPoint(x: 0.7526881720430108, y: 0),
                CGPoint(x: 0.7526881720430108, y: 0.0945945945945946),
                CGPoint(x: 0.7526881720430108, y: 0.17567567567567569),
                CGPoint(x: 0.7526881720430108, y: 0.25675675675675674),
                CGPoint(x: 0.7526881720430108, y: 0.33783783783783783)
            ],
            [
                CGPoint(x: 0.9032258064516129, y: 0),
                CGPoint(x: 0.9032258064516129, y: 0.06756756756756757),
                CGPoint(x: 0.9032258064516129, y: 0.10810810810810811),
                CGPoint(x: 0.9032258064516129, y: 0.14864864864864866),
                CGPoint(x: 0.9354838709677419, y: 0.17567567567567569),
                CGPoint(x: 0.9354838709677419, y: 0.2747744998416385),
                CGPoint(x: 0.9354838709677419, y: 0.36486486486486486),
                CGPoint(x: 0.9354838709677419, y: 0.4189189189189189)
            ],
            [
                CGPoint(x: 0.6559139784946236, y: 0.17567567567567569),
                CGPoint(x: 0.6989247311827957, y: 0.14864864864864866),
                CGPoint(x: 0.7455194944976479, y: 0.14864864864864866),
                CGPoint(x: 0.7849462365591398, y: 0.14864864864864866),
                CGPoint(x: 0.8422943443380376, y: 0.14864864864864866),
                CGPoint(x: 0.8946231308803764, y: 0.14054087046030406),
                CGPoint(x: 0.9354838709677419, y: 0.12162162162162163),
                CGPoint(x: 0.967741935483871, y: 0.11711739205025337),
                CGPoint(x: 1, y: 0.10810810810810811)
            ],
            [
                CGPoint(x: 0.7204301075268817, y: 0.2972972972972973),
                CGPoint(x: 0.7526881720430108, y: 0.31531504038217906),
                CGPoint(x: 0.7913975869455645, y: 0.3135136784733953),
                CGPoint(x: 0.8444443569388441, y: 0.2891895191089527),
                CGPoint(x: 0.9032258064516129, y: 0.25675675675675674),
                CGPoint(x: 0.9354838709677419, y: 0.238739013671875),
                CGPoint(x: 0.967741935483871, y: 0.22372354043496623),
                CGPoint(x: 1, y: 0.24324324324324326)
            ],
            [
                CGPoint(x: 0.6236559139784946, y: 0.8243243243243243),
                CGPoint(x: 0.7102293609290995, y: 0.8150840965477196),
                CGPoint(x: 0.7849462365591398, y: 0.8108108108108109),
                CGPoint(x: 0.8315416561659946, y: 0.7927930677259291),
                CGPoint(x: 0.8709677419354839, y: 0.7837837837837838),
                CGPoint(x: 0.9032258064516129, y: 0.7837837837837838)
            ]
        ])
    }

    private func normalizedTelemetrySample(_ strokes: [[CGPoint]]) -> BasicMajorChordInkSample {
        BasicMajorChordInkSample(
            strokes: strokes.map { stroke in
                stroke.map { point in
                    CGPoint(x: point.x * 100, y: point.y * 100)
                }
            }
        )
    }

    private func handwrittenFSample() -> BasicMajorChordInkSample {
        BasicMajorChordInkSample(strokes: [
            line(from: CGPoint(x: 15, y: 10), to: CGPoint(x: 15, y: 92)),
            line(from: CGPoint(x: 15, y: 10), to: CGPoint(x: 82, y: 10)),
            line(from: CGPoint(x: 15, y: 50), to: CGPoint(x: 66, y: 50))
        ])
    }

    private func handwrittenGSample() -> BasicMajorChordInkSample {
        var gStroke = arc(center: CGPoint(x: 52, y: 52), radius: CGSize(width: 38, height: 42), startDegrees: 35, endDegrees: 325)
        gStroke.append(contentsOf: line(from: CGPoint(x: 55, y: 58), to: CGPoint(x: 88, y: 58), points: 8))
        gStroke.append(contentsOf: line(from: CGPoint(x: 88, y: 58), to: CGPoint(x: 88, y: 45), points: 6))
        return BasicMajorChordInkSample(strokes: [gStroke])
    }

    private func chordSample(root: BasicMajorChordInkSample, accidental: Accidental) -> BasicMajorChordInkSample {
        guard let rootBounds = root.bounds else {
            return root
        }

        let accidentalX = rootBounds.maxX + 14
        let accidentalHeight = max(62, rootBounds.height * 0.82)
        let topY = rootBounds.midY - accidentalHeight / 2
        let bottomY = topY + accidentalHeight
        let accidentalStrokes: [[CGPoint]]

        switch accidental {
        case .sharp:
            let leftX = accidentalX + 8
            let rightX = accidentalX + 24
            accidentalStrokes = [
                line(from: CGPoint(x: leftX, y: topY + 4), to: CGPoint(x: leftX - 4, y: bottomY - 4)),
                line(from: CGPoint(x: rightX, y: topY + 2), to: CGPoint(x: rightX - 4, y: bottomY - 6)),
                line(from: CGPoint(x: accidentalX, y: topY + accidentalHeight * 0.38), to: CGPoint(x: accidentalX + 32, y: topY + accidentalHeight * 0.34)),
                line(from: CGPoint(x: accidentalX, y: topY + accidentalHeight * 0.62), to: CGPoint(x: accidentalX + 32, y: topY + accidentalHeight * 0.58))
            ]
        case .flat:
            let stemX = accidentalX + 8
            accidentalStrokes = [
                line(from: CGPoint(x: stemX, y: topY + 2), to: CGPoint(x: stemX, y: bottomY - 2)),
                polyline([
                    CGPoint(x: stemX, y: topY + accidentalHeight * 0.46),
                    CGPoint(x: accidentalX + 28, y: topY + accidentalHeight * 0.52),
                    CGPoint(x: accidentalX + 30, y: topY + accidentalHeight * 0.74),
                    CGPoint(x: accidentalX + 12, y: bottomY - 3),
                    CGPoint(x: stemX, y: bottomY - 5)
                ])
            ]
        case .natural:
            accidentalStrokes = []
        }

        return BasicMajorChordInkSample(strokes: root.strokes + accidentalStrokes)
    }

    private func minorDashChordSample(root: BasicMajorChordInkSample) -> BasicMajorChordInkSample {
        guard let rootBounds = root.bounds else {
            return root
        }

        let dashX = rootBounds.maxX + 18
        let dashY = rootBounds.midY + rootBounds.height * 0.02
        let dashStroke = line(
            from: CGPoint(x: dashX, y: dashY),
            to: CGPoint(x: dashX + max(24, rootBounds.width * 0.34), y: dashY + 1),
            points: 12
        )

        return BasicMajorChordInkSample(strokes: root.strokes + [dashStroke])
    }

    private func minorShortAngledDashChordSample(root: BasicMajorChordInkSample) -> BasicMajorChordInkSample {
        guard let rootBounds = root.bounds else {
            return root
        }

        let dashX = rootBounds.maxX + 18
        let dashY = rootBounds.midY - rootBounds.height * 0.16
        let dashStroke = line(
            from: CGPoint(x: dashX, y: dashY),
            to: CGPoint(x: dashX + max(14, rootBounds.width * 0.18), y: dashY - rootBounds.height * 0.10),
            points: 6
        )

        return BasicMajorChordInkSample(strokes: root.strokes + [dashStroke])
    }

    private func minorDashBelowAccidentalChordSample(
        root: BasicMajorChordInkSample,
        accidental: Accidental
    ) -> BasicMajorChordInkSample {
        guard let rootBounds = root.bounds else {
            return root
        }

        let accidentalRoot = chordSample(root: root, accidental: accidental)
        let dashX = rootBounds.maxX + 20
        let dashY = rootBounds.midY + rootBounds.height * 0.42
        let dashStroke = line(
            from: CGPoint(x: dashX, y: dashY),
            to: CGPoint(x: dashX + max(30, rootBounds.width * 0.42), y: dashY - 5),
            points: 10
        )

        return BasicMajorChordInkSample(strokes: accidentalRoot.strokes + [dashStroke])
    }

    private func minorMSuffixChordSample(root: BasicMajorChordInkSample) -> BasicMajorChordInkSample {
        guard let rootBounds = root.bounds else {
            return root
        }

        let suffixX = rootBounds.maxX + 16
        let topY = rootBounds.midY - rootBounds.height * 0.20
        let baseY = rootBounds.midY + rootBounds.height * 0.23
        let width = max(32, rootBounds.width * 0.44)
        let mStroke = polyline([
            CGPoint(x: suffixX, y: baseY),
            CGPoint(x: suffixX, y: topY + rootBounds.height * 0.05),
            CGPoint(x: suffixX + width * 0.20, y: topY),
            CGPoint(x: suffixX + width * 0.36, y: baseY),
            CGPoint(x: suffixX + width * 0.48, y: topY + rootBounds.height * 0.04),
            CGPoint(x: suffixX + width * 0.70, y: topY),
            CGPoint(x: suffixX + width, y: baseY)
        ], pointsPerSegment: 6)

        return BasicMajorChordInkSample(strokes: root.strokes + [mStroke])
    }

    private func minorMinWordSuffixChordSample(root: BasicMajorChordInkSample) -> BasicMajorChordInkSample {
        guard let rootBounds = root.bounds else {
            return root
        }

        let suffixX = rootBounds.maxX + 16
        let topY = rootBounds.midY - rootBounds.height * 0.18
        let baseY = rootBounds.midY + rootBounds.height * 0.40
        let width = max(66, rootBounds.width * 0.90)
        let mStroke = polyline([
            CGPoint(x: suffixX, y: baseY),
            CGPoint(x: suffixX, y: topY + rootBounds.height * 0.10),
            CGPoint(x: suffixX + width * 0.12, y: topY),
            CGPoint(x: suffixX + width * 0.24, y: baseY),
            CGPoint(x: suffixX + width * 0.34, y: topY + rootBounds.height * 0.05),
            CGPoint(x: suffixX + width * 0.48, y: topY),
            CGPoint(x: suffixX + width * 0.58, y: baseY)
        ], pointsPerSegment: 5)
        let iStem = line(
            from: CGPoint(x: suffixX + width * 0.70, y: topY + rootBounds.height * 0.16),
            to: CGPoint(x: suffixX + width * 0.70, y: baseY),
            points: 8
        )
        let iDot = line(
            from: CGPoint(x: suffixX + width * 0.66, y: topY - rootBounds.height * 0.10),
            to: CGPoint(x: suffixX + width * 0.76, y: topY - rootBounds.height * 0.10),
            points: 4
        )
        let nStroke = polyline([
            CGPoint(x: suffixX + width * 0.84, y: baseY),
            CGPoint(x: suffixX + width * 0.84, y: topY + rootBounds.height * 0.06),
            CGPoint(x: suffixX + width, y: baseY)
        ], pointsPerSegment: 6)

        return BasicMajorChordInkSample(strokes: root.strokes + [mStroke, iStem, iDot, nStroke])
    }

    private func wobblySharpChordSample(root: BasicMajorChordInkSample) -> BasicMajorChordInkSample {
        guard let rootBounds = root.bounds else {
            return root
        }

        let accidentalX = rootBounds.maxX + 14
        let accidentalHeight = max(62, rootBounds.height * 0.82)
        let topY = rootBounds.midY - accidentalHeight / 2
        let bottomY = topY + accidentalHeight
        let accidentalStrokes = [
            line(from: CGPoint(x: accidentalX + 8, y: topY + 3), to: CGPoint(x: accidentalX + 6, y: bottomY - 5)),
            line(from: CGPoint(x: accidentalX + 25, y: topY), to: CGPoint(x: accidentalX + 22, y: bottomY - 7)),
            polyline([
                CGPoint(x: accidentalX, y: topY + accidentalHeight * 0.34),
                CGPoint(x: accidentalX + 12, y: topY + accidentalHeight * 0.42),
                CGPoint(x: accidentalX + 31, y: topY + accidentalHeight * 0.50)
            ]),
            polyline([
                CGPoint(x: accidentalX + 2, y: topY + accidentalHeight * 0.58),
                CGPoint(x: accidentalX + 16, y: topY + accidentalHeight * 0.64),
                CGPoint(x: accidentalX + 33, y: topY + accidentalHeight * 0.70)
            ])
        ]

        return BasicMajorChordInkSample(strokes: root.strokes + accidentalStrokes)
    }

    private func wideFlatChordSample(root: BasicMajorChordInkSample) -> BasicMajorChordInkSample {
        guard let rootBounds = root.bounds else {
            return root
        }

        let accidentalX = rootBounds.maxX + 13
        let accidentalHeight = max(60, rootBounds.height * 0.82)
        let topY = rootBounds.midY - accidentalHeight / 2
        let bottomY = topY + accidentalHeight
        let stemX = accidentalX + 9
        let accidentalStrokes = [
            line(from: CGPoint(x: stemX, y: topY), to: CGPoint(x: stemX, y: bottomY - 4)),
            polyline([
                CGPoint(x: stemX, y: topY + accidentalHeight * 0.42),
                CGPoint(x: accidentalX + 25, y: topY + accidentalHeight * 0.36),
                CGPoint(x: accidentalX + 38, y: topY + accidentalHeight * 0.48),
                CGPoint(x: accidentalX + 36, y: topY + accidentalHeight * 0.64),
                CGPoint(x: accidentalX + 20, y: topY + accidentalHeight * 0.72),
                CGPoint(x: stemX, y: topY + accidentalHeight * 0.66)
            ])
        ]

        return BasicMajorChordInkSample(strokes: root.strokes + accidentalStrokes)
    }

    private func broadSharpChordSample(root: BasicMajorChordInkSample) -> BasicMajorChordInkSample {
        guard let rootBounds = root.bounds else {
            return root
        }

        let accidentalX = rootBounds.maxX + 12
        let accidentalHeight = max(60, rootBounds.height * 0.82)
        let topY = rootBounds.midY - accidentalHeight / 2
        let bottomY = topY + accidentalHeight
        let accidentalStrokes = [
            line(from: CGPoint(x: accidentalX + 8, y: topY + 4), to: CGPoint(x: accidentalX + 3, y: bottomY - 7)),
            line(from: CGPoint(x: accidentalX + 22, y: topY), to: CGPoint(x: accidentalX + 29, y: bottomY - 13)),
            polyline([
                CGPoint(x: accidentalX, y: topY + accidentalHeight * 0.26),
                CGPoint(x: accidentalX + 14, y: topY + accidentalHeight * 0.36),
                CGPoint(x: accidentalX + 30, y: topY + accidentalHeight * 0.48)
            ]),
            polyline([
                CGPoint(x: accidentalX, y: topY + accidentalHeight * 0.58),
                CGPoint(x: accidentalX + 18, y: topY + accidentalHeight * 0.68),
                CGPoint(x: accidentalX + 36, y: topY + accidentalHeight * 0.78)
            ])
        ]

        return BasicMajorChordInkSample(strokes: root.strokes + accidentalStrokes)
    }

    private func boundaryTrainingExamples(repetitions: Int) throws -> [ChordRecognitionLearningExample] {
        let samples: [(String, BasicMajorChordInkSample)] = [
            ("C", handwrittenCSample()),
            ("D", closedDSample()),
            ("E", handwrittenESample()),
            ("F", handwrittenFSample()),
            ("G", handwrittenGSample()),
            ("A", handwrittenASample()),
            ("B", handwrittenBSample())
        ]

        return try (0..<repetitions).flatMap { _ in
            try samples.map { symbol, sample in
                ChordRecognitionLearningExample(
                    match: try XCTUnwrap(BasicMajorChordCompendium.match(symbol)),
                    ink: ChordRecognitionLearningInk(sample: sample)
                )
            }
        }
    }

    private func line(from start: CGPoint, to end: CGPoint, points: Int = 16) -> [CGPoint] {
        (0..<points).map { index in
            let t = CGFloat(index) / CGFloat(points - 1)
            return CGPoint(
                x: start.x + (end.x - start.x) * t,
                y: start.y + (end.y - start.y) * t
            )
        }
    }

    private func polyline(_ points: [CGPoint], pointsPerSegment: Int = 10) -> [CGPoint] {
        guard let first = points.first else {
            return []
        }

        return points.dropFirst().reduce(into: [first]) { result, point in
            guard let start = result.last else {
                return
            }

            result.append(contentsOf: line(from: start, to: point, points: pointsPerSegment).dropFirst())
        }
    }

    private func arc(
        center: CGPoint,
        radius: CGSize,
        startDegrees: CGFloat,
        endDegrees: CGFloat,
        points: Int = 36
    ) -> [CGPoint] {
        (0..<points).map { index in
            let t = CGFloat(index) / CGFloat(points - 1)
            let degrees = startDegrees + (endDegrees - startDegrees) * t
            let radians = degrees * .pi / 180
            return CGPoint(
                x: center.x + cos(radians) * radius.width,
                y: center.y + sin(radians) * radius.height
            )
        }
    }
}

private struct ChordRecognitionHarnessCase {
    var name: String
    var expectedDisplayText: String
    var textCandidates: [String]
    var inkSample: BasicMajorChordInkSample?
}

private struct ChordRecognitionHarnessResult {
    var totalCases: Int
    var ensembleCorrect: Int
    var attemptedByMethod: [BasicMajorChordRecognitionMethod: Int]
    var correctByMethod: [BasicMajorChordRecognitionMethod: Int]
}

private enum ChordRecognitionHarness {
    static func evaluate(_ cases: [ChordRecognitionHarnessCase]) -> ChordRecognitionHarnessResult {
        var ensembleCorrect = 0
        var attemptedByMethod: [BasicMajorChordRecognitionMethod: Int] = [:]
        var correctByMethod: [BasicMajorChordRecognitionMethod: Int] = [:]

        for testCase in cases {
            let report = BasicMajorChordRecognizer.evaluate(
                textCandidates: testCase.textCandidates,
                inkSample: testCase.inkSample
            )

            if report.bestMatch?.displayText == testCase.expectedDisplayText {
                ensembleCorrect += 1
            }

            for method in BasicMajorChordRecognitionMethod.allCases {
                let methodCandidates = report.candidates.filter { $0.method == method }
                if !methodCandidates.isEmpty {
                    attemptedByMethod[method, default: 0] += 1
                }

                if methodCandidates.contains(where: { $0.match.displayText == testCase.expectedDisplayText }) {
                    correctByMethod[method, default: 0] += 1
                }
            }
        }

        return ChordRecognitionHarnessResult(
            totalCases: cases.count,
            ensembleCorrect: ensembleCorrect,
            attemptedByMethod: attemptedByMethod,
            correctByMethod: correctByMethod
        )
    }
}
