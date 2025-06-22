//
//  RadioError.swift
//  Oton.FM
//
//  Created by Assistant on 2025-01-21.
//

import Foundation

enum RadioError: LocalizedError, Equatable {
    case networkUnavailable
    case streamUnavailable
    case bufferingTimeout
    case invalidAudioFormat
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Нет подключения к интернету"
        case .streamUnavailable:
            return "Радиопоток временно недоступен"
        case .bufferingTimeout:
            return "Превышено время ожидания"
        case .invalidAudioFormat:
            return "Неподдерживаемый формат аудио"
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
        case .invalidAudioFormat:
            return "Обратитесь в поддержку"
        case .unknownError:
            return "Попробуйте перезапустить приложение"
        }
    }
}