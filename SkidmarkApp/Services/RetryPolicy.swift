import Foundation

/// Defines retry behavior for failed operations
struct RetryPolicy {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let multiplier: Double
    
    static let `default` = RetryPolicy(
        maxAttempts: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        multiplier: 2.0
    )
    
    static let aggressive = RetryPolicy(
        maxAttempts: 5,
        baseDelay: 0.5,
        maxDelay: 30.0,
        multiplier: 2.0
    )
    
    static let none = RetryPolicy(
        maxAttempts: 1,
        baseDelay: 0,
        maxDelay: 0,
        multiplier: 1.0
    )
    
    /// Calculates delay for a given attempt using exponential backoff
    func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let exponentialDelay = baseDelay * pow(multiplier, Double(attempt - 1))
        return min(exponentialDelay, maxDelay)
    }
    
    /// Determines if an error is retryable
    func isRetryable(_ error: Error) -> Bool {
        // Network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost,
                 .notConnectedToInternet, .dnsLookupFailed, .cannotFindHost:
                return true
            default:
                return false
            }
        }
        
        // Backend errors
        if let backendError = error as? BackendError {
            switch backendError {
            case .noConnection, .timeout, .networkError:
                return true
            case .serverError(let statusCode):
                // Retry on 5xx server errors and 429 rate limiting
                return statusCode >= 500 || statusCode == 429
            default:
                return false
            }
        }
        
        // League data errors
        if let leagueError = error as? LeagueDataError {
            switch leagueError {
            case .noConnection, .timeout, .networkError:
                return true
            case .serverError(let statusCode):
                return statusCode >= 500 || statusCode == 429
            default:
                return false
            }
        }
        
        return false
    }
}
