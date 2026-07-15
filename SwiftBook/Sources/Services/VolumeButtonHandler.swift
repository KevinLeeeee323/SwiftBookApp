import AVFoundation
import MediaPlayer
import UIKit

// MARK: - Volume Button Handler
// Detects volume button presses via AVAudioSession.outputVolume KVO and turns
// them into page-turn callbacks. A hidden MPVolumeView added to the key window
// suppresses the system volume HUD and lets us silently reset the volume back to
// a baseline so there is always headroom to press up AND down.
final class VolumeButtonHandler: ObservableObject {
    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?

    private let session = AVAudioSession.sharedInstance()
    private var observer: NSKeyValueObservation?
    private var volumeView: MPVolumeView?
    private var silencePlayer: AVAudioPlayer?

    private let baseline: Float = 0.5
    private var originalVolume: Float = 0.5
    private var isAdjusting = false      // true while we are resetting volume ourselves
    private var isRunning = false

    // MARK: - Start
    func start() {
        guard !isRunning else { return }
        isRunning = true

        installHiddenVolumeView()

        do {
            // .playback routes to the media volume (which the HUD/MPVolumeView
            // controls) and makes outputVolume observation reliable.
            // .mixWithOthers keeps any background audio playing.
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("VolumeButtonHandler: audio session error \(error)")
        }

        // Keep the session actively outputting (inaudible) silence. Without live
        // output, outputVolume KVO frequently does NOT fire — especially in the
        // Simulator — and the volume buttons fall back to the ringer volume.
        startSilentAudio()

        originalVolume = session.outputVolume

        // Prime to a mid level (after the slider subview exists) so the first
        // press in either direction produces a detectable change.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self = self, self.isRunning else { return }
            self.setSystemVolume(self.baseline)
        }

        observer = session.observe(\.outputVolume, options: [.old, .new]) { [weak self] _, change in
            let newValue = change.newValue
            let oldValue = change.oldValue
            // Marshal onto main so all state (isAdjusting/isRunning/callbacks) is
            // touched from one thread — KVO delivery thread is not guaranteed.
            DispatchQueue.main.async {
                guard let self = self, self.isRunning, !self.isAdjusting else { return }
                guard let newValue = newValue else { return }
                let delta = newValue - (oldValue ?? self.baseline)
                // Ignore tiny/no-op changes.
                guard abs(delta) >= 0.003 else { return }

                if delta > 0 {
                    self.onVolumeUp?()
                } else {
                    self.onVolumeDown?()
                }
                // Reset back to baseline so the next press is detectable too.
                self.resetToBaseline()
            }
        }
    }

    // MARK: - Stop
    func stop() {
        guard isRunning else { return }
        isRunning = false
        observer = nil
        silencePlayer?.stop()
        silencePlayer = nil
        // Restore the user's original media volume.
        setSystemVolume(originalVolume)
        volumeView?.removeFromSuperview()
        volumeView = nil
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Silent keep-alive audio
    private func startSilentAudio() {
        guard silencePlayer == nil else { return }
        do {
            let player = try AVAudioPlayer(data: Self.silentWAVData())
            player.numberOfLoops = -1   // loop forever
            player.volume = 0           // inaudible
            player.prepareToPlay()
            player.play()
            silencePlayer = player
        } catch {
            print("VolumeButtonHandler: silent audio error \(error)")
        }
    }

    /// Builds a tiny in-memory 16-bit PCM WAV of pure silence (no bundled asset needed).
    private static func silentWAVData(durationSeconds: Double = 2.0, sampleRate: UInt32 = 8000) -> Data {
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = UInt32(bitsPerSample / 8)
        let numSamples = UInt32(Double(sampleRate) * durationSeconds)
        let dataSize = numSamples * bytesPerSample * UInt32(numChannels)
        let byteRate = sampleRate * UInt32(numChannels) * bytesPerSample
        let blockAlign = UInt16(UInt32(numChannels) * bytesPerSample)

        var d = Data()
        func put32(_ v: UInt32) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func put16(_ v: UInt16) { var x = v.littleEndian; withUnsafeBytes(of: &x) { d.append(contentsOf: $0) } }
        func putStr(_ s: String) { d.append(contentsOf: Array(s.utf8)) }

        putStr("RIFF"); put32(36 + dataSize); putStr("WAVE")
        putStr("fmt "); put32(16); put16(1); put16(numChannels)
        put32(sampleRate); put32(byteRate); put16(blockAlign); put16(bitsPerSample)
        putStr("data"); put32(dataSize)
        d.append(Data(count: Int(dataSize)))   // silence (zeros)
        return d
    }

    // MARK: - Hidden MPVolumeView
    private func installHiddenVolumeView(retriesLeft: Int = 5) {
        guard volumeView == nil else { return }
        guard let window = Self.activeWindow() else {
            // The key window may not be in the hierarchy yet (start() runs from
            // onAppear). Without the MPVolumeView we get neither HUD suppression nor
            // a UISlider to reset the baseline, so retry a few times before giving up.
            guard retriesLeft > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self, self.isRunning else { return }
                self.installHiddenVolumeView(retriesLeft: retriesLeft - 1)
            }
            return
        }
        // On-screen but effectively invisible: iOS only suppresses the volume HUD
        // when a real MPVolumeView is present inside the visible window hierarchy.
        let mpv = MPVolumeView(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        mpv.alpha = 0.012
        mpv.isUserInteractionEnabled = false
        mpv.clipsToBounds = true
        window.addSubview(mpv)
        volumeView = mpv
        // Prime to a mid level now that the slider exists, so the first press in
        // either direction produces a detectable change.
        setSystemVolume(baseline)
    }

    // MARK: - Volume reset
    private func resetToBaseline() {
        isAdjusting = true
        // Reset immediately — every frame of delay between presses is noticeable
        // when the user is tapping quickly. The 0.08 s lockout below is enough for
        // the slider settle to propagate a single KVO fire.
        setSystemVolume(baseline)
        // Keep ignoring KVO briefly while the volume slider's mechanical settle
        // might bounce — 0.08 s is tight enough for fast successive presses but
        // long enough to suppress a false double-fire.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.isAdjusting = false
        }
    }

    private func setSystemVolume(_ value: Float) {
        let clamped = max(0, min(1, value))
        guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else { return }
        // All callers run on the main thread (start prime / reset / stop).
        slider.value = clamped
    }

    // MARK: - Window lookup
    private static func activeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let key = scenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) {
            return key
        }
        return scenes.flatMap { $0.windows }.first
    }
}
