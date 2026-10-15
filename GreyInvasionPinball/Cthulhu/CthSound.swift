// Pinball Lab Table 03 (Cthulhu Rising), juice round 1: the table's own sounds. Grey Invasion's lag-free
// AVAudioEngine player (Sound.swift), keyed by Table 03's events and playing `cth_sfx_<name>.wav`.
import SpriteKit
import AVFoundation
import QuartzCore
import Foundation

/// Table 03's sound effects (tools/cth_make_sfx.py): mechanical parts from Kenney Impact Sounds (CC0), the
/// table's own voice (bells, gongs, chants, Cthulhu's roar) synthesized. A missing file is simply skipped.
enum CthSound: String, CaseIterable {
    // parts
    case flipper, bumper, sling, sigilTarget, gate, spinner, scoopIn, scoopOut, kickback, launch, upKick
    case candleLane, lanesComplete, skillShot, ramp, orbit, sigilBank, ballSave, drain
    case magnetGrab, magnetFling, cthulhuHit
    // the story
    case clue, page, libraryLit, tomeStarted, tomeFinished, failed
    case ritualLit, ritualStarted, candle, summoning
    case awakening, tentacleHit, tentacleCut, eyeOpen, eyeStruck, banished, escaped
}

/// Plays Table 03's sounds at the player's volume: every sound decoded into memory once, a fixed set of
/// player nodes ("voices") that just queue a buffer, the session and engine started off the main thread.
@MainActor
final class CthSoundPlayer {
    private let engine = AVAudioEngine()
    private var buffers: [CthSound: AVAudioPCMBuffer] = [:]
    private var voices: [AVAudioPlayerNode] = []
    /// When each voice finishes its current sound, so a new sound takes an idle voice
    /// instead of cutting off a long one (the Awakening, say).
    private var busyUntil: [CFTimeInterval] = []
    private static let voiceCount = 12
    private static let audioQueue = DispatchQueue(label: "PinballLab.cthAudio", qos: .userInitiated)
    private var starting = false
    /// T3 M9 v2 (Aaron: no sound at all): what the debug tag shows. Sounds played, skipped because the engine
    /// wasn't running, and skipped for volume 0 / a missing file.
    private(set) var played = 0
    private(set) var skippedEngine = 0
    private(set) var skippedOther = 0
    private(set) var engineError = ""

    // Juice round 2 (T3 M9 v3): one looping bed, the Awakening drone (cth_loop_awakening.wav, a seamless 8 s loop),
    // on its own player node. The scene sets a target volume every frame; the loop fades toward it and stops at 0.
    private let loopNode = AVAudioPlayerNode()
    private var loopBuffer: AVAudioPCMBuffer?
    private var loopVolume: Float = 0
    private var loopTarget: Float = 0
    private var loopHeld = false
    /// Fade speeds, volume units per second (in ≈ 2 s to full, out ≈ 1.2 s).
    private static let loopFadeIn: Float = 0.5
    private static let loopFadeOut: Float = 0.85

    /// e.g. "snd 39/12 on · 14 played · 0 eng · 0 other · vol 0.80": files loaded / voices, engine running,
    /// counts, the device's output volume.
    var debugStatus: String {
        let vol = AVAudioSession.sharedInstance().outputVolume
        let err = engineError.isEmpty ? "" : " · \(engineError)"
        return "snd \(buffers.count)/\(voices.count) \(engine.isRunning ? "on" : "OFF") · \(played) played · "
            + "\(skippedEngine) eng · \(skippedOther) other · vol \(String(format: "%.2f", vol))\(err)"
    }

    init() {
        // cth_make_sfx.py writes them all in one format (44.1 kHz mono), so one set of voices plays any of them.
        var format: AVAudioFormat?
        for sound in CthSound.allCases {
            let base = "cth_sfx_\(sound.rawValue)"
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

        if let url = Bundle.main.url(forResource: "cth_loop_awakening", withExtension: "wav"),
           let file = try? AVAudioFile(forReading: url), file.processingFormat == format,
           let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)),
           (try? file.read(into: buffer)) != nil {
            engine.attach(loopNode)
            if (try? engine.connectNode(loopNode, to: engine.mainMixerNode, format: format)) != nil {
                loopBuffer = buffer
            }
        }

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
    func play(_ sound: CthSound, volume: Float) {
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

    /// The loop's target volume, 0…1 (0 = fade out and stop).
    func setLoop(target: Float) {
        loopTarget = max(0, min(1, target))
    }

    /// Call every frame: fades the loop toward its target, starting it (from the top) when it's wanted and not
    /// playing, stopping it once it has faded out.
    func stepLoop(dt: Float) {
        guard let buffer = loopBuffer, !loopHeld else { return }
        if loopVolume < loopTarget {
            loopVolume = min(loopTarget, loopVolume + Self.loopFadeIn * dt)
        } else if loopVolume > loopTarget {
            loopVolume = max(loopTarget, loopVolume - Self.loopFadeOut * dt)
        }
        if loopTarget > 0, !loopNode.isPlaying, engine.isRunning {
            loopNode.stop()                                          // clear anything left from an interruption
            loopNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            try? loopNode.playAudio()
        }
        loopNode.volume = loopVolume
        if loopTarget == 0, loopVolume <= 0, loopNode.isPlaying {
            loopNode.stop()
        }
    }

    /// Pause (true) or resume (false) the loop where it is, for the pause card and going to the background.
    func holdLoop(_ held: Bool) {
        guard held != loopHeld, loopBuffer != nil else { return }
        loopHeld = held
        if held {
            if loopNode.isPlaying { loopNode.pause() }
        } else if loopVolume > 0, engine.isRunning {
            try? loopNode.playAudio()                                // resumes from where it paused
        }
    }

    /// Silence the loop at once (the menu, a new game).
    func stopLoop() {
        loopTarget = 0
        loopVolume = 0
        loopHeld = false
        loopNode.stop()
    }
}
