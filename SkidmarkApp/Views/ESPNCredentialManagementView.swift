import SwiftUI
import WebKit

#if canImport(UIKit)
import UIKit
#endif

/// View for managing ESPN credentials for a specific league
/// Allows viewing, updating, and deleting stored credentials
struct ESPNCredentialManagementView: View {
    let leagueId: String
    let leagueName: String
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ESPNCredentialManagementViewModel
    
    init(leagueId: String, leagueName: String, authService: ESPNAuthenticationService = ESPNAuthenticationService()) {
        self.leagueId = leagueId
        self.leagueName = leagueName
        _viewModel = StateObject(wrappedValue: ESPNCredentialManagementViewModel(
            leagueId: leagueId,
            authService: authService
        ))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Current Status")) {
                HStack {
                    Text("Credentials")
                    Spacer()
                    if viewModel.hasCredentials {
                        Label("Stored", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Not Found", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
            }
            
            if viewModel.hasCredentials {
                Section(header: Text("Credential Preview")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ESPN_S2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.maskedESPNS2)
                            .font(.system(.body, design: .monospaced))
                        
                        Text("SWID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                        Text(viewModel.maskedSWID)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            
            Section(header: Text("Actions")) {
                Button(action: { viewModel.showingWebAuth = true }) {
                    Label("Sign In with ESPN", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
                
                Button(action: { viewModel.showingManualEntry = true }) {
                    Label("Enter Credentials Manually", systemImage: "pencil")
                }
                .disabled(viewModel.isLoading)
                
                if viewModel.hasCredentials {
                    Button(role: .destructive, action: { viewModel.showingDeleteConfirmation = true }) {
                        Label("Delete Credentials", systemImage: "trash")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            
            Section(footer: Text("Credentials are stored securely in your device's keychain and are only used to access your ESPN fantasy league data.")) {
                EmptyView()
            }
        }
        .navigationTitle("ESPN Credentials")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $viewModel.showingWebAuth) {
            ESPNWebAuthView(
                leagueId: leagueId,
                authService: viewModel.authService,
                onSuccess: {
                    viewModel.loadCredentialStatus()
                }
            )
        }
        .sheet(isPresented: $viewModel.showingManualEntry) {
            ManualCredentialEntryView(
                leagueId: leagueId,
                authService: viewModel.authService,
                onSave: {
                    viewModel.loadCredentialStatus()
                }
            )
        }
        .alert("Delete Credentials", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteCredentials()
            }
        } message: {
            Text("Are you sure you want to delete the stored ESPN credentials for \(leagueName)? You will need to re-authenticate to access this league.")
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("Success", isPresented: $viewModel.showingSuccess) {
            Button("OK") { }
        } message: {
            Text(viewModel.successMessage)
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
        .onAppear {
            viewModel.loadCredentialStatus()
        }
    }
}

/// View model for ESPN credential management
@MainActor
class ESPNCredentialManagementViewModel: ObservableObject {
    let leagueId: String
    let authService: ESPNAuthenticationService
    
    @Published var hasCredentials = false
    @Published var maskedESPNS2 = ""
    @Published var maskedSWID = ""
    @Published var isLoading = false
    @Published var showingWebAuth = false
    @Published var showingManualEntry = false
    @Published var showingDeleteConfirmation = false
    @Published var showingError = false
    @Published var showingSuccess = false
    @Published var errorMessage = ""
    @Published var successMessage = ""
    
    init(leagueId: String, authService: ESPNAuthenticationService) {
        self.leagueId = leagueId
        self.authService = authService
    }
    
    func loadCredentialStatus() {
        hasCredentials = authService.hasCredentials(forLeagueId: leagueId)
        
        if hasCredentials {
            let result = authService.retrieveCredentials(forLeagueId: leagueId)
            if case .success(let credentials) = result {
                maskedESPNS2 = maskCredential(credentials.espnS2, showFirst: 10, showLast: 10)
                maskedSWID = credentials.swid
            }
        }
    }
    
    func deleteCredentials() {
        isLoading = true
        
        let result = authService.deleteCredentials(forLeagueId: leagueId)
        
        isLoading = false
        
        switch result {
        case .success:
            successMessage = "Credentials deleted successfully"
            showingSuccess = true
            loadCredentialStatus()
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func maskCredential(_ credential: String, showFirst: Int, showLast: Int) -> String {
        guard credential.count > showFirst + showLast else {
            return String(repeating: "*", count: credential.count)
        }
        
        let first = credential.prefix(showFirst)
        let last = credential.suffix(showLast)
        let masked = String(repeating: "*", count: credential.count - showFirst - showLast)
        
        return "\(first)\(masked)\(last)"
    }
}

/// View for ESPN web-based authentication
struct ESPNWebAuthView: View {
    let leagueId: String
    let authService: ESPNAuthenticationService
    let onSuccess: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var webView: WKWebView?
    @State private var isAuthenticating = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack {
            if let webView = webView {
                WebViewRepresentable(webView: webView)
            } else {
                ProgressView("Loading ESPN login...")
            }
        }
        .navigationTitle("Sign In to ESPN")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isAuthenticating)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    extractCredentials()
                }
                .disabled(isAuthenticating)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                isAuthenticating = false
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            startAuthentication()
        }
    }
    
    private func startAuthentication() {
        let webView = authService.authenticateWithWebView(leagueId: leagueId) { result in
            DispatchQueue.main.async {
                isAuthenticating = false
                
                switch result {
                case .success:
                    onSuccess()
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
        
        self.webView = webView
    }
    
    private func extractCredentials() {
        guard let webView = webView else { return }
        isAuthenticating = true
        
        // Manually trigger cookie extraction
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak authService] cookies in
            DispatchQueue.main.async {
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
                    errorMessage = "ESPN cookies not found. Please make sure you're logged in to ESPN Fantasy."
                    showingError = true
                    isAuthenticating = false
                    return
                }
                
                // Save credentials
                let result = authService?.saveCredentials(espnS2: s2, swid: swidValue, leagueId: leagueId)
                
                switch result {
                case .success:
                    onSuccess()
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showingError = true
                    isAuthenticating = false
                case .none:
                    errorMessage = "Authentication service unavailable"
                    showingError = true
                    isAuthenticating = false
                }
            }
        }
    }
}

/// UIViewRepresentable wrapper for WKWebView
#if canImport(UIKit)
struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    
    func makeUIView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed
    }
}
#else
// Fallback for macOS - not supported
struct WebViewRepresentable: View {
    let webView: WKWebView
    
    var body: some View {
        Text("Web authentication not supported on this platform")
    }
}
#endif
