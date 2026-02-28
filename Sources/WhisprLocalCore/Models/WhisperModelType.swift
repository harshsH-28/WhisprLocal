import Foundation

/// Available whisper.cpp model types with their metadata.
public enum WhisperModelType: String, CaseIterable, Identifiable, Sendable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case medium = "medium"

    public var id: String { rawValue }

    /// Human-readable display name.
    public var displayName: String {
        rawValue.capitalized
    }

    /// Expected filename for the GGML model binary.
    public var fileName: String {
        "ggml-\(rawValue).bin"
    }

    /// Approximate download size in bytes.
    public var approximateSize: Int64 {
        switch self {
        case .tiny:   return 75_000_000    // ~75 MB
        case .base:   return 142_000_000   // ~142 MB
        case .small:  return 466_000_000   // ~466 MB
        case .medium: return 1_530_000_000 // ~1.5 GB
        }
    }

    /// Human-readable size string.
    public var sizeDescription: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: approximateSize)
    }

    /// Description of relative quality/speed tradeoff.
    public var qualityDescription: String {
        switch self {
        case .tiny:   return "Fastest, lower accuracy"
        case .base:   return "Good balance of speed and accuracy"
        case .small:  return "Higher accuracy, moderate speed"
        case .medium: return "Best accuracy, slower"
        }
    }

    /// The default recommended model.
    public static var recommended: WhisperModelType { .base }
}
