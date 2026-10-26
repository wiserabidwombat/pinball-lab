import Foundation
import Observation

private let cameraModeKey = "cameraMode"
private let multiballFullTableKey = "multiballFullTable"
private let soundVolumeKey = "soundVolume"
private let hapticsOnKey = "hapticsOn"
private let tipsOnKey = "tipsOn"
private let bonusCountOnKey = "bonusCountOn"
private let improveOnKey = "improveOn"

/// Player settings, saved in UserDefaults: camera mode (milestone 2), multiball full-table view
/// (milestone 5), and sound volume, haptics, tips and the bonus count (milestone 10).
@MainActor
@Observable
final class GameSettings {
    var cameraMode: CameraMode {
        didSet { UserDefaults.standard.set(cameraMode.rawValue, forKey: cameraModeKey) }
    }

    /// While two or more balls are in play, ease out to the whole table (on by default).
    var multiballFullTable: Bool {
        didSet { UserDefaults.standard.set(multiballFullTable, forKey: multiballFullTableKey) }
    }

    /// Sound effects volume, 0 (off) … 1.
    var soundVolume: Double {
        didSet { UserDefaults.standard.set(soundVolume, forKey: soundVolumeKey) }
    }

    /// Vibration on flips, hits and big moments.
    var hapticsOn: Bool {
        didSet {
            UserDefaults.standard.set(hapticsOn, forKey: hapticsOnKey)
            Haptic.enabled = hapticsOn
        }
    }

    /// Hints such as "Pull down on the plunger to launch".
    var tipsOn: Bool {
        didSet { UserDefaults.standard.set(tipsOn, forKey: tipsOnKey) }
    }

    /// Count the end-of-ball bonus up in the score strip (off = add it straight away).
    var bonusCountOn: Bool {
        didSet { UserDefaults.standard.set(bonusCountOn, forKey: bonusCountOnKey) }
    }

    /// Improve mode (2026-10-26): the flip-spot coach marks on the flippers (pause card; off by default).
    var improveOn: Bool {
        didSet { UserDefaults.standard.set(improveOn, forKey: improveOnKey) }
    }

    init() {
        let d = UserDefaults.standard
        cameraMode = CameraMode(rawValue: d.string(forKey: cameraModeKey) ?? "") ?? .flying
        multiballFullTable = d.object(forKey: multiballFullTableKey) as? Bool ?? true
        soundVolume = d.object(forKey: soundVolumeKey) as? Double ?? 0.8
        hapticsOn = d.object(forKey: hapticsOnKey) as? Bool ?? true
        tipsOn = d.object(forKey: tipsOnKey) as? Bool ?? true
        bonusCountOn = d.object(forKey: bonusCountOnKey) as? Bool ?? true
        improveOn = d.object(forKey: improveOnKey) as? Bool ?? false
        Haptic.enabled = hapticsOn
    }
}
