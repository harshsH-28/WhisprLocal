import Foundation

/// Errors related to model management.
public enum ModelManagerError: Error, LocalizedError {
    case directoryCreationFailed(Error)
    case modelNotFound(WhisperModelType)
    case deletionFailed(Error)
    case downloadFailed(Error)
    case downloadCancelled
    case invalidDownload

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let error):
            return "Failed to create models directory: \(error.localizedDescription)"
        case .modelNotFound(let model):
            return "Model '\(model.displayName)' not found at expected path"
        case .deletionFailed(let error):
            return "Failed to delete model: \(error.localizedDescription)"
        case .downloadFailed(let error):
            return "Failed to download model: \(error.localizedDescription)"
        case .downloadCancelled:
            return "Model download was cancelled"
        case .invalidDownload:
            return "Downloaded file is invalid or corrupted"
        }
    }
}

/// Manages local model files and downloads from Hugging Face.
public final class ModelManager: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let fileManager: FileManager
    private var downloadTask: URLSessionDownloadTask?
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    private var progressCallback: ((Double) -> Void)?

    /// The base directory for storing models.
    public let modelsDirectory: URL

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.modelsDirectory = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisprLocal", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
        super.init()
    }

    /// Initializer that accepts a custom models directory (for testing).
    public init(modelsDirectory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.modelsDirectory = modelsDirectory
        super.init()
    }

    /// Ensure the models directory exists. Creates it if missing.
    public func ensureModelsDirectory() throws {
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            do {
                try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            } catch {
                throw ModelManagerError.directoryCreationFailed(error)
            }
        }
    }

    /// Returns the expected file path for a given model type.
    public func modelPath(for modelType: WhisperModelType) -> URL {
        modelsDirectory.appendingPathComponent(modelType.fileName)
    }

    /// Check if a model file exists on disk.
    public func isModelAvailable(_ modelType: WhisperModelType) -> Bool {
        fileManager.fileExists(atPath: modelPath(for: modelType).path)
    }

    /// Delete a model file from disk.
    public func deleteModel(_ modelType: WhisperModelType) throws {
        let path = modelPath(for: modelType)
        guard fileManager.fileExists(atPath: path.path) else {
            throw ModelManagerError.modelNotFound(modelType)
        }
        do {
            try fileManager.removeItem(at: path)
        } catch {
            throw ModelManagerError.deletionFailed(error)
        }
    }

    /// Get the file size of an installed model, if available.
    public func modelFileSize(_ modelType: WhisperModelType) -> Int64? {
        let path = modelPath(for: modelType)
        guard let attrs = try? fileManager.attributesOfItem(atPath: path.path),
              let size = attrs[.size] as? Int64 else {
            return nil
        }
        return size
    }

    /// List all installed models.
    public func installedModels() -> [WhisperModelType] {
        WhisperModelType.allCases.filter { isModelAvailable($0) }
    }

    /// Instructions text for users on how to manually place a model.
    public func modelInstructions(for modelType: WhisperModelType) -> String {
        """
        To use WhisprLocal, download a whisper model and place it at:

        \(modelPath(for: modelType).path)

        You can download models from:
        https://huggingface.co/ggerganov/whisper.cpp/tree/main

        Look for: \(modelType.fileName)
        Expected size: \(modelType.sizeDescription)
        """
    }

    /// Download URL for a model from Hugging Face.
    public func downloadURL(for modelType: WhisperModelType) -> URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(modelType.fileName)")!
    }

    /// Download a model from Hugging Face.
    /// - Parameters:
    ///   - modelType: The model to download.
    ///   - progress: Callback reporting download progress (0.0–1.0), called on arbitrary thread.
    public func downloadModel(_ modelType: WhisperModelType, progress: @escaping @Sendable (Double) -> Void) async throws {
        try ensureModelsDirectory()

        let url = downloadURL(for: modelType)
        self.progressCallback = progress

        let tempFileURL: URL = try await withCheckedThrowingContinuation { continuation in
            self.downloadContinuation = continuation
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let task = session.downloadTask(with: url)
            self.downloadTask = task
            task.resume()
        }

        // Validate file size (within ~10% tolerance)
        let attrs = try fileManager.attributesOfItem(atPath: tempFileURL.path)
        if let fileSize = attrs[.size] as? Int64 {
            let expected = modelType.approximateSize
            let tolerance = Double(expected) * 0.1
            if Double(fileSize) < Double(expected) - tolerance {
                try? fileManager.removeItem(at: tempFileURL)
                throw ModelManagerError.invalidDownload
            }
        }

        // Move to final destination
        let destination = modelPath(for: modelType)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: tempFileURL, to: destination)
    }

    /// Cancel an in-flight download.
    public func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        progressCallback = nil
    }

    // MARK: - URLSessionDownloadDelegate

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Move to a temp location we control (the system deletes `location` after this method returns)
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bin")
        do {
            try fileManager.moveItem(at: location, to: tempURL)
            downloadContinuation?.resume(returning: tempURL)
        } catch {
            downloadContinuation?.resume(throwing: ModelManagerError.downloadFailed(error))
        }
        downloadContinuation = nil
        self.downloadTask = nil
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressCallback?(fraction)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let error = error else { return }
        if (error as NSError).code == NSURLErrorCancelled {
            downloadContinuation?.resume(throwing: ModelManagerError.downloadCancelled)
        } else {
            downloadContinuation?.resume(throwing: ModelManagerError.downloadFailed(error))
        }
        downloadContinuation = nil
        downloadTask = nil
        progressCallback = nil
    }
}
