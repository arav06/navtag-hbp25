import SwiftUI
import Combine

struct WalletView: View {
    let userEmail: String  // Get this from the main login view or parent
    
    @State private var navTagBalance: Double? = nil  // Store balance directly from the server
    @State private var isBalanceLoading = true  // Track if the balance is being fetched initially
    private let balanceUpdatePublisher = Timer.publish(every: 30, on: .main, in: .common).autoconnect()  // Timer for auto-refresh every 30 seconds

    @State private var transactions: [NavTagTransaction] = [
        NavTagTransaction(description: "Toll Payment - Route 101", amount: -20.0, date: "Feb 7, 2025"),
        NavTagTransaction(description: "Balance Top-Up", amount: 500.0, date: "Feb 6, 2025"),
        NavTagTransaction(description: "Toll Payment - Golden Gate", amount: -15.0, date: "Feb 5, 2025")
    ]
    @State private var cars: [Car] = []
    @State private var profile: Profile? = nil
    @State private var expandedWidget: WidgetType? = nil
    @State private var isShowingAddMoneyView = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // NavTag Card Section with balance
                NavTagCard(balance: navTagBalance ?? 0.0) {
                    withAnimation {
                        isShowingAddMoneyView.toggle()
                    }
                }
                .padding(.horizontal)

                if isBalanceLoading {
                    Text("Fetching balance...")
                        .foregroundColor(.gray)
                        .italic()
                }

                // Circle Widgets Section
                if expandedWidget == nil {
                    HStack(spacing: 30) {
                        CircleWidget(iconName: "car.fill", label: "AddCar", widgetType: .AddCar, expandedWidget: $expandedWidget)
                        CircleWidget(iconName: "person.fill", label: "Profile", widgetType: .profile, isCenter: true, expandedWidget: $expandedWidget)
                        CircleWidget(iconName: "car.2.fill", label: "MyCars", widgetType: .MyCar, expandedWidget: $expandedWidget)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }

                // Expanded Widget Section
                if let widget = expandedWidget {
                    ExpandedWidgetView(widgetType: widget, userEmail: userEmail, cars: cars, profile: profile, onClose: {
                        withAnimation {
                            expandedWidget = nil
                        }
                    })
                    .transition(
                        widget == .profile
                            ? .scale(scale: 0.8, anchor: .center).combined(with: .opacity)
                            : .move(edge: .bottom).combined(with: .opacity)
                    )
                    .padding()
                }

                // Transaction History Section
                if expandedWidget == nil {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Transaction History")
                            .font(.title2)
                            .bold()
                            .padding(.horizontal)

                        ForEach(transactions) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .padding(.vertical)
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("NavTag")
            .edgesIgnoringSafeArea(.bottom)
            .sheet(isPresented: $isShowingAddMoneyView) {
                AddMoneyView(navTagBalance: Binding(
                    get: { navTagBalance ?? 0.0 },
                    set: { newValue in navTagBalance = newValue }
                ))
            }
            .onAppear {
                fetchInitialBalance()
            }
            .onReceive(balanceUpdatePublisher) { _ in
                fetchBalance()  // Automatically fetch balance every 30 seconds
            }
        }
    }

    /// Fetch the balance initially and avoid displaying 0.0
    private func fetchInitialBalance() {
        fetchBalance { isBalanceLoading = false }  // Update balance and mark loading as complete
    }

    /// Fetch balance from the server and update the UI
    private func fetchBalance(onComplete: (() -> Void)? = nil) {
        guard let url = URL(string: "https://able-only-chamois.ngrok-free.app/get_balance?email=\(userEmail)") else {
            print("Invalid URL.")
            onComplete?()
            return
        }

        isBalanceLoading = true  // Indicate balance fetch is in progress

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch balance: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isBalanceLoading = false
                    onComplete?()
                }
                return
            }

            guard let data = data, let balanceString = String(data: data, encoding: .utf8) else {
                print("No data received or data could not be converted to String.")
                DispatchQueue.main.async {
                    isBalanceLoading = false
                    onComplete?()
                }
                return
            }

            // Try to convert the response string to a Double
            if let balance = Double(balanceString.trimmingCharacters(in: .whitespacesAndNewlines)) {
                DispatchQueue.main.async {
                    navTagBalance = balance  // Update the UI with the new balance
                    isBalanceLoading = false
                    onComplete?()
                }
            } else {
                print("Failed to convert response to Double. Response: \(balanceString)")
                DispatchQueue.main.async {
                    isBalanceLoading = false
                    onComplete?()
                }
            }
        }.resume()
    }
}
struct CarRowView: View {
    var car: Car

    var body: some View {
        HStack {
            AsyncImage(url: URL(string: car.imageUrl)) { image in
                image.resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "car.fill")
                            .foregroundColor(.white)
                            .font(.title2)
                    )
            }

            VStack(alignment: .leading) {
                Text(car.plateNumber.isEmpty ? "Unknown Plate" : car.plateNumber)
                    .font(.headline)
                Text(car.state.isEmpty ? "Unknown State" : car.state)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - Profile View
struct ProfileView: View {
    var profile: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                    .padding()

                VStack(alignment: .leading, spacing: 5) {
                    Text(profile.name)
                        .font(.title)
                        .bold()
                    Text(profile.email)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ProfileInfoRow(icon: "phone.fill", title: "Phone", value: profile.phone)
                ProfileInfoRow(icon: "house.fill", title: "Address", value: profile.address)
            }

            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 5)
    }
}



struct ProfileInfoRow: View {
    var icon: String
    var title: String
    var value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }
}

struct Car: Identifiable, Decodable {
    let id = UUID()
    let imageUrl: String
    let plateNumber: String
    let state: String

    enum CodingKeys: String, CodingKey {
        case imageUrl = "image_url"
        case plateNumber = "plate_number"
        case state
    }
}


enum WidgetType {
    case AddCar, profile, MyCar
}


struct TransactionRow: View {
    var transaction: NavTagTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.headline)
                Text(transaction.date)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Text("\(transaction.amount < 0 ? "-" : "+") $\(abs(transaction.amount), specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(transaction.amount < 0 ? .red : .green)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}


struct NavTagTransaction: Identifiable {
    let id = UUID()
    let description: String
    let amount: Double
    let date: String
}

struct LoadMoneyView: View {
    @Binding var navTagBalance: Double
    @State private var amountToLoad: String = ""

    var body: some View {
        VStack {
            Text("Load Money")
                .font(.largeTitle)
                .bold()
                .padding()

            TextField("Enter amount to load", text: $amountToLoad)
                .padding()
                .keyboardType(.decimalPad)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)

            Button(action: {
                if let amount = Double(amountToLoad) {
                    navTagBalance += amount
                    amountToLoad = ""  // Clear input after loading money
                }
            }) {
                Text("Add Money")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Spacer()
        }
    }
}

struct NavTagCard: View {
    var balance: Double
    var onAddMoney: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Text("NavTag Balance")
                .font(.headline)
                .foregroundColor(.gray)

            Text("$\(balance, specifier: "%.2f")")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.black)

            Button(action: onAddMoney) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.white)
                    Text("Add Money")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
    }
}


struct ExpandedWidgetView: View {
    var widgetType: WidgetType
    var userEmail: String
    var cars: [Car]
    var profile: Profile?
    var onClose: () -> Void

    @State private var isShowingUploadView = false  // State for showing the upload view
    @State private var myCars: [Car] = []  // Store fetched cars locally

    var body: some View {
        VStack {
            HStack {
                Text(expandedWidgetTitle())
                    .font(.title)
                    .bold()
                    .padding()
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.gray)
                }
                .padding()
            }

            if widgetType == .MyCar {
                ScrollView {
                    ForEach(myCars) { car in
                        CarRowView(car: car)
                            .padding(.horizontal)
                            .padding(.vertical, 5)
                    }
                }
                .onAppear {
                    fetchCars()
                }
            } else if widgetType == .profile {
                ScrollView {
                    if let profile = profile {
                        ProfileView(profile: profile)
                            .padding(.horizontal)
                    } else {
                        Text("Profile data not available.")
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
            } else if widgetType == .AddCar {
                VStack(spacing: 20) {
                    Image(systemName: "camera.fill")
                        .resizable()
                        .frame(width: 140, height: 100)
                        .foregroundColor(.blue)
                        .padding()

                    Text("Upload your car’s license plate.")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        isShowingUploadView = true  // Show the license plate upload view
                    }) {
                        Text("Upload License Plate")
                            .fontWeight(.bold)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .sheet(isPresented: $isShowingUploadView) {
                    LicensePlateUploadView(userEmail: userEmail)
                }
            } else {
                Spacer()
                Text("Unknown widget type.")
                    .font(.headline)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
    }

    private func expandedWidgetTitle() -> String {
        switch widgetType {
        case .AddCar: return "Add New Car"
        case .profile: return "Your Profile"
        case .MyCar: return "My Cars"
        }
    }

    // MARK: - Fetch Cars from API when MyCar widget is opened
    private func fetchCars() {
        guard let url = URL(string: "https://able-only-chamois.ngrok-free.app/my_cars?email=\(userEmail)") else {
            print("Invalid car URL.")
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Failed to fetch cars: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No car data received.")
                return
            }

            do {
                let decodedCars = try JSONDecoder().decode([Car].self, from: data)
                DispatchQueue.main.async {
                    myCars = decodedCars
                }
            } catch {
                print("Failed to decode car response: \(error.localizedDescription)")
            }
        }.resume()
    }
}

struct CircleWidget: View {
    var iconName: String
    var label: String
    var widgetType: WidgetType
    var isCenter: Bool = false  // Determines if the widget is in the center

    @Binding var expandedWidget: WidgetType?

    // Animation state to control the pop-out effect
    @State private var isPressed = false

    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: isPressed ? 80 : 70, height: isPressed ? 80 : 70)
                    .shadow(color: Color.blue.opacity(0.4), radius: 6, x: 0, y: 2)
                    .scaleEffect(isPressed ? 1.1 : 1.0)  // Slightly grow when touched
                    .animation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0.3), value: isPressed)

                Image(systemName: iconName)
                    .font(.system(size: 28))
                    .foregroundColor(.white)
            }
            .gesture(
                DragGesture(minimumDistance: 0)  // Detect minimal touches
                    .onChanged { _ in
                        isPressed = true  // Pop out the widget
                    }
                    .onEnded { _ in
                        isPressed = false  // Return to original size
                        withAnimation(.spring()) {
                            if expandedWidget == widgetType {
                                expandedWidget = nil  // Collapse if already expanded
                            } else {
                                expandedWidget = widgetType  // Expand selected widget
                            }
                        }
                    }
            )

            Text(label)
                .font(.subheadline)
                .foregroundColor(.black)
                .padding(.top, 5)
        }
    }
}

import SwiftUI

struct HomeView: View {
    @AppStorage("userEmail") private var userEmail: String = ""
    @AppStorage("isUserLoggedIn") private var isUserLoggedIn: Bool = false

    var body: some View {
        VStack {
            Button(action: handleLogout) {
                Text("Log Out")
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
        }
        .padding()
    }

    private func handleLogout() {
        isUserLoggedIn = false  // Reset the login state
        userEmail = ""  // Clear user information
    }
}
