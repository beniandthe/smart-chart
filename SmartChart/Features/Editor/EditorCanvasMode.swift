import Foundation

enum EditorCanvasMode: Hashable {
    case browse
    case measureEdit
    case timeSignatureEdit
    case rhythmicNotationEdit
    case freeHand

    var freeHandTabTitle: String {
        switch self {
        case .browse, .measureEdit, .timeSignatureEdit, .rhythmicNotationEdit:
            return "Free-Hand"
        case .freeHand:
            return "Done"
        }
    }

    var freeHandTabSymbol: String {
        switch self {
        case .browse, .measureEdit, .timeSignatureEdit, .rhythmicNotationEdit:
            return "pencil.and.scribble"
        case .freeHand:
            return "pencil.slash"
        }
    }

    var showsMeasureResizeHandles: Bool {
        self == .measureEdit
    }

    var showsTimeSignatureTargeting: Bool {
        self == .timeSignatureEdit
    }

    var showsRhythmicNotationTargeting: Bool {
        self == .rhythmicNotationEdit
    }

    var locksDocumentActions: Bool {
        self == .freeHand
    }

    var allowsMeasureSelection: Bool {
        self != .freeHand
    }

    var allowsDirectRhythmicNotationInk: Bool {
        self == .rhythmicNotationEdit
    }

    var allowsPageInkEditing: Bool {
        self == .freeHand
    }

    var allowsAnyInkEditing: Bool {
        allowsPageInkEditing || allowsDirectRhythmicNotationInk
    }

    var disablesPageScroll: Bool {
        self != .browse
    }
}
