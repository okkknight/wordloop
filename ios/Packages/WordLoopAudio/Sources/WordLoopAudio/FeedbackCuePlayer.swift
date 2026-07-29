import AVFoundation

/// Small synthesized cues matching the Web Audio feedback used by WordLoop.
///
/// Keeping the envelopes and note timings here (rather than using system
/// sounds) makes the native interaction read as the same product as Web.
@MainActor
public final class FeedbackCuePlayer {
    public enum Cue: Sendable {
        case passed
        case failed
        case mastery
        case recordingReady
    }

    private struct Note {
        let frequency: Double
        let offset: Double
        let duration: Double
        let peak: Float
        let waveform: Waveform
    }

    private enum Waveform {
        case sine
        case triangle
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    public init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }

    public func play(_ cue: Cue) {
        let notes: [Note] = switch cue {
        case .passed:
            [
                .init(frequency: 660, offset: 0, duration: 0.12, peak: 0.07, waveform: .sine),
                .init(frequency: 880, offset: 0.09, duration: 0.12, peak: 0.07, waveform: .sine),
            ]
        case .failed:
            [
                .init(frequency: 420, offset: 0, duration: 0.16, peak: 0.12, waveform: .triangle),
                .init(frequency: 260, offset: 0.12, duration: 0.16, peak: 0.12, waveform: .triangle),
            ]
        case .mastery:
            [.init(frequency: 740, offset: 0, duration: 0.115, peak: 0.05, waveform: .sine)]
        case .recordingReady:
            [
                .init(frequency: 520, offset: 0, duration: 0.1, peak: 0.045, waveform: .sine),
                .init(frequency: 700, offset: 0.07, duration: 0.1, peak: 0.045, waveform: .sine),
            ]
        }

        guard let buffer = makeBuffer(notes: notes) else { return }
        do {
            if !engine.isRunning { try engine.start() }
            player.stop()
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            player.play()
        } catch {
            // Feedback must never interfere with speech playback or learning.
        }
    }

    private func makeBuffer(notes: [Note]) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let lastEnd = notes.map { $0.offset + $0.duration }.max() ?? 0
        let frameCount = AVAudioFrameCount((lastEnd + 0.02) * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for note in notes {
            let start = Int(note.offset * sampleRate)
            let end = min(Int((note.offset + note.duration) * sampleRate), Int(frameCount))
            for frame in start..<end {
                let elapsed = Double(frame - start) / sampleRate
                let phase = 2 * Double.pi * note.frequency * elapsed
                let signal: Double = switch note.waveform {
                case .sine: sin(phase)
                case .triangle: (2 / Double.pi) * asin(sin(phase))
                }
                let attack = min(elapsed / 0.015, 1)
                let release = min((note.duration - elapsed) / 0.015, 1)
                samples[frame] += Float(signal * attack * max(release, 0)) * note.peak
            }
        }
        return buffer
    }
}
