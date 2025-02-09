import SwiftUI
import Foundation

func updateBalanceOnServer(email: String, funds: Double, completion: @escaping (Bool) -> Void) {
    // Construct the URL with query parameters
    let urlString = "https://able-only-chamois.ngrok-free.app/update_balance?email=\(email)&funds=\(funds)"
    guard let url = URL(string: urlString) else {
        print("Invalid URL")
        completion(false)
        return
    }

    // Create the GET request
    var request = URLRequest(url: url)
    request.httpMethod = "GET"  // Use GET request
    // No need to set a body or headers for GET requests

    // Initiate the network call
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error updating balance: \(error.localizedDescription)")
            completion(false)
            return
        }

        if let httpResponse = response as? HTTPURLResponse {
            print("HTTP Status Code: \(httpResponse.statusCode)")

            // Check if the request was successful
            if (200...299).contains(httpResponse.statusCode) {
                print("Balance successfully updated on server.")
                completion(true)
            } else {
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Server response: \(responseString)")
                }
                completion(false)
            }
        } else {
            print("Unexpected response format.")
            completion(false)
        }
    }.resume()
}


// Updated handleAddMoney function to navigate back to home
struct CreditCardView: View {
    @Binding var amountToAdd: String
    @Binding var navTagBalance: Double
    @State private var cardNumber: String = ""
    @State private var cardHolderName: String = ""
    @State private var expiryDate: String = ""
    @State private var cvv: String = ""
    @AppStorage("userEmail") private var userEmail: String = ""
    
    // Add presentationMode to dismiss the view after success
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Form {
            Section(header: Text("Card Details")) {
                TextField("Cardholder Name", text: $cardHolderName)
                TextField("Card Number", text: $cardNumber)
                    .keyboardType(.numberPad)
                TextField("Expiry Date (MM/YY)", text: $expiryDate)
                TextField("CVV", text: $cvv)
                    .keyboardType(.numberPad)
            }

            Button(action: handleAddMoney) {
                Text("Add $\(amountToAdd) to Wallet")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .navigationTitle("Credit Card Payment")
    }

    private func handleAddMoney() {
        guard let amount = Double(amountToAdd), amount > 0 else {
            print("Invalid amount")
            return
        }

        let amountToBeAdded = amount

        // Send balance update to the server
        updateBalanceOnServer(email: userEmail, funds: amountToBeAdded) { success in
            DispatchQueue.main.async {
                if success {
                    print("Server updated successfully with funds: \(amountToBeAdded)")
                    navTagBalance += amountToBeAdded  // Update local balance
                    amountToAdd = ""  // Clear the input field
                    
                    // Navigate back to Home or previous view
                    presentationMode.wrappedValue.dismiss()
                } else {
                    print("Failed to update balance on server.")
                }
            }
        }
    }
}
struct DebitCardView: View {
    @Binding var amountToAdd: String
    @Binding var navTagBalance: Double
    @State private var cardNumber: String = ""
    @State private var cardHolderName: String = ""
    @State private var expiryDate: String = ""
    @State private var cvv: String = ""
    @AppStorage("userEmail") private var userEmail: String = ""

    var body: some View {
        Form {
            Section(header: Text("Card Details")) {
                TextField("Cardholder Name", text: $cardHolderName)
                TextField("Card Number", text: $cardNumber)
                    .keyboardType(.numberPad)
                TextField("Expiry Date (MM/YY)", text: $expiryDate)
                TextField("CVV", text: $cvv)
                    .keyboardType(.numberPad)
            }

            Button(action: handleAddMoney) {
                Text("Add $\(amountToAdd) to Wallet")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .navigationTitle("Debit Card Payment")
    }

    private func handleAddMoney() {
        guard let amount = Double(amountToAdd), amount > 0 else {
            print("Invalid amount")
            return
        }

        // Keep a reference to the amount being added, since the balance update on the server might take some time
        let amountToBeAdded = amount

        // Send balance update to the server
        updateBalanceOnServer(email: userEmail, funds: amountToBeAdded) { success in
            DispatchQueue.main.async {
                if success {
                    print("Server updated successfully with funds: \(amountToBeAdded)")
                    navTagBalance += amountToBeAdded  // Update local balance
                    amountToAdd = ""  // Clear the input field
                } else {
                    print("Failed to update balance on server.")
                    // Optional: Show alert to user indicating the update failed
                }
            }
        }
    }
}

struct AddMoneyView: View {
    @Binding var navTagBalance: Double
    @State private var amountToAdd: String = ""
    @State private var isShowingPaymentOptions = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Enter Amount to Add")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.black)

            Text("$\(amountToAdd.isEmpty ? "0" : amountToAdd)")
                .font(.system(size: 50, weight: .bold))
                .foregroundColor(.black)
                .padding()

            CustomKeypad(amountToAdd: $amountToAdd)

            Button(action: {
                if !amountToAdd.isEmpty {
                    isShowingPaymentOptions = true
                }
            }) {
                Text("Proceed")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(15)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.all)
        .sheet(isPresented: $isShowingPaymentOptions) {
            NavigationView {
                PaymentOptionsView(amountToAdd: $amountToAdd, navTagBalance: $navTagBalance)
            }
        }
    }
}

struct CustomKeypad: View {
    @Binding var amountToAdd: String

    let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        Button(action: {
                            handleKeyPress(key: key)
                        }) {
                            Text(key)
                                .font(.title)
                                .frame(width: 70, height: 70)
                                .background(Color.blue.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
            }
        }
    }

    private func handleKeyPress(key: String) {
        if key == "⌫" {
            if !amountToAdd.isEmpty {
                amountToAdd.removeLast()
            }
        } else if key == "." {
            if !amountToAdd.contains(".") {
                amountToAdd.append(".")
            }
        } else {
            amountToAdd.append(key)
        }
    }
}

// MARK: - Payment Options View
struct PaymentOptionsView: View {
    @Binding var amountToAdd: String
    @Binding var navTagBalance: Double

    var body: some View {
        VStack(spacing: 20) {
            Text("Select Payment Method")
                .font(.title2)
                .bold()
                .foregroundColor(.blue)

            HStack(spacing: 20) {
                NavigationLink(destination: CreditCardView(amountToAdd: $amountToAdd, navTagBalance: $navTagBalance)) {
                    PaymentMethodCardView(method: "Credit Card", icon: "creditcard", color: .blue)
                }
                NavigationLink(destination: DebitCardView(amountToAdd: $amountToAdd, navTagBalance: $navTagBalance)) {
                    PaymentMethodCardView(method: "Debit Card", icon: "creditcard.fill", color: .green)
                }
            }

            Spacer()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.1), radius: 5))
        .frame(maxHeight: UIScreen.main.bounds.height * 0.5)
    }
}

// MARK: - Payment Method Card
struct PaymentMethodCardView: View {
    let method: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(color)

            Text(method)
                .font(.headline)
                .foregroundColor(.black)
        }
        .frame(width: 130, height: 130)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(15)
        .shadow(color: color.opacity(0.6), radius: 10, x: 0, y: 5)
    }
}

