import AVFoundation
import Foundation

/// Errors that can occur during audio recording.
public enum AudioRecorderError: Error, LocalizedError {
    case alreadyRecording
    case notRecording
    case engineStartFailed(Error)
    case noAudioData

    public var errorDescription: String? {
        switch self {
        case .alreadyRecording: return "Already recording"
        case .notRecording: return "Not currently recording"
        case .engineStartFailed(let error): return "Audio engine failed to start: \(error.localizedDescription)"
        case .noAudioData: return "No audio data captured"
        }
    }
}

/// Records audio from the default input device at 16kHz mono Float32 format.
public final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private let sampleRate: Double = 16000.0
    private let lock = NSLock()

    public private(set) var isRecording: Bool = false

    public init() {}

    /// Start recording audio. Throws if already recording.
    public func startRecording() throws {
        guard !isRecording else { throw AudioRecorderError.alreadyRecording }

        lock.lock()
        samples.removeAll()
        lock.unlock()

        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Target format: 16kHz mono Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.engineStartFailed(
                NSError(domain: "AudioRecorder", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create target audio format"])
            )
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.engineStartFailed(
                NSError(domain: "AudioRecorder", code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
            )
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * self.sampleRate / inputFormat.sampleRate
            )
            guard frameCount > 0 else { return }

            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else {
                return
            }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, let channelData = convertedBuffer.floatChannelData else { return }

            let count = Int(convertedBuffer.frameLength)
            let data = Array(UnsafeBufferPointer(start: channelData[0], count: count))

            self.lock.lock()
            self.samples.append(contentsOf: data)
            self.lock.unlock()
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioRecorderError.engineStartFailed(error)
        }

        isRecording = true
    }

    /// Stop recording and return the captured audio samples.
    public func stopRecording() throws -> [Float] {
        guard isRecording else { throw AudioRecorderError.notRecording }

        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        isRecording = false

        lock.lock()
        let capturedSamples = samples
        samples.removeAll()
        lock.unlock()

        guard !capturedSamples.isEmpty else { throw AudioRecorderError.noAudioData }
        return capturedSamples
    }

    /// Cancel recording without returning data.
    public func cancelRecording() {
        if isRecording {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
            isRecording = false
        }
        lock.lock()
        samples.removeAll()
        lock.unlock()
    }

    /// Current duration of recorded audio in seconds.
    public var currentDuration: TimeInterval {
        lock.lock()
        let count = samples.count
        lock.unlock()
        return Double(count) / sampleRate
    }
}
