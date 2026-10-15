// Pinball Lab: Orbit Pinball (table 1, Oct 2026), kept as it was. Moved in from its own app with every type
// prefixed "Orbit" and its images/sounds prefixed "orbit_" (names shared with Grey Invasion). Was Sound.swift.
import SpriteKit
import AVFoundation
import QuartzCore
import Foundation

/// Orbit's sound effects. Each case plays `orbit_sfx_<name>.wav` from the app bundle (Kenney, CC0).
/// A missing file is simply skipped.
enum OrbitSound: String, CaseIterable {
    case bumper, sling, launch, rollover, dropTarget, bank
    case wormholeIn, wormholeOut, drain, ballSave, skillShot, multiplier, flipper
}

/// Plays Orbit's sounds. Pinball Lab plumbing: the original used SKAction.playSoundFileNamed (no
/// volume control); this is Grey Invasion's lag-free AVAudioEngine player (sounds decoded once,
/// a pool of player nodes, session and engine started off the main thread), so Orbit follows the
/// shared volume setting. Same sounds, same call sites (`play(_:on:)`).
@MainActor
final class OrbitSoundPlayer {
    /// The shared sound volume (Settings), 0…1; set by OrbitTableView. 0 = silent.
    static var volume: Float = 0.8

    private let engine = AVAudioEngine()
    private var buffers: [OrbitSound: AVAudioPCMBuffer] = [:]
    private var voices: [AVAudioPlayerNode] = []
    private var busyUntil: [CFTimeInterval] = []
    private static let voiceCount = 10
    private static let audioQueue = DispatchQueue(label: "PinballLab.orbitAudio", qos: .userInitiated)
    private var starting = false

    init() {
        var format: AVAudioFormat?
        for sound in OrbitSound.allCases {
            let base = "orbit_sfx_\(sound.rawValue)"
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

    private func startEngine() {
        guard !starting, !voices.isEmpty else { return }
        starting = true
        let engine = self.engine
        let voices = self.voices
        let player = self
        Self.audioQueue.async {
            // Ambient: respects the silent switch and mixes with the player's own music.
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.ambient, options: [.mixWithOthers])
            try? session.setActive(true)
            if !engine.isRunning, (try? engine.start()) != nil {
                for voice in voices { try? voice.playAudio() }
            }
            Task { @MainActor in player.starting = false }
        }
    }

    /// `node` is unused (kept so Orbit's original call sites don't change).
    func play(_ sound: OrbitSound, on node: SKNode) {
        let volume = Self.volume
        guard volume > 0, let buffer = buffers[sound], !voices.isEmpty else { return }
        guard engine.isRunning else {
            startEngine()
            return
        }
        let now = CACurrentMediaTime()
        var pick = 0
        for i in voices.indices {
            if busyUntil[i] <= now { pick = i; break }
            if busyUntil[i] < busyUntil[pick] { pick = i }
        }
        let voice = voices[pick]
        busyUntil[pick] = now + Double(buffer.frameLength) / buffer.format.sampleRate
        voice.volume = volume
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !voice.isPlaying { try? voice.playAudio() }
    }
}
