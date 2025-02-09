import SwiftUI
import UIKit
import PhotosUI  // For photo library permission checking

// MARK: - Image Picker for Photo Library
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @State private var isAccessDenied = false  // Track permission status

    func makeUIViewController(context: Context) -> UIImagePickerController {
        checkPhotoLibraryPermission()  // Check and request permission before opening the picker

        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator Class for Handling Image Selection
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.image = selectedImage
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }

    // MARK: - Permission Check for Photo Library
    private func checkPhotoLibraryPermission() {
        let status = PHPhotoLibrary.authorizationStatus()

        switch status {
        case .authorized:
            print("Access granted to photo library.")
        case .denied, .restricted:
            print("Access denied or restricted.")
            isAccessDenied = true  // Update state to inform the user if needed
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { newStatus in
                if newStatus == .authorized {
                    print("Access granted after request.")
                } else {
                    print("Access denied.")
                    isAccessDenied = true
                }
            }
        @unknown default:
            fatalError("Unexpected case for photo library authorization status.")
        }
    }
}
