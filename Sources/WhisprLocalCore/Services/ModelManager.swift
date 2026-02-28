import Foundation

/// Errors related to model management.
public enum ModelManagerError: Error, LocalizedError {
    case directoryCreationFailed(Error)
    case modelNotFound(WhisperModelType)
    case deletionFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let error):
            return "Failed to create models directory: \(error.localizedDescription)"
        case .modelNotFound(let model):
            return "Model '\(model.displayName)' not found at expected path"
        case .deletionFailed(let error):
            return "Failed to delete model: \(error.localizedDescription)"
        }
    }
}

/// Manages local model files. No network — user places models manually.
public final class ModelManager {
    private let fileManager: FileManager

    /// The base directory for storing models.
    public let modelsDirectory: URL

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.modelsDirectory = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WhisprLocal", isDirectory: true)
            .appendingPathComponent("models", isDirectory: true)
    }

    /// Initializer that accepts a custom models directory (for testing).
    public init(modelsDirectory: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.modelsDirectory = modelsDirectory
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
}
