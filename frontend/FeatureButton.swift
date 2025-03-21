import SwiftUI

struct FeatureButton: View {
    let iconName: String
    let title: String
    let backgroundColor: Color

    var body: some View {
        VStack {
            Image(systemName: iconName)
                .font(.largeTitle)
                .padding()
                .background(backgroundColor)
                .clipShape(Circle())

            Text(title)
                .font(.headline)
        }
        .frame(width: 100, height: 120)
        .background(backgroundColor.opacity(0.2))
        .cornerRadius(15)
        .shadow(radius: 5)
    }
}
