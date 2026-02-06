import Foundation

/// Finite state machine for audio playback.
/// Every valid transition is documented in ARCHITECTURE.md section 7.
enum AudioState: Equatable, Sendable {
    /// Initial state, player not active.
    case idle
    /// Establishing connection, buffering initial data.
    case connecting
    /// Actively playing audio.
    case playing
    /// Playback stalled because buffer is empty.
    case buffering
    /// User-initiated pause.
    case paused
    /// An error occurred; contains recovery information.
    case error(AudioError)

    /// Whether the engine is in an active streaming state.
    var isActive: Bool {
        switch self {
        case .playing, .buffering, .connecting:
            return true
        default:
            return false
        }
    }
}

/// Typed audio errors with user-facing descriptions and recovery hints.
enum AudioError: LocalizedError, Equatable, Sendable {
    case networkUnavailable
    case streamUnavailable
    case bufferingTimeout
    case audioSessionInterrupted
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Нет подключения к интернету"
        case .streamUnavailable:
            return "Радиопоток временно недоступен"
        case .bufferingTimeout:
            return "Превышено время ожидания"
        case .audioSessionInterrupted:
            return "Воспроизведение прервано"
        case .unknownError(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .networkUnavailable:
            return "Проверьте подключение к интернету"
        case .streamUnavailable, .bufferingTimeout:
            return "Попробуйте позже"
        case .audioSessionInterrupted:
            return "Нажмите Play для возобновления"
        case .unknownError:
            return "Попробуйте перезапустить приложение"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .streamUnavailable, .bufferingTimeout, .audioSessionInterrupted:
            return true
        case .unknownError:
            return false
        }
    }
}
