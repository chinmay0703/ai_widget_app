import Foundation

/// User-facing errors surfaced by the services layer.
enum AppError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidAPIKey
    case network(String)
    case httpStatus(Int, String)
    case decoding(String)
    case emptyResponse
    case accessibilityDenied
    case noSelectedText
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No OpenAI API key is configured. Add one in Settings."
        case .invalidAPIKey:
            return "The OpenAI API key was rejected. Check the key and try again."
        case .network(let message):
            return "Network error: \(message)"
        case .httpStatus(let code, let message):
            return "OpenAI returned an error (\(code)): \(message)"
        case .decoding(let message):
            return "Could not read the response: \(message)"
        case .emptyResponse:
            return "The model returned an empty response."
        case .accessibilityDenied:
            return "Accessibility permission is required to read the selected text."
        case .noSelectedText:
            return "No text was selected. Highlight some text and try again."
        case .cancelled:
            return "The request was cancelled."
        }
    }
}
