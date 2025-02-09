//
//  ImageUploadButton.swift
//  NAGTollApp
//
//  Created by Nathan Chen on 2/8/25.
//

import SwiftUI

struct ImageUploadButton: View {
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
            }

            Button(action: { showingImagePicker = true }) {
                Text(image == nil ? title : "Change \(title)")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.3))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
        }
    }
}

