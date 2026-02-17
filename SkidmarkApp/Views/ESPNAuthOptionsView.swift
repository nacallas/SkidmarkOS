import SwiftUI

/// View that presents ESPN authentication with manual credential entry
struct ESPNAuthOptionsView: View {
    let leagueId: String
    let authService: ESPNAuthenticationService
    let onSuccess: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ManualCredentialEntryView(
            leagueId: leagueId,
            authService: authService,
            onSave: {
                onSuccess()
                dismiss()
            }
        )
    }
}
