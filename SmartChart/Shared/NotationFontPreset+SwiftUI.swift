import SwiftUI

extension NotationFontPreset {
    func notationPreviewFont(size: CGFloat) -> Font {
        #if canImport(UIKit)
        NotationFontRegistrar.registerBundledFontsIfNeeded()
        #endif
        return .custom(postScriptName, size: size)
    }

    func textPreviewFont(size: CGFloat) -> Font {
        #if canImport(UIKit)
        NotationFontRegistrar.registerBundledFontsIfNeeded()
        #endif

        guard let textPostScriptName else {
            return .system(size: size, weight: .semibold)
        }

        return .custom(textPostScriptName, size: size)
    }
}
