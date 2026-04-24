import Foundation

enum EditorCanvasMode: Hashable {
    case browse
    case measureEdit
    case timeSignatureEdit
    case freeHand

    var freeHandTabTitle: String {
        switch self {
        case .browse, .measureEdit, .timeSignatureEdit:
            return "Free-Hand"
        case .freeHand:
            return "Done"
        }
    }

    var freeHandTabSymbol: String {
        switch self {
        case .browse, .measureEdit, .timeSignatureEdit:
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

    var locksDocumentActions: Bool {
        self == .freeHand
    }

    var allowsMeasureSelection: Bool {
        self != .freeHand
    }

    var allowsPageInkEditing: Bool {
        self == .freeHand
    }

    var disablesPageScroll: Bool {
        self != .browse
    }
}
