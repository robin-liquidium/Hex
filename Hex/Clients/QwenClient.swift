import Foundation
import HexCore

#if canImport(MLXAudioSTT)
import HuggingFace
import MLXAudioCore
import MLXAudioSTT

actor QwenClient {
  private var model: Qwen3ASRModel?
  private var loadedVariant: QwenModel?
  private let logger = HexLog.transcription

  func isModelAvailable(_ modelName: String) -> Bool {
    guard let variant = QwenModel(rawValue: modelName) else { return false }
    if loadedVariant == variant, model != nil { return true }

    let fileManager = FileManager.default
    guard let modelDirectory = try? modelDirectory(for: variant) else { return false }
    guard fileManager.fileExists(atPath: modelDirectory.appendingPathComponent("config.json").path) else {
      return false
    }

    guard let files = try? fileManager.contentsOfDirectory(
      at: modelDirectory,
      includingPropertiesForKeys: [.fileSizeKey]
    ) else { return false }

    return files.contains { file in
      guard file.pathExtension == "safetensors" else { return false }
      return ((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 0
    }
  }

  func ensureLoaded(modelName: String, progress: @escaping (Progress) -> Void) async throws {
    guard let variant = QwenModel(rawValue: modelName) else {
      throw QwenClientError.unsupportedModel(modelName)
    }
    if loadedVariant == variant, model != nil { return }

    model = nil
    loadedVariant = nil

    let startedAt = Date()
    logger.notice("Starting Qwen3-ASR load variant=\(variant.identifier, privacy: .public)")

    let overallProgress = Progress(totalUnitCount: 100)
    overallProgress.completedUnitCount = 1
    progress(overallProgress)

    let cache = HubCache(cacheDirectory: try URL.hexMLXModelsDirectory)
    guard let repoID = Repo.ID(rawValue: variant.identifier) else {
      throw QwenClientError.unsupportedModel(modelName)
    }

    let modelDirectory = try await ModelUtils.resolveOrDownloadModel(
      client: HubClient(cache: cache),
      cache: cache,
      repoID: repoID,
      requiredExtension: "safetensors",
      progressHandler: { downloadProgress in
        overallProgress.completedUnitCount = 1 + Int64(downloadProgress.fractionCompleted * 89)
        progress(overallProgress)
      }
    )

    overallProgress.completedUnitCount = 90
    progress(overallProgress)

    logger.info("Loading Qwen3-ASR model from \(modelDirectory.path, privacy: .private)")
    let loadedModel = try await Qwen3ASRModel.fromModelDirectory(modelDirectory)
    model = loadedModel
    loadedVariant = variant

    overallProgress.completedUnitCount = 100
    progress(overallProgress)
    logger.notice(
      "Qwen3-ASR load completed in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)), privacy: .public)s"
    )
  }

  func transcribe(_ url: URL) throws -> String {
    guard let model else { throw QwenClientError.modelNotLoaded }

    let startedAt = Date()
    logger.notice("Transcribing with Qwen3-ASR file=\(url.lastPathComponent, privacy: .private)")
    let (_, audio) = try loadAudioArray(from: url, sampleRate: 16_000)
    let output = model.generate(audio: audio)
    logger.info(
      "Qwen3-ASR transcription finished in \(String(format: "%.2f", Date().timeIntervalSince(startedAt)), privacy: .public)s"
    )
    return output.text
  }

  func deleteCaches(modelName: String) throws {
    guard let variant = QwenModel(rawValue: modelName) else {
      throw QwenClientError.unsupportedModel(modelName)
    }

    let fileManager = FileManager.default
    let cache = HubCache(cacheDirectory: try URL.hexMLXModelsDirectory)
    let modelDirectory = try modelDirectory(for: variant)

    if fileManager.fileExists(atPath: modelDirectory.path) {
      try fileManager.removeItem(at: modelDirectory)
      logger.notice("Deleted Qwen3-ASR model at \(modelDirectory.path, privacy: .private)")
    }

    if let repoID = Repo.ID(rawValue: variant.identifier) {
      let hubDirectory = cache.repoDirectory(repo: repoID, kind: .model)
      if fileManager.fileExists(atPath: hubDirectory.path) {
        try fileManager.removeItem(at: hubDirectory)
        logger.notice("Deleted Qwen3-ASR hub cache at \(hubDirectory.path, privacy: .private)")
      }
    }

    if loadedVariant == variant {
      model = nil
      loadedVariant = nil
    }
  }

  func unload() {
    model = nil
    loadedVariant = nil
  }

  private func modelDirectory(for variant: QwenModel) throws -> URL {
    try URL.hexMLXModelsDirectory
      .appendingPathComponent("mlx-audio", isDirectory: true)
      .appendingPathComponent(
        variant.identifier.replacingOccurrences(of: "/", with: "_"),
        isDirectory: true
      )
  }
}

private enum QwenClientError: LocalizedError {
  case modelNotLoaded
  case unsupportedModel(String)

  var errorDescription: String? {
    switch self {
    case .modelNotLoaded:
      "Qwen3-ASR model is not loaded."
    case .unsupportedModel(let name):
      "Unsupported Qwen3-ASR model: \(name)"
    }
  }
}

#else

actor QwenClient {
  func isModelAvailable(_ modelName: String) -> Bool { false }

  func ensureLoaded(modelName: String, progress: @escaping (Progress) -> Void) async throws {
    throw NSError(
      domain: "QwenClient",
      code: -1,
      userInfo: [NSLocalizedDescriptionKey: "MLX Audio support is not linked."]
    )
  }

  func transcribe(_ url: URL) throws -> String {
    throw NSError(
      domain: "QwenClient",
      code: -2,
      userInfo: [NSLocalizedDescriptionKey: "Qwen3-ASR is unavailable."]
    )
  }

  func deleteCaches(modelName: String) throws {}
  func unload() {}
}

#endif
