import Foundation
import Security

/// Protocol defining secure credential storage operations for ESPN authentication
protocol KeychainService {
    /// Save ESPN credentials for a specific league
    func saveESPNCredentials(espnS2: String, swid: String, forLeagueId leagueId: String) -> Result<Void, KeychainError>
    
    /// Retrieve ESPN credentials for a specific league
    func retrieveESPNCredentials(forLeagueId leagueId: String) -> Result<ESPNCredentials, KeychainError>
    
    /// Delete ESPN credentials for a specific league
    func deleteESPNCredentials(forLeagueId leagueId: String) -> Result<Void, KeychainError>
    
    /// Check if credentials exist for a specific league
    func hasESPNCredentials(forLeagueId leagueId: String) -> Bool
}

/// ESPN credentials structure
struct ESPNCredentials: Equatable {
    let espnS2: String
    let swid: String
}

/// Errors that can occur during keychain operations
enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case retrievalFailed(OSStatus)
    case deletionFailed(OSStatus)
    case credentialsNotFound
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save credentials to keychain: \(status)"
        case .retrievalFailed(let status):
            return "Failed to retrieve credentials from keychain: \(status)"
        case .deletionFailed(let status):
            return "Failed to delete credentials from keychain: \(status)"
        case .credentialsNotFound:
            return "Credentials not found in keychain"
        case .encodingFailed:
            return "Failed to encode credentials"
        case .decodingFailed:
            return "Failed to decode credentials"
        }
    }
}

/// Default implementation of KeychainService using iOS Keychain APIs
final class DefaultKeychainService: KeychainService {
    private let service = "com.skidmark.espn"
    
    // MARK: - Public Methods
    
    func saveESPNCredentials(espnS2: String, swid: String, forLeagueId leagueId: String) -> Result<Void, KeychainError> {
        let credentials = ESPNCredentials(espnS2: espnS2, swid: swid)
        
        // Encode credentials to JSON
        guard let data = encodeCredentials(credentials) else {
            return .failure(.encodingFailed)
        }
        
        // Check if credentials already exist
        if hasESPNCredentials(forLeagueId: leagueId) {
            // Update existing credentials
            return updateCredentials(data, forLeagueId: leagueId)
        } else {
            // Add new credentials
            return addCredentials(data, forLeagueId: leagueId)
        }
    }
    
    func retrieveESPNCredentials(forLeagueId leagueId: String) -> Result<ESPNCredentials, KeychainError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: leagueId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return .failure(.credentialsNotFound)
            }
            return .failure(.retrievalFailed(status))
        }
        
        guard let data = result as? Data else {
            return .failure(.decodingFailed)
        }
        
        guard let credentials = decodeCredentials(data) else {
            return .failure(.decodingFailed)
        }
        
        return .success(credentials)
    }
    
    func deleteESPNCredentials(forLeagueId leagueId: String) -> Result<Void, KeychainError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: leagueId
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            return .failure(.deletionFailed(status))
        }
        
        return .success(())
    }
    
    func hasESPNCredentials(forLeagueId leagueId: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: leagueId,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Private Helpers
    
    private func addCredentials(_ data: Data, forLeagueId leagueId: String) -> Result<Void, KeychainError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: leagueId,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecValueData as String: data
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            return .failure(.saveFailed(status))
        }
        
        return .success(())
    }
    
    private func updateCredentials(_ data: Data, forLeagueId leagueId: String) -> Result<Void, KeychainError> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: leagueId
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            return .failure(.saveFailed(status))
        }
        
        return .success(())
    }
    
    private func encodeCredentials(_ credentials: ESPNCredentials) -> Data? {
        let dictionary: [String: String] = [
            "espnS2": credentials.espnS2,
            "swid": credentials.swid
        ]
        
        return try? JSONEncoder().encode(dictionary)
    }
    
    private func decodeCredentials(_ data: Data) -> ESPNCredentials? {
        guard let dictionary = try? JSONDecoder().decode([String: String].self, from: data),
              let espnS2 = dictionary["espnS2"],
              let swid = dictionary["swid"] else {
            return nil
        }
        
        return ESPNCredentials(espnS2: espnS2, swid: swid)
    }
}
