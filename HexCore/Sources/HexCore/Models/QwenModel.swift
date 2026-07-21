import Foundation

/// Qwen3-ASR variants supported through MLX Audio Swift.
public enum QwenModel: String, CaseIterable, Sendable {
	case small8Bit = "mlx-community/Qwen3-ASR-0.6B-8bit"
	case large8Bit = "mlx-community/Qwen3-ASR-1.7B-8bit"

	public var identifier: String { rawValue }
}
