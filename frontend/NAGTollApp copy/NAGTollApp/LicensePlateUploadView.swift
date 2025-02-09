import SwiftUI
import UIKit

struct LicensePlateUploadView: View {
    let userEmail: String  // Dynamically passed email

    @State private var selectedImage: UIImage?
    @State private var isShowingCamera = false
    @State private var isShowingPhotoLibrary = false
    @State private var uploadStatus: String = ""  // Status updates

    var body: some View {
        VStack(spacing: 20) {
            Text("Upload or Take a Photo of Your License Plate")
                .font(.largeTitle)
                .bold()
                .padding()

            // Display Selected Image or Placeholder
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Text("No Image Selected")
                            .foregroundColor(.gray)
                            .font(.headline)
                    )
                    .padding()
            }

            // Take a Photo Button
            Button(action: {
                isShowingCamera = true
            }) {
                Text("Take a Photo")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }

            // Upload Image from Gallery Button
            Button(action: {
                isShowingPhotoLibrary = true
            }) {
                Text("Select from Gallery")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }

            // Upload Image to Server Button (Enabled only if an image is selected)
            if selectedImage != nil {
                Button(action: uploadLicensePlateImage) {
                    Text("Upload License Plate")
                        .fontWeight(.bold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }

            // Status Message
            if !uploadStatus.isEmpty {
                Text(uploadStatus)
                    .font(.footnote)
                    .foregroundColor(uploadStatus.contains("Success") ? .green : .red)
                    .padding()
            }

            // Disclaimer Text
            Text("⚠️ Submitting false or misleading information is a federal offense.")
                .font(.footnote)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraCaptureView(image: $selectedImage)
        }
        .sheet(isPresented: $isShowingPhotoLibrary) {
            ImagePicker(image: $selectedImage)
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("License Plate")
    }

    // MARK: - Upload License Plate Image Function
    private func uploadLicensePlateImage() {
        guard let image = selectedImage else {
            uploadStatus = "No image selected."
            return
        }

        guard let url = URL(string: "https://able-only-chamois.ngrok-free.app/add_license_plate") else {
            uploadStatus = "Invalid server URL."
            return
        }

        // Convert the image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            uploadStatus = "Failed to convert image."
            return
        }

        // Create the multipart form request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Create the multipart body
        var body = Data()

        // Append email field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"email\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(userEmail)\r\n".data(using: .utf8)!)

        // Append image data with "image" as the key
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"license_plate.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        // End of the multipart form
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Perform the request
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    uploadStatus = "Failed to upload: \(error.localizedDescription)"
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        uploadStatus = "Success! Image uploaded."
                    } else {
                        uploadStatus = "Server error: \(httpResponse.statusCode)"
                    }
                }

                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
            }
        }.resume()
    }
}

// MARK: - Camera Capture View for Taking Photos
struct CameraCaptureView: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraCaptureView

        init(_ parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let capturedImage = info[.originalImage] as? UIImage {
                parent.image = capturedImage
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}




