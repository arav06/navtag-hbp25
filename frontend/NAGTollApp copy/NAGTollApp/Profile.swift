import SwiftUI
import Foundation

// MARK: - Profile Model
struct Profile {
    let name: String
    let email: String
    let phone: String
    let address: String

    // Provide a default initializer to handle empty or missing data
    init(name: String, email: String, phone: String, address: String) {
        self.name = name.isEmpty ? "Name not available" : name
        self.email = email.isEmpty ? "Email not available" : email
        self.phone = phone.isEmpty ? "Phone not available" : phone
        self.address = address.isEmpty ? "Address not available" : address
    }
}

// MARK: - Individual Profile Row View
struct ProfileRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.bold)
            Spacer()
            Text(value)
                .foregroundColor(.gray)
        }
    }
}

