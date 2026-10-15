import SpriteKit
import AVFoundation
import QuartzCore
import Foundation

/// Sound effects (milestone 9 round 2). Each case plays `sfx_<name>.wav` from the app bundle,
/// made by tools/make_sfx.py from Kenney's Sci-fi Sounds and Impact Sounds (CC0).
/// A missing file is simply skipped, so the game still runs without it.
enum Sound: String, CaseIterable {
    case flipper, bumper, sling, launch, rollover, multiplier, dropTarget, bank
    case scoopIn, scoopOut, ramp, orbit, drain, ballSave, skillShot, lock, multiball, jackpot
    case waveStart, scoutDown, waveCleared, cowSaved, cowTaken
    case mothership, coreHit, mothershipBoom, extraBall, kickback
}

/// Plays the sound effects at the player's volume.
/// M10 v3 (Aaron: "lag and skips during playing"): AVAudioEngine instead of AVAudioPlayer.
/// M10 v6: iOS 27 APIs (connectNode, playAudio) and the session/engine start off the main thread.
/// AVAudioPlayer.play() and seeking do blocking work on the main thread, a frame hitch on every
/// bumper and flipper. Here every sound is decoded into memory once at launch and a fixed set of
/// player nodes ("voices") just queue a buffer, which is cheap enough for the game loop.
@MainActor
final class SoundPlayer {
    private let engine = AVAudioEngine()
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var voices: [AVAudioPlayerNode] = []
    /// When each voice finishes its current sound, so a new sound takes an idle voice
    /// instead of cutting off a long one (the Mothership explosion, say).
    private var busyUntil: [CFTimeInterval] = []
    private static let voiceCount = 12
    /// M10 v6 (Xcode: "AVAudioSession Hang Risk"): turning the audio session on and starting the
    /// engine can block, so both happen on this queue instead of the main thread.
    private static let audioQueue = DispatchQueue(label: "GreyInvasion.audio", qos: .userInitiated)
    private var starting = false

    init() {
        // Decode every sound once. make_sfx.py writes them all in one format (44.1 kHz mono),
        // so one set of voices can play any of them; a file in another format is skipped.
        var format: AVAudioFormat?
        for sound in Sound.allCases {
            let base = "sfx_\(sound.rawValue)"
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

    /// Starts (or restarts) the engine and its voices in the background. iOS stops the engine after
    /// an audio interruption or a route change (headphones in or out); `play` calls this again then,
    /// and sounds are skipped for the moment it takes.
    private func startEngine() {
        guard !starting, !voices.isEmpty else { return }
        starting = true
        let engine = self.engine                         // AVAudioEngine and the nodes are Sendable on iOS 27
        let voices = self.voices
        let player = self                                // a constant (not a weak var) so the hop back is clean
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

    /// `volume` 0…1 (the settings slider). 0 plays nothing.
    func play(_ sound: Sound, volume: Float) {
        guard volume > 0, let buffer = buffers[sound], !voices.isEmpty else { return }
        guard engine.isRunning else {
            startEngine()
            return
        }
        // An idle voice if there is one, otherwise the one closest to finishing.
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
