import CoreGraphics
import Foundation
#if DEBUG
import SwiftUI
#endif

/// Plan 2 round 18: what-if overrides for table tunables (Debug builds only; a Release build always uses the defaults).
///
/// Launch with `-override "Mon.ragingPush=2000,Mon.calmBend=0.0009"`, or from the Mac's runners:
/// `OVERRIDE="Mon.ragingPush=2000" tools/shotlab_run.sh monsoon devilraging` (or tools/playlab_run.sh). A tunable reads its
/// value with `LabOverrides.cg("Mon.ragingPush", 1600)`: the override if one was given, else the default. Every Shot Lab
/// and Play Lab JSON records the overrides it ran with, so an A/B needs no edit-build cycle and the report says which
/// side it is.
///
/// Tunables so far (name → default):
///   Mon.calmPush 600 · Mon.ragingPush 1600 · Mon.calmBend 0.00045 · Mon.ragingBend 0.0025   (MonDustDevil)
/// Switches (1 = on, 0 = off; read with `LabOverrides.on`), the Play Lab robots' rounds 8–11 features, all on by default:
///   Lab.nudge (8, advanced + expert) · Lab.deadBounce (9, expert) · Lab.postPass (10, expert) · Lab.mbTrap (11, expert)
/// A name nobody reads is ignored silently, but it still appears in the recorded overrides, so check the spelling.
/// On the phone, the pause card's override field (LabOverridesField, Debug) replaces them while the app runs; every
/// tunable is read when it's used, so a change applies at once.
nonisolated enum LabOverrides {
    nonisolated(unsafe) static private(set) var values: [String: Double] = {
        #if DEBUG
        return parse(UserDefaults.standard.string(forKey: "override") ?? "")
        #else
        return [:]
        #endif
    }()

    /// "Name=value, Name=value" (commas or semicolons) → the overrides; parts that don't parse are skipped.
    static func parse(_ s: String) -> [String: Double] {
        var out: [String: Double] = [:]
        for part in s.split(whereSeparator: { $0 == "," || $0 == ";" }) {
            let kv = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if kv.count == 2, !kv[0].isEmpty, let v = Double(kv[1]) { out[kv[0]] = v }
        }
        return out
    }

    #if DEBUG
    /// The pause card's field: replace every override (until the app quits); "" clears them.
    static func set(_ text: String) { values = parse(text) }

    /// The overrides as the field shows them ("Lab.nudge=0, Mon.calmPush=900").
    static var text: String {
        values.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value == $0.value.rounded() && abs($0.value) < 1e9 ? String(Int($0.value)) : String($0.value))" }
            .joined(separator: ", ")
    }
    #endif

    /// The tunable's value: the override if one was given, else `fallback`.
    static func cg(_ name: String, _ fallback: CGFloat) -> CGFloat {
        values[name].map { CGFloat($0) } ?? fallback
    }

    /// A switch: off when overridden to 0, otherwise `fallback` (on).
    static func on(_ name: String, _ fallback: Bool = true) -> Bool {
        values[name].map { $0 != 0 } ?? fallback
    }

    /// What a lab JSON records (nil when nothing was overridden, so old and new reports read the same).
    static var recorded: [String: Double]? { values.isEmpty ? nil : values }
}

#if DEBUG
/// The pause card's what-if overrides (Debug): a button showing what's active; tapping it opens an alert with a text
/// field (alerts sit above the keyboard — a field on the card was hidden by it). Type `Name=value, …` and Set — e.g.
/// `Lab.nudge=0` or `Mon.calmPush=900`. Applies at once (a lab run started after it records them); lasts until the
/// app quits; Clear removes them.
struct LabOverridesField: View {
    @State private var text = LabOverrides.text
    @State private var shown = LabOverrides.text
    @State private var editing = false

    var body: some View {
        Button {
            text = shown
            editing = true
        } label: {
            Text(shown.isEmpty ? "What-if: none" : "What-if: \(shown)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.18), in: Capsule())
        }
        .foregroundStyle(.orange)
        .frame(maxWidth: 320)
        .alert("What-if overrides", isPresented: $editing) {
            TextField("Lab.nudge=0, Mon.calmPush=900", text: $text)
                .font(.system(size: 13, design: .monospaced))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Set") { apply(text) }
            Button("Clear", role: .destructive) { apply("") }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Name=value, separated by commas. Applies now, until the app quits.")
        }
    }

    private func apply(_ value: String) {
        LabOverrides.set(value)
        shown = LabOverrides.text
        text = shown
    }
}
#endif
