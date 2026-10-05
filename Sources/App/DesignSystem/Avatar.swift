import SwiftUI

struct Avatar: View {
    let url: URL?
    let size: Double

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Theme.avatarGradient
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
