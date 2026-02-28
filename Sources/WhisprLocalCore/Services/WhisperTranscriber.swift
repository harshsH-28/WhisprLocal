import Foundation
import whisper

/// Errors during transcription.
public enum TranscriberError: Error, LocalizedError, Equatable {
    case modelLoadFailed(String)
    case modelNotLoaded
    case transcriptionFailed
    case emptyAudio

    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let path): return "Failed to load whisper model at: \(path)"
        case .modelNotLoaded: return "No model is currently loaded"
        case .transcriptionFailed: return "Transcription failed"
        case .emptyAudio: return "No audio data to transcribe"
        }
    }
}

/// Thread-safe wrapper around whisper.cpp C API.
public actor WhisperTranscriber {
    private var context: OpaquePointer?

    public var isModelLoaded: Bool { context != nil }

    public init() {}

    /// Load a whisper model from disk.
    public func loadModel(path: String) throws {
        // Free existing model if loaded
        if let ctx = context {
            whisper_free(ctx)
            context = nil
        }

        var cparams = whisper_context_default_params()
        cparams.use_gpu = true

        guard let ctx = whisper_init_from_file_with_params(path, cparams) else {
            throw TranscriberError.modelLoadFailed(path)
        }
        context = ctx
    }

    /// Transcribe audio samples (16kHz mono Float32) to text.
    /// - Parameters:
    ///   - samples: Audio samples at 16kHz mono Float32.
    ///   - language: Language code (e.g. "en", "hi") or "auto" for auto-detection.
    public func transcribe(samples: [Float], language: String = "auto") throws -> String {
        guard let ctx = context else { throw TranscriberError.modelNotLoaded }
        guard !samples.isEmpty else { throw TranscriberError.emptyAudio }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_realtime = false
        params.print_progress = false
        params.print_timestamps = false
        params.print_special = false
        params.translate = false
        params.single_segment = false
        params.no_timestamps = true
        params.n_threads = Int32(max(1, ProcessInfo.processInfo.activeProcessorCount - 2))

        let result: Int32 = language.withCString { cString in
            if language != "auto" {
                params.language = cString
            }
            return samples.withUnsafeBufferPointer { buffer in
                whisper_full(ctx, params, buffer.baseAddress, Int32(buffer.count))
            }
        }

        guard result == 0 else { throw TranscriberError.transcriptionFailed }

        let segmentCount = whisper_full_n_segments(ctx)
        var transcription = ""

        for i in 0..<segmentCount {
            if let cString = whisper_full_get_segment_text(ctx, i) {
                transcription += String(cString: cString)
            }
        }

        return transcription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Unload the current model and free resources.
    public func unloadModel() {
        if let ctx = context {
            whisper_free(ctx)
            context = nil
        }
    }

    deinit {
        if let ctx = context {
            whisper_free(ctx)
        }
    }
}
