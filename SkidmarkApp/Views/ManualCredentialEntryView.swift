import SwiftUI

/// View for manually entering ESPN credentials with helpful instructions
struct ManualCredentialEntryView: View {
    let leagueId: String
    let authService: ESPNAuthenticationService
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var espnS2: String = ""
    @State private var swid: String = ""
    @State private var isSaving = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingInstructions = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("ESPN Cookies")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("ESPN_S2")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: { showingInstructions = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "questionmark.circle")
                                    Text("How to find")
                                }
                                .font(.caption)
                            }
                        }
                        
                        SecureField("Paste ESPN_S2 cookie value", text: $espnS2)
                            .textContentType(.password)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SWID")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("Paste SWID cookie value", text: $swid)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                }
                
                Section(footer: Text("Your credentials are stored securely in the device keychain and are only used to access your ESPN fantasy league data.")) {
                    Button(action: saveCredentials) {
                        if isSaving {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Saving...")
                            }
                        } else {
                            Text("Save Credentials")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .navigationTitle("Enter ESPN Credentials")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSaving)
                }
            }
            .alert("Save Error", isPresented: $showingError) {
                Button("OK") {
                    showingError = false
                }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingInstructions) {
                CookieInstructionsView()
            }
        }
    }
    
    private var isFormValid: Bool {
        !espnS2.trimmingCharacters(in: .whitespaces).isEmpty &&
        !swid.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    private func saveCredentials() {
        isSaving = true
        errorMessage = ""
        
        Task {
            let trimmedS2 = espnS2.trimmingCharacters(in: .whitespaces)
            let trimmedSWID = swid.trimmingCharacters(in: .whitespaces)
            
            let result = authService.saveCredentials(
                espnS2: trimmedS2,
                swid: trimmedSWID,
                leagueId: leagueId
            )
            
            await MainActor.run {
                switch result {
                case .success:
                    isSaving = false
                    onSave()
                case .failure(let error):
                    errorMessage = "Failed to save credentials: \(error.localizedDescription)"
                    showingError = true
                    isSaving = false
                }
            }
        }
    }
}

/// View showing detailed instructions for finding ESPN cookies
struct CookieInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Group {
                        Text("How to Find Your ESPN Cookies")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("You need to extract two cookie values from your browser after logging into ESPN Fantasy.")
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    InstructionSection(
                        title: "Chrome / Edge",
                        steps: [
                            "Open espn.com and log in to your account",
                            "Right-click anywhere on the page and select 'Inspect'",
                            "Click the 'Application' tab (or 'Storage' in some versions)",
                            "In the left sidebar, expand 'Cookies' and click on 'https://www.espn.com'",
                            "Find 'espn_s2' in the list and copy its Value (very long string)",
                            "Find 'SWID' in the list and copy its Value (format: {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX})"
                        ]
                    )
                    
                    Divider()
                    
                    InstructionSection(
                        title: "Safari",
                        steps: [
                            "Open espn.com and log in to your account",
                            "Go to Safari > Settings > Advanced and enable 'Show Develop menu'",
                            "Click Develop > Show Web Inspector",
                            "Click the 'Storage' tab",
                            "Select 'Cookies' > 'https://www.espn.com'",
                            "Find 'espn_s2' and copy its Value",
                            "Find 'SWID' and copy its Value"
                        ]
                    )
                    
                    Divider()
                    
                    InstructionSection(
                        title: "Firefox",
                        steps: [
                            "Open espn.com and log in to your account",
                            "Right-click and select 'Inspect Element'",
                            "Click the 'Storage' tab",
                            "Expand 'Cookies' and click 'https://www.espn.com'",
                            "Find 'espn_s2' and copy its Value",
                            "Find 'SWID' and copy its Value"
                        ]
                    )
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Important Notes")
                                .font(.headline)
                        }
                        
                        Text("• The espn_s2 cookie is very long (200+ characters)")
                        Text("• The SWID format includes curly braces: {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}")
                        Text("• These credentials give access to your ESPN account - keep them secure")
                        Text("• Credentials are stored in your device's secure keychain")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Cookie Instructions")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Reusable component for instruction steps
struct InstructionSection: View {
    let title: String
    let steps: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "laptopcomputer")
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Text(step)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.subheadline)
                }
            }
        }
    }
}
