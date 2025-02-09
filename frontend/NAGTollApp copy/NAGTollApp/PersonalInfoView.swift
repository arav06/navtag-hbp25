import SwiftUI
import GoogleSignIn

struct PersonalInfoView: View {
    let user: GIDGoogleUser
    @Binding var hasFilledPersonalInfo: Bool
    let onComplete: () -> Void
    
    @EnvironmentObject var webSocketManager: WebSocketManager  // ✅ Injected automatically
    

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var addressLine: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var zipCode: String = ""
    @State private var phoneNumber: String = ""

    @State private var governmentIDImage: UIImage?
    @State private var showingIDPicker = false

    // Per-field validation state
    @State private var firstNameError = false
    @State private var lastNameError = false
    @State private var addressError = false
    @State private var cityError = false
    @State private var stateError = false
    @State private var zipCodeError = false
    @State private var phoneNumberError = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {

                // Header Title
                Text("Let’s get to know you!")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Form Section - Wrapped in a Clean Card
                cardView {
                    VStack(spacing: 15) {
                        formField("First Name", text: $firstName, isError: $firstNameError)
                        formField("Last Name", text: $lastName, isError: $lastNameError)
                        formField("Phone Number", text: $phoneNumber, isError: $phoneNumberError)
                        formField("Address Line", text: $addressLine, isError: $addressError)

                        HStack {
                            formField("City", text: $city, isError: $cityError)
                            formField("State (e.g., NY)", text: $state, isError: $stateError)
                        }

                        formField("Zip Code", text: $zipCode, isError: $zipCodeError)
                    }
                }
                .padding(.horizontal)

                // Image Upload Section for Government ID
                cardView {
                    VStack {
                        ImageUploadSection(title: "Valid Government ID", image: $governmentIDImage, showingImagePicker: $showingIDPicker)

                        // Error message if no image is uploaded
                        if governmentIDImage == nil {
                            Text("Required").font(.footnote).foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)

                // Submit Button with Conditional Background Fix
                Button(action: handleSubmit) {
                    Text("Submit")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            Group {
                                if isFormValid() {
                                    LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .leading, endPoint: .trailing)
                                } else {
                                    Color.gray
                                }
                            }
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.5), radius: 12, x: 0, y: 6)
                }
                .disabled(!isFormValid())
                .padding(.horizontal)
                .padding(.top, 10)
            }
            .padding(.top)
            .background(Color(UIColor.systemGroupedBackground))
        }
        .sheet(isPresented: $showingIDPicker) {
            ImagePicker(image: $governmentIDImage)
        }
    }

    // MARK: - Handle Form Submission and POST Request
    private func handleSubmit() {
        validateFields()  // Ensure all fields are validated before submission
        
        guard let email = user.profile?.email else {
                print("Email not available.")
                return
            }

            if isFormValid() {
                print("Submitting Personal Info")

                let fullAddress = "\(addressLine), \(city), \(state), \(zipCode)"
                let message = "User Info: Name=\(firstName) \(lastName), Address=\(fullAddress), Phone=\(phoneNumber)"
                
                webSocketManager.connect(to: "ws://18.219.180.114:8765")

                print("WebSocket connection initiated.")

                // Proceed with other logic (e.g., server call)
                hasFilledPersonalInfo = true
                onComplete()

            }
        guard let email = user.profile?.email else {
            print("Email not available.")
            return
        }

        if isFormValid() {
            print("Submitting Personal Info:")
            print("Name: \(firstName) \(lastName)")
            print("Phone: \(phoneNumber)")
            print("Address: \(addressLine), \(city), \(state), \(zipCode)")

            // Create the concatenated address string
            let fullAddress = "\(addressLine), \(city), \(state), \(zipCode)"

            // Convert the government ID image to base64
            //let govIDBase64 = governmentIDImage?.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""

            // Create the user data to send
            let personalInfo = UserPersonalInfo(
                name: "\(firstName) \(lastName)",
                email: email,
                phone: phoneNumber,
                address: fullAddress
                //govid: govIDBase64
            )

            // Send the POST request
            sendUserData(personalInfo)

            hasFilledPersonalInfo = true  // Move to the main TabView
            onComplete()  // Trigger navigation to wallet page
        }
    }

    private func sendUserData(_ userInfo: UserPersonalInfo) {
        guard let url = URL(string: "https://able-only-chamois.ngrok-free.app/add_user") else {
            print("Invalid URL.")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let jsonData = try JSONEncoder().encode(userInfo)
            request.httpBody = jsonData

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Failed to send data: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("Response Status Code: \(httpResponse.statusCode)")

                    if (200...299).contains(httpResponse.statusCode) {
                        print("User data sent successfully!")
                    } else {
                        print("Server responded with status code: \(httpResponse.statusCode)")
                    }
                }

                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response body: \(responseString)")
                }
            }.resume()

        } catch {
            print("Failed to encode user data: \(error.localizedDescription)")
        }
    }

    // MARK: - Form Validation Functions
    private func formField(_ placeholder: String, text: Binding<String>, isError: Binding<Bool>) -> some View {
        VStack(alignment: .leading) {
            CustomTextField(placeholder, text: text, onEditingChanged: { _ in
                validateFields()
            })
            if isError.wrappedValue {
                Text("Required").font(.footnote).foregroundColor(.red)
            }
        }
    }

    private func validateFields() {
        firstNameError = firstName.trimmingCharacters(in: .whitespaces).isEmpty
        lastNameError = lastName.trimmingCharacters(in: .whitespaces).isEmpty
        phoneNumberError = !isValidPhoneNumber(phoneNumber)
        addressError = addressLine.trimmingCharacters(in: .whitespaces).isEmpty
        cityError = city.trimmingCharacters(in: .whitespaces).isEmpty
        stateError = !isValidState(state)
        zipCodeError = !isValidZipCode(zipCode)
    }

    private func isFormValid() -> Bool {
        return !(firstNameError || lastNameError || phoneNumberError || addressError || cityError || stateError || zipCodeError) && governmentIDImage != nil
    }

    private func isValidState(_ state: String) -> Bool {
        let validStates = ["AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
                           "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
                           "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
                           "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
                           "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]
        return validStates.contains(state.uppercased())
    }

    private func isValidZipCode(_ zip: String) -> Bool {
        let zipCodeRegex = "^[0-9]{5}$"
        let zipPredicate = NSPredicate(format: "SELF MATCHES %@", zipCodeRegex)
        return zipPredicate.evaluate(with: zip)
    }

    private func isValidPhoneNumber(_ phone: String) -> Bool {
        let phoneRegex = "^[0-9]{10}$"  // Simple 10-digit phone number
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phonePredicate.evaluate(with: phone)
    }

    // Reusable card view modifier
    private func cardView<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding()
            .background(Color.white)
            .cornerRadius(15)
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 5)
    }
}

// Updated data model for server request
struct UserPersonalInfo: Codable {
    let name: String
    let email: String
    let phone: String
    let address: String
    //let govid: String  // Base64-encoded government ID image
}

struct CustomTextField: View {
    private let placeholder: String
    @Binding var text: String
    let onEditingChanged: (Bool) -> Void

    init(_ placeholder: String, text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void) {
        self.placeholder = placeholder
        self._text = text
        self.onEditingChanged = onEditingChanged
    }

    var body: some View {
        TextField(placeholder, text: $text, onEditingChanged: onEditingChanged)
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct ImageUploadSection: View {
    var title: String
    @Binding var image: UIImage?
    @Binding var showingImagePicker: Bool

    var body: some View {
        VStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding(.bottom, 10)
            }

            Button(action: { showingImagePicker = true }) {
                Text(image == nil ? title : "Change \(title)")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(Color.blue)
                    .cornerRadius(12)
                    .shadow(color: Color.blue.opacity(0.3), radius: 5, x: 0, y: 2)
            }
        }
    }
}


