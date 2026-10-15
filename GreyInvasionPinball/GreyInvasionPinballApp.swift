import SwiftUI
import CoreText
import Foundation

/// Pinball Lab (Oct 2026): Orbit Pinball, Grey Invasion and the tables to come, in one app.
/// (This file keeps its old name; the app was Grey Invasion Pinball until it became the collection.)
@main
struct PinballLabApp: App {
    init() {
        // Register Orbitron at launch if it's bundled (no Info.plist entry needed).
        // Until Orbitron.ttf is added, Font.orbitron falls back to the system font.
        if let url = Bundle.main.url(forResource: "Orbitron", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            PinballLabRoot()
        }
    }
}

/// Orbitron at a given size and weight, falling back to the system font if it isn't bundled.
extension Font {
    static func orbitron(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Font.custom("Orbitron", size: size).weight(weight)
    }
}
