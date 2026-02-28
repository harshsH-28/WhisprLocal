import XCTest
@testable import WhisprLocalCore

final class ModelManagerTests: XCTestCase {

    private func makeTestManager() throws -> (ModelManager, URL) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhisprLocalTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let manager = ModelManager(modelsDirectory: tempDir)
        return (manager, tempDir)
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    func testDefaultModelsDirectoryIsInApplicationSupport() {
        let manager = ModelManager()
        let path = manager.modelsDirectory.path
        XCTAssertTrue(path.contains("Application Support"))
        XCTAssertTrue(path.contains("WhisprLocal"))
        XCTAssertTrue(path.hasSuffix("models"))
    }

    func testModelPathReturnsCorrectPath() throws {
        let (manager, dir) = try makeTestManager()
        defer { cleanup(dir) }

        for model in WhisperModelType.allCases {
            let path = manager.modelPath(for: model)
            XCTAssertEqual(path.lastPathComponent, model.fileName)
            XCTAssertEqual(path.deletingLastPathComponent(), dir)
        }
    }

    func testIsModelAvailableReturnsFalseWhenMissing() throws {
        let (manager, dir) = try makeTestManager()
        defer { cleanup(dir) }
        XCTAssertFalse(manager.isModelAvailable(.base))
    }

    func testIsModelAvailableReturnsTrueWhenExists() throws {
        let (manager, dir) = try makeTestManager()
        defer { cleanup(dir) }

        let path = manager.modelPath(for: .base)
        FileManager.default.createFile(atPath: path.path, contents: Data("dummy".utf8))

        XCTAssertTrue(manager.isModelAvailable(.base))
    }

    func testEnsureModelsDirectoryCreatesIfMissing() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("WhisprLocalTests-\(UUID().uuidString)")
        let modelsDir = tempDir.appendingPathComponent("models")
        let manager = ModelManager(modelsDirectory: modelsDir)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: modelsDir.path))

        try manager.ensureModelsDirectory()

        XCTAssertTrue(FileManager.default.fileExists(atPath: modelsDir.path))
    }

    func testDeleteModelRemovesFile() throws {
        let (manager, dir) = try makeTestManager()
        defer { cleanup(dir) }

        let path = manager.modelPath(for: .tiny)
        FileManager.default.createFile(atPath: path.path, contents: Data("dummy".utf8))
        XCTAssertTrue(manager.isModelAvailable(.tiny))

        try manager.deleteModel(.tiny)
        XCTAssertFalse(manager.isModelAvailable(.tiny))
    }

    func testDeleteModelThrowsWhenNotFound() throws {
        let (manager, dir) = try makeTestManager()
        defer { cleanup(dir) }

        XCTAssertThrowsError(try manager.deleteModel(.base)) { error in
            XCTAssertTrue(error is ModelManagerError)
        }
    }

    func testInstalledModelsReturnsOnlyExisting() throws {
        let (manager, dir) = try makeTestManager()
        defer { cleanup(dir) }

        XCTAssertTrue(manager.installedModels().isEmpty)

        FileManager.default.createFile(
            atPath: manager.modelPath(for: .tiny).path,
            contents: Data("dummy".utf8)
        )
        FileManager.default.createFile(
            atPath: manager.modelPath(for: .base).path,
            contents: Data("dummy".utf8)
        )

        let installed = manager.installedModels()
        XCTAssertEqual(installed.count, 2)
        XCTAssertTrue(installed.contains(.tiny))
        XCTAssertTrue(installed.contains(.base))
    }

    func testModelInstructionsContainFilename() throws {
        let (manager, dir) = try makeTestManager()
        defer { cleanup(dir) }

        let instructions = manager.modelInstructions(for: .base)
        XCTAssertTrue(instructions.contains("ggml-base.bin"))
        XCTAssertTrue(instructions.contains(dir.path))
    }
}
