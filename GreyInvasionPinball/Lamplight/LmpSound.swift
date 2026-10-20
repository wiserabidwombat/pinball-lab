// Pinball Lab Table 05 (The Lamplight), juice round 1 (T5 M9 v41): the table's own sounds, which replace the Monsoon set
// it borrowed. Grey Invasion's lag-free AVAudioEngine player (as Cthulhu's CthSoundPlayer, without the loop), keyed by
// the Lamplight's events and playing `lmp_sfx_<name>.wav` (tools/lmp_make_sfx.py).
import SpriteKit
import AVFoundation
import QuartzCore
import Foundation

/// Table 05's sound effects (tools/lmp_make_sfx.py): mechanical parts from Kenney Impact Sounds (CC0); the shop's own
/// voice (the door bell, teacup clinks, the till, pages, the fire, warm chimes, the cat) synthesized. A missing file is
/// simply skipped.
enum LmpSound: String, CaseIterable {
    // parts
    case flipper, sling, post, gate, spinner, scoopIn, scoopOut, launch, teacup, screenPanel
    // shots
    case ramp, orbit, loftPlunge, dumbwaiter, catFlap, fireplace, fireplaceOpen, drain, ballSave
    // the shop
    case regular, find, rareFind, thankYou, rush, festival
    // the cat
    case catWake, catPet, catSwat, catGift
}

/// Plays Table 05's sounds at the player's volume: every sound decoded into memory once, a fixed set of
/// player nodes ("voices") that just queue a buffer, the session and engine started off the main thread.
@MainActor
final class LmpSoundPlayer {
    private let engine = AVAudioEngine()
    private var buffers: [LmpSound: AVAudioPCMBuffer] = [:]
    private var voices: [AVAudioPlayerNode] = []
    /// When each voice finishes its current sound, so a new sound takes an idle voice
    /// instead of cutting off a long one (Festival Night's chimes, say).
    private var busyUntil: [CFTimeInterval] = []
    private static let voiceCount = 12
    private static let audioQueue = DispatchQueue(label: "PinballLab.lmpAudio", qos: .userInitiated)
    private var starting = false
    /// T3 M9 v2 (Aaron: no sound at all): what the debug tag shows. Sounds played, skipped because the engine
    /// wasn't running, and skipped for volume 0 / a missing file.
    private(set) var played = 0
    private(set) var skippedEngine = 0
    private(set) var skippedOther = 0
    private(set) var engineError = ""

    /// e.g. "snd 39/12 on · 14 played · 0 eng · 0 other · vol 0.80": files loaded / voices, engine running,
    /// counts, the device's output volume.
    var debugStatus: String {
        let vol = AVAudioSession.sharedInstance().outputVolume
        let err = engineError.isEmpty ? "" : " · \(engineError)"
        return "snd \(buffers.count)/\(voices.count) \(engine.isRunning ? "on" : "OFF") · \(played) played · "
            + "\(skippedEngine) eng · \(skippedOther) other · vol \(String(format: "%.2f", vol))\(err)"
    }

    init() {
        // lmp_make_sfx.py writes them all in one format (44.1 kHz mono), so one set of voices plays any of them.
        var format: AVAudioFormat?
        for sound in LmpSound.allCases {
            let base = "lmp_sfx_\(sound.rawValue)"
            guard let url = ["wav", "caf", "m4a"].lazy
                    .compactMap({ Bundle.main.url(forResource: base, withExtension: $0) }).first,
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil else { continue }
            if format == nil { format = file.processingFormat }
            guard file.processingFormat == format else { continue }
            buffers[sound] = buffer
        }
        guard let format else { return }

        for _ in 0..<Self.voiceCount {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            do { try engine.connectNode(node, to: engine.mainMixerNode, format: format) } catch { continue }
            voices.append(node)
            busyUntil.append(0)
        }
        engine.prepare()
        startEngine()
    }

    /// Starts (or restarts, after an interruption or a route change) the engine and its voices in the background.
    private func startEngine() {
        guard !starting, !voices.isEmpty else { return }
        starting = true
        let engine = self.engine
        let voices = self.voices
        let player = self
        Self.audioQueue.async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, options: [.mixWithOthers])
            try? session.setActive(true)
            var failure = ""
            if !engine.isRunning {
                do {
                    try engine.start()
                    for voice in voices { try? voice.playAudio() }
                } catch {
                    failure = "start: \((error as NSError).code)"
                }
            }
            let failureText = failure                    // a constant for the hop back to the main actor
            Task { @MainActor in
                player.starting = false
                player.engineError = failureText
            }
        }
    }

    /// `volume` 0…1 (the settings slider × any per-call gain). 0 plays nothing.
    func play(_ sound: LmpSound, volume: Float) {
        guard volume > 0, let buffer = buffers[sound], !voices.isEmpty else { skippedOther += 1; return }
        guard engine.isRunning else {
            skippedEngine += 1
            startEngine()
            return
        }
        played += 1
        let now = CACurrentMediaTime()
        var pick = 0
        for i in voices.indices {
            if busyUntil[i] <= now { pick = i; break }
            if busyUntil[i] < busyUntil[pick] { pick = i }
        }
        let node = voices[pick]
        busyUntil[pick] = now + Double(buffer.frameLength) / buffer.format.sampleRate
        node.volume = volume
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying { try? node.playAudio() }
    }
}
