import Photos
import SwiftUI

class GalleryViewModel: ObservableObject {
    @Published var photos: [PHAsset] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedPhotos: Set<String> = []
    @Published var sortOption: PhotoSortOption = .creationDate
    
    private let photoManager = PhotoManager.shared
    
    init() {
        Task {
            await loadPhotos()
        }
    }
    
    @MainActor
    func loadPhotos() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let authorized = await photoManager.requestAuthorization()
            guard authorized else {
                error = PhotoError.unauthorized
                return
            }
            
            photos = try await photoManager.fetchPhotos(sortBy: sortOption)
        } catch {
            self.error = error
        }
    }
    
    func togglePhotoSelection(_ asset: PHAsset) {
        if selectedPhotos.contains(asset.localIdentifier) {
            selectedPhotos.remove(asset.localIdentifier)
        } else {
            selectedPhotos.insert(asset.localIdentifier)
        }
    }
    
    func deleteSelectedPhotos() async {
        let assetsToDelete = photos.filter { selectedPhotos.contains($0.localIdentifier) }
        do {
            try await photoManager.deletePhotos(assetsToDelete)
            selectedPhotos.removeAll()
            await loadPhotos()
        } catch {
            self.error = error
        }
    }
    
    func createAlbumWithSelectedPhotos(named name: String) async {
        let assetsToAdd = photos.filter { selectedPhotos.contains($0.localIdentifier) }
        do {
            _ = try await photoManager.createAlbum(named: name, with: assetsToAdd)
            selectedPhotos.removeAll()
        } catch {
            self.error = error
        }
    }
    
    func setSortOption(_ option: PhotoSortOption) async {
        sortOption = option
        await loadPhotos()
    }
    
    func toggleFavorite(_ asset: PHAsset) async {
        do {
            try await photoManager.saveFavoriteState(!asset.isFavorite, for: asset)
            await loadPhotos()
        } catch {
            self.error = error
        }
    }
} 