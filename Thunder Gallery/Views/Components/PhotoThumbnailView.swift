import SwiftUI
import Photos

struct PhotoThumbnailView: View {
    let asset: PHAsset
    @State private var image: UIImage?
    
    var body: some View {
        GeometryReader { geometry in
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                ProgressView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .background(Color.gray.opacity(0.2))
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        let size = CGSize(width: 200, height: 200)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            if let image = image {
                self.image = image
            }
        }
    }
} 