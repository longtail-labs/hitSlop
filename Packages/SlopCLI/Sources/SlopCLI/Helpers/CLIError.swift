import Foundation

enum CLIError: LocalizedError {
    case appNotRunning
    case serverError(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .appNotRunning:
            "hitSlop app is not running. Launch hitSlop.app first."
        case .serverError(let msg):
            "Server error: \(msg)"
        case .invalidResponse(let msg):
            "Invalid response: \(msg)"
        }
    }
}
