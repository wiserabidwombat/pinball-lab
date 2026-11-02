import CoreGraphics
import Foundation

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
/// A name nobody reads is ignored silently, but it still appears in the recorded overrides, so check the spelling.
nonisolated enum LabOverrides {
    static let values: [String: Double] = {
        #if DEBUG
        guard let s = UserDefaults.standard.string(forKey: "override"), !s.isEmpty else { return [:] }
        var out: [String: Double] = [:]
        for part in s.split(whereSeparator: { $0 == "," || $0 == ";" }) {
            let kv = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if kv.count == 2, !kv[0].isEmpty, let v = Double(kv[1]) { out[kv[0]] = v }
        }
        return out
        #else
        return [:]
        #endif
    }()

    /// The tunable's value: the override if one was given, else `fallback`.
    static func cg(_ name: String, _ fallback: CGFloat) -> CGFloat {
        values[name].map { CGFloat($0) } ?? fallback
    }

    /// What a lab JSON records (nil when nothing was overridden, so old and new reports read the same).
    static var recorded: [String: Double]? { values.isEmpty ? nil : values }
}
