import SwiftUI
import GoogleSignIn
import GoogleSignInSwift

struct LoginView: View {
    @Binding var user: GIDGoogleUser?
    @AppStorage("isUserLoggedIn") private var isUserLoggedIn: Bool = false
    @AppStorage("userEmail") private var userEmail: String = ""
    let onSignIn: () -> Void  // Closure to trigger navigation to the home page

    var body: some View {
        ZStack {
            // Blue Background Gradient
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.black]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // App Title
                Text("Welcome to")
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                Text("NAVTag")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Logo
                Image("Navtag_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)
                    .cornerRadius(15)
                    .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
                    .padding()

                Spacer()

                // Sign-In Button
                Button(action: handleSignIn) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill.badge.plus")
                            .font(.system(size: 24, weight: .bold))
                        Text("Sign in with Google")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                                               startPoint: .leading,
                                               endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
                }

                Spacer()
            }
            .padding()
        }
    }

    private func handleSignIn() {
        guard let rootViewController = getRootViewController() else {
            print("No root view controller found.")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                print("Sign-In error: \(error.localizedDescription)")
                return
            }

            if let resultUser = result?.user {
                self.user = resultUser
                print("User signed in: \(resultUser.profile?.name ?? "Unknown")")

                // Store session details in UserDefaults
                if let email = resultUser.profile?.email {
                    userEmail = email
                    isUserLoggedIn = true  // Set the logged-in status
                    onSignIn()  // Navigate to the home page
                }
            }
        }
    }
}

// Utility function to get the root view controller
private func getRootViewController() -> UIViewController? {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootViewController = scene.windows.first?.rootViewController else {
        return nil
    }
    return rootViewController
}
