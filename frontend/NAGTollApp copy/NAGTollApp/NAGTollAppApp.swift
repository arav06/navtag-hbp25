import SwiftUI
import GoogleSignIn

@main
struct NAGTollApp: App {
    @State private var user: GIDGoogleUser?
    @State private var userEmail: String = "unknown@example.com"  // Default email until sign-in
    @State private var currentPage: Page = .signIn
    
    // Create an instance of the WebSocketManager using @StateObject for proper lifecycle management
    @StateObject private var webSocketManager = WebSocketManager()

    var body: some Scene {
        WindowGroup {
            switch currentPage {
            case .signIn:
                LoginView(user: $user) {
                    if let email = user?.profile?.email {
                        self.userEmail = email  // Safely assign the user's email after sign-in
                    }
                    self.currentPage = .personalInfo  // Navigate to the personal info page
                }
                .environmentObject(webSocketManager)  // Provide WebSocketManager to LoginView

            case .personalInfo:
                if let user = user {
                    PersonalInfoView(
                        user: user,
                        hasFilledPersonalInfo: .constant(false),
                        onComplete: {
                            self.currentPage = .wallet  // Navigate to the wallet page
                        }
                    )
                    .environmentObject(webSocketManager)  // Provide WebSocketManager to PersonalInfoView
                    .onAppear {
                        webSocketManager.connect(to: "ws://18.219.180.114:8765")
                    }
                }

            case .wallet:
                WalletView(userEmail: userEmail)  // Pass the captured userEmail to WalletView
                    .environmentObject(webSocketManager)  // Provide WebSocketManager to WalletView if needed
            }
        }
    }
}

enum Page {
    case signIn
    case personalInfo
    case wallet
}
