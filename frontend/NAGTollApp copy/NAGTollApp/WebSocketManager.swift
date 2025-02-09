import Foundation
import Combine

class WebSocketManager: ObservableObject {
    @Published var receivedMessage: String = "No message received yet."

    private var webSocketTask: URLSessionWebSocketTask?

    // MARK: - Connect to WebSocket
    func connect(to urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid WebSocket URL")
            return
        }

        let urlSession = URLSession(configuration: .default)
        webSocketTask = urlSession.webSocketTask(with: url)
        webSocketTask?.resume()
        print("Connected to WebSocket.")
        receiveMessage()  // Start listening for incoming messages
    }

    // MARK: - Send Latitude and Longitude as JSON
    func sendLatLon(latitude: Double, longitude: Double) {
        let messageData: [String: Double] = [
            "latitude": latitude,
            "longitude": longitude
        ]

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: messageData, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                sendMessage(jsonString)  // Send the lat/lon JSON string
            }
        } catch {
            print("Failed to serialize latitude/longitude: \(error.localizedDescription)")
        }
    }

    // MARK: - Generic Method to Send Text Messages
    private func sendMessage(_ message: String) {
        let webSocketMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(webSocketMessage) { error in
            if let error = error {
                print("Error sending message: \(error.localizedDescription)")
            } else {
                print("Message sent: \(message)")
            }
        }
    }

    // MARK: - Listen for Incoming WebSocket Messages
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        print("Received message: \(text)")
                        self?.receivedMessage = text

                        // Handle "sendlatlon" request from the server
                        if text == "sendlatlon" {
                            self?.sendLatLon(latitude: 142.1234, longitude: -32.4194)  // Example coordinates (San Francisco)
                        }
                    }
                default:
                    print("Received unexpected message type.")
                }
            case .failure(let error):
                print("Failed to receive message: \(error.localizedDescription)")
            }

            // Continue listening for messages
            self?.receiveMessage()
        }
    }

    // MARK: - Disconnect from WebSocket
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        print("Disconnected from WebSocket.")
    }
}
