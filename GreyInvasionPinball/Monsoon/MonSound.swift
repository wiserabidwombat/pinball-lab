// Pinball Lab Table 04 (Monsoon), juice round 1: the table's own sounds. Table 03's lag-free AVAudioEngine player
// (CthSound.swift) copied with the Mon prefix, keyed by Monsoon's events and playing `mon_sfx_<name>.wav`.
import SpriteKit
import AVFoundation
import QuartzCore
import Foundation

/// Monsoon's sound effects (tools/mon_make_sfx.py): mechanical parts from Kenney Impact Sounds (CC0); the storm and the
/// paint (thunder, raindrops, brush washes, desert chimes, sand, the helix whir) synthesized. A missing file is skipped.
enum MonSound: String, CaseIterable {
    // parts
    case flipper, sling, gate, spinner, scoopIn, scoopOut, kickback, launch, upKick, standup, captiveKnock, diverter
    case bumper, lane, lanesComplete, skillShot, ramp, orbit, helix, saguaros, captiveTop, dustDevil, ballSave, drain
    // the painting and the storm
    case wash, regionPainted, monsoonLit, monsoonStart, jackpot, stormPasses
    case superbloomLit, superbloomStart, bloom, superJackpot, paintingFinished, newSketch
}

/// The storm bed's layers (mon_loop_<name>.wav, tools/mon_make_loops.py): dry desert wind and cicadas, distant thunder,
/// rain, and birds after the storm.
enum MonLoop: String, CaseIterable {
    case desert, thunder, rain, birds
}

/// Plays Table 03's sounds at the player's volume: every sound decoded into memory once, a fixed set of
/// player nodes ("voices") that just queue a buffer, the session and engine started off the main thread.
@MainActor
final class MonSoundPlayer {
    private let engine = AVAudioEngine()
    private var buffers: [MonSound: AVAudioPCMBuffer] = [:]
    private var voices: [AVAudioPlayerNode] = []
    /// When each voice finishes its current sound, so a new sound takes an idle voice
    /// instead of cutting off a long one (the Awakening, say).
    private var busyUntil: [CFTimeInterval] = []
    private static let voiceCount = 12
    private static let audioQueue = DispatchQueue(label: "PinballLab.monAudio", qos: .userInitiated)
    private var starting = false
    /// T3 M9 v2 (Aaron: no sound at all): what the debug tag shows. Sounds played, skipped because the engine
    /// wasn't running, and skipped for volume 0 / a missing file.
    private(set) var played = 0
    private(set) var skippedEngine = 0
    private(set) var skippedOther = 0
    private(set) var engineError = ""

    // M10 v3 (juice round 2): the storm bed, four looping layers (tools/mon_make_loops.py, seamless 12 s each) on
    // their own player nodes. The scene sets each layer's target volume every frame; layers fade toward it slowly
    // (the weather changes, it doesn't cut) and stop once silent.
    private var loopNodes: [MonLoop: AVAudioPlayerNode] = [:]
    private var loopBuffers: [MonLoop: AVAudioPCMBuffer] = [:]
    private var loopVolume: [MonLoop: Float] = [:]
    private var loopTarget: [MonLoop: Float] = [:]
    private var loopsHeld = false
    /// Fade speeds, volume units per second (in ≈ 3 s to full, out ≈ 2 s).
    private static let loopFadeIn: Float = 0.33
    private static let loopFadeOut: Float = 0.5

    /// e.g. "snd 39/12 on · 14 played · 0 eng · 0 other · vol 0.80": files loaded / voices, engine running,
    /// counts, the device's output volume.
    var debugStatus: String {
        let vol = AVAudioSession.sharedInstance().outputVolume
        let err = engineError.isEmpty ? "" : " · \(engineError)"
        return "snd \(buffers.count)/\(voices.count) \(engine.isRunning ? "on" : "OFF") · \(played) played · "
            + "\(skippedEngine) eng · \(skippedOther) other · vol \(String(format: "%.2f", vol))\(err)"
    }

    init() {
        // mon_make_sfx.py writes them all in one format (44.1 kHz mono), so one set of voices plays any of them.
        var format: AVAudioFormat?
        for sound in MonSound.allCases {
            let base = "mon_sfx_\(sound.rawValue)"
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

        for loop in MonLoop.allCases {
            guard let url = Bundle.main.url(forResource: "mon_loop_\(loop.rawValue)", withExtension: "wav"),
                  let file = try? AVAudioFile(forReading: url), file.processingFormat == format,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil else { continue }
            let node = AVAudioPlayerNode()
            engine.attach(node)
            guard (try? engine.connectNode(node, to: engine.mainMixerNode, format: format)) != nil else { continue }
            node.volume = 0
            loopNodes[loop] = node
            loopBuffers[loop] = buffer
            loopVolume[loop] = 0
            loopTarget[loop] = 0
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
    func play(_ sound: MonSound, volume: Float) {
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

    /// A storm-bed layer's target volume, 0…1 (0 = fade out and stop).
    func setLoop(_ loop: MonLoop, target: Float) {
        loopTarget[loop] = max(0, min(1, target))
    }

    /// Call every frame: fades each layer toward its target, starting it (from the top) when it's wanted and not
    /// playing, stopping it once it has faded out.
    func stepLoops(dt: Float) {
        guard !loopsHeld else { return }
        for (loop, node) in loopNodes {
            guard let buffer = loopBuffers[loop] else { continue }
            let target = loopTarget[loop] ?? 0
            var volume = loopVolume[loop] ?? 0
            if volume < target {
                volume = min(target, volume + Self.loopFadeIn * dt)
            } else if volume > target {
                volume = max(target, volume - Self.loopFadeOut * dt)
            }
            loopVolume[loop] = volume
            if target > 0, !node.isPlaying, engine.isRunning {
                node.stop()                                          // clear anything left from an interruption
                node.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
                try? node.playAudio()
            }
            node.volume = volume
            if target == 0, volume <= 0, node.isPlaying { node.stop() }
        }
    }

    /// Pause (true) or resume (false) the bed where it is, for the pause card.
    func holdLoops(_ held: Bool) {
        guard held != loopsHeld else { return }
        loopsHeld = held
        for (loop, node) in loopNodes {
            if held {
                if node.isPlaying { node.pause() }
            } else if (loopVolume[loop] ?? 0) > 0, engine.isRunning {
                try? node.playAudio()                                // resumes from where it paused
            }
        }
    }

    /// Silence the bed at once (the menu, a new game).
    func stopLoops() {
        loopsHeld = false
        for (loop, node) in loopNodes {
            loopTarget[loop] = 0
            loopVolume[loop] = 0
            node.stop()
        }
    }
}
