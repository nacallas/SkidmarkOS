import Foundation

/// Generic wrapper that adds retry logic to async operations
struct RetryableService {
    let policy: RetryPolicy
    let networkMonitor: NetworkMonitor?
    
    init(policy: RetryPolicy = .default, networkMonitor: NetworkMonitor? = nil) {
        self.policy = policy
        self.networkMonitor = networkMonitor
    }
    
    /// Executes an async operation with automatic retry logic
    /// - Parameter operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: The last error encountered if all retries fail
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...policy.maxAttempts {
            // Check network connectivity before attempting (if monitor available)
            if let monitor = networkMonitor, !monitor.isConnected {
                throw BackendError.noConnection
            }
            
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry if error is not retryable
                guard policy.isRetryable(error) else {
                    throw error
                }
                
                // Don't retry if this was the last attempt
                guard attempt < policy.maxAttempts else {
                    throw error
                }
                
                // Calculate delay and wait before next attempt
                let delay = policy.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // This should never be reached, but throw last error as fallback
        throw lastError ?? BackendError.networkError(NSError(domain: "RetryableService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
    }
}
