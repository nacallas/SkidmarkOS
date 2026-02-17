import Foundation
import WebKit
import AuthenticationServices

/// Service for handling ESPN authentication via web view
/// Provides web-based login with automatic cookie extraction
class ESPNAuthenticationService: NSObject {
    private let keychainService: KeychainService
    private var webView: WKWebView?
    private var completionHandler: ((Result<ESPNCredentials, ESPNAuthError>) -> Void)?
    private var currentLeagueId: String?
    private var hasExtractedCredentials = false
    private var authSession: ASWebAuthenticationSession?
    
    init(keychainService: KeychainService = DefaultKeychainService()) {
        self.keychainService = keychainService
        super.init()
    }
    
    /// Authenticate with ESPN using web authentication session
    /// Presents ESPN login page and extracts cookies after successful login
    func authenticateWithWebView(
        leagueId: String,
        completion: @escaping (Result<ESPNCredentials, ESPNAuthError>) -> Void
    ) -> WKWebView {
        self.completionHandler = completion
        self.currentLeagueId = leagueId
        self.hasExtractedCredentials = false
        
        // Create web view configuration with default (persistent) data store
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        
        // Enable cookies
        config.preferences.javaScriptEnabled = true
        
        // Create web view
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        self.webView = webView
        
        // Clear any existing ESPN cookies first to force fresh login
        let cookieStore = config.websiteDataStore.httpCookieStore
        cookieStore.getAllCookies { cookies in
            let espnCookies = cookies.filter { $0.domain.contains("espn.com") }
            for cookie in espnCookies {
                cookieStore.delete(cookie)
            }
            
            // Now load the login page
            DispatchQueue.main.async {
                if let url = URL(string: "https://www.espn.com/login") {
                    let request = URLRequest(url: url)
                    webView.load(request)
                }
            }
        }
        
        return webView
    }
    
    /// Manually save ESPN credentials (fallback method)
    func saveCredentials(
        espnS2: String,
        swid: String,
        leagueId: String
    ) -> Result<Void, ESPNAuthError> {
        // Validate credential format
        guard validateCredentialFormat(espnS2: espnS2, swid: swid) else {
            return .failure(.invalidCredentialFormat)
        }
        
        let result = keychainService.saveESPNCredentials(
            espnS2: espnS2,
            swid: swid,
            forLeagueId: leagueId
        )
        
        if case .failure(let error) = result {
            return .failure(.credentialSaveFailed(error))
        }
        
        return .success(())
    }
    
    /// Retrieve stored credentials for a league
    func retrieveCredentials(forLeagueId leagueId: String) -> Result<ESPNCredentials, ESPNAuthError> {
        let result = keychainService.retrieveESPNCredentials(forLeagueId: leagueId)
        
        switch result {
        case .success(let credentials):
            return .success(credentials)
        case .failure(let error):
            return .failure(.credentialRetrievalFailed(error))
        }
    }
    
    /// Delete credentials for a league
    func deleteCredentials(forLeagueId leagueId: String) -> Result<Void, ESPNAuthError> {
        let result = keychainService.deleteESPNCredentials(forLeagueId: leagueId)
        
        if case .failure(let error) = result {
            return .failure(.credentialDeletionFailed(error))
        }
        
        return .success(())
    }
    
    /// Check if credentials exist for a league
    func hasCredentials(forLeagueId leagueId: String) -> Bool {
        return keychainService.hasESPNCredentials(forLeagueId: leagueId)
    }
    
    // MARK: - Private Helpers
    
    private func extractCookies(from webView: WKWebView, leagueId: String) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            
            var espnS2: String?
            var swid: String?
            
            for cookie in cookies {
                if cookie.name == "espn_s2" {
                    espnS2 = cookie.value
                } else if cookie.name == "SWID" {
                    swid = cookie.value
                }
            }
            
            guard let s2 = espnS2, let swidValue = swid else {
                self.completionHandler?(.failure(.cookieExtractionFailed))
                return
            }
            
            let credentials = ESPNCredentials(espnS2: s2, swid: swidValue)
            
            // Save credentials to keychain
            let saveResult = self.keychainService.saveESPNCredentials(
                espnS2: s2,
                swid: swidValue,
                forLeagueId: leagueId
            )
            
            if case .failure(let error) = saveResult {
                self.completionHandler?(.failure(.credentialSaveFailed(error)))
                return
            }
            
            self.completionHandler?(.success(credentials))
        }
    }
    
    private func validateCredentialFormat(espnS2: String, swid: String) -> Bool {
        // ESPN_S2 should be a non-empty string
        guard !espnS2.isEmpty else {
            return false
        }
        
        // SWID should start with { and end with }
        guard swid.hasPrefix("{") && swid.hasSuffix("}") else {
            return false
        }
        
        return true
    }
}

// MARK: - WKNavigationDelegate

extension ESPNAuthenticationService: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Check if we're on a page that indicates successful login
        guard let url = webView.url?.absoluteString else { return }
        
        print("ESPN WebView navigated to: \(url)")
        
        // If we just logged in and are on the homepage, navigate to fantasy to trigger espn_s2 cookie
        if url.contains("espn.com") && !url.contains("/login") && !url.contains("/authenticate") && !url.contains("/fantasy") {
            print("Login detected, navigating to fantasy to set cookies...")
            if let fantasyURL = URL(string: "https://www.espn.com/fantasy/") {
                webView.load(URLRequest(url: fantasyURL))
            }
        } else if url.contains("/fantasy") {
            print("On fantasy page, attempting cookie extraction...")
            // Give cookies extra time to be written
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self, let webView = self.webView else { return }
                self.extractCookiesForCompletion(from: webView)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completionHandler?(.failure(.webViewLoadFailed))
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        completionHandler?(.failure(.webViewLoadFailed))
    }
    
    private func extractCookiesForCompletion(from webView: WKWebView) {
        guard !hasExtractedCredentials else {
            print("Already extracted credentials, skipping")
            return
        }
        
        print("Extracting cookies from webView...")
        
        // Try to get cookies via JavaScript as well
        let script = """
        (function() {
            var cookies = document.cookie.split(';');
            var result = {};
            for (var i = 0; i < cookies.length; i++) {
                var cookie = cookies[i].trim();
                var parts = cookie.split('=');
                if (parts.length === 2) {
                    result[parts[0]] = parts[1];
                }
            }
            return JSON.stringify(result);
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }
            
            if let jsonString = result as? String,
               let data = jsonString.data(using: .utf8),
               let cookies = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                print("JavaScript cookies: \(cookies.keys.joined(separator: ", "))")
                
                if let espnS2 = cookies["espn_s2"], let swid = cookies["SWID"] {
                    print("Found cookies via JavaScript!")
                    self.saveAndComplete(espnS2: espnS2, swid: swid)
                    return
                }
            }
            
            // Fallback to HTTPCookieStore
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self = self else { return }
                
                print("Found \(cookies.count) total cookies via HTTPCookieStore")
                
                var espnS2: String?
                var swid: String?
                
                for cookie in cookies {
                    print("Cookie: \(cookie.name) = \(cookie.value.prefix(20))... (domain: \(cookie.domain))")
                    if cookie.name == "espn_s2" {
                        espnS2 = cookie.value
                        print("Found espn_s2 cookie (length: \(cookie.value.count))")
                    } else if cookie.name == "SWID" {
                        swid = cookie.value
                        print("Found SWID cookie: \(cookie.value)")
                    }
                }
                
                guard let s2 = espnS2, let swidValue = swid else {
                    print("Cookies not found yet - espn_s2: \(espnS2 != nil), SWID: \(swid != nil)")
                    // Cookies not found yet - user may not be logged in
                    return
                }
                
                self.saveAndComplete(espnS2: s2, swid: swidValue)
            }
        }
    }
    
    private func saveAndComplete(espnS2: String, swid: String) {
        print("Successfully extracted both cookies, saving...")
        self.hasExtractedCredentials = true
        
        let credentials = ESPNCredentials(espnS2: espnS2, swid: swid)
        
        // Save credentials if we have a leagueId
        if let leagueId = self.currentLeagueId {
            let saveResult = self.keychainService.saveESPNCredentials(
                espnS2: espnS2,
                swid: swid,
                forLeagueId: leagueId
            )
            
            if case .failure(let error) = saveResult {
                print("Failed to save credentials: \(error)")
                self.completionHandler?(.failure(.credentialSaveFailed(error)))
                return
            }
            
            print("Credentials saved successfully")
        }
        
        self.completionHandler?(.success(credentials))
    }
}

// MARK: - Error Types

enum ESPNAuthError: LocalizedError {
    case webViewLoadFailed
    case cookieExtractionFailed
    case invalidCredentialFormat
    case credentialSaveFailed(KeychainError)
    case credentialRetrievalFailed(KeychainError)
    case credentialDeletionFailed(KeychainError)
    
    var errorDescription: String? {
        switch self {
        case .webViewLoadFailed:
            return "Failed to load ESPN login page"
        case .cookieExtractionFailed:
            return "Failed to extract ESPN cookies. Please ensure you logged in successfully."
        case .invalidCredentialFormat:
            return "Invalid credential format. SWID should be in {xxx} format."
        case .credentialSaveFailed(let error):
            return "Failed to save credentials: \(error.localizedDescription)"
        case .credentialRetrievalFailed(let error):
            return "Failed to retrieve credentials: \(error.localizedDescription)"
        case .credentialDeletionFailed(let error):
            return "Failed to delete credentials: \(error.localizedDescription)"
        }
    }
}
