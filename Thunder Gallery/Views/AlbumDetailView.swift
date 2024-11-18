import SwiftUI
import Photos

struct AlbumDetailView: View {
    let album: AlbumItem
    @StateObject private var viewModel: AlbumDetailViewModel
    @State private var selectedAsset: PHAsset?
    @State private var showingEditor = false
    
    init(album: AlbumItem) {
        self.album = album
        _viewModel = StateObject(wrappedValue: AlbumDetailViewModel(album: album))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 2),
                                 count: Int(geometry.size.width) / 120),
                    spacing: 2
                ) {
                    ForEach(viewModel.photos, id: \.localIdentifier) { asset in
                        PhotoThumbnailView(asset: asset)
                            .aspectRatio(1, contentMode: .fill)
                            .onTapGesture {
                                selectedAsset = asset
                                showingEditor = true
                            }
                    }
                }
            }
        }
        .navigationTitle(album.title)
        .sheet(isPresented: $showingEditor) {
            if let asset = selectedAsset {
                PhotoEditorView(asset: asset)
            }
        }
    }
}

class AlbumDetailViewModel: ObservableObject {
    @Published var photos: [PHAsset] = []
    private let album: AlbumItem
    
    init(album: AlbumItem) {
        self.album = album
        fetchPhotos()
    }
    
    private func fetchPhotos() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let assets = PHAsset.fetchAssets(in: album.collection, options: fetchOptions)
        photos = assets.objects(at: IndexSet(0..<assets.count))
    }
} 