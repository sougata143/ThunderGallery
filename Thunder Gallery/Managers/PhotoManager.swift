import Photos
import UIKit
import CoreData

class PhotoManager: ObservableObject {
    static let shared = PhotoManager()
    
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    
    private let imageManager = PHImageManager.default()
    private let cache = NSCache<NSString, UIImage>()
    
    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        cache.countLimit = 200 // Limit cache to 200 images
    }
    
    func requestAuthorization() async -> Bool {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            self.authorizationStatus = status
        }
        return status == .authorized || status == .limited
    }
    
    // MARK: - Photo Operations
    
    func fetchPhotos(sortBy: PhotoSortOption = .creationDate) async throws -> [PHAsset] {
        guard authorizationStatus == .authorized || authorizationStatus == .limited else {
            throw PhotoError.unauthorized
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [sortBy.sortDescriptor]
        fetchOptions.includeHiddenAssets = false
        fetchOptions.includeAllBurstAssets = false
        
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        return fetchResult.objects(at: IndexSet(0..<fetchResult.count))
    }
    
    func loadImage(for asset: PHAsset, targetSize: CGSize = PHImageManagerMaximumSize) async throws -> UIImage {
        let cacheKey = "\(asset.localIdentifier)-\(targetSize.width)-\(targetSize.height)" as NSString
        
        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = targetSize == PHImageManagerMaximumSize ? .highQualityFormat : .opportunistic
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: PhotoError.cancelled)
                    return
                }
                
                guard let image = image else {
                    continuation.resume(throwing: PhotoError.loadFailed)
                    return
                }
                
                self.cache.setObject(image, forKey: cacheKey)
                continuation.resume(returning: image)
            }
        }
    }
    
    func deletePhotos(_ assets: [PHAsset]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSFastEnumeration)
        }
    }
    
    func createAlbum(named name: String, with assets: [PHAsset]? = nil) async throws -> PHAssetCollection {
        var placeholderIdentifier: String?
        
        try await PHPhotoLibrary.shared().performChanges {
            let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholderIdentifier = createRequest.placeholderForCreatedAssetCollection.localIdentifier
        }
        
        guard let identifier = placeholderIdentifier,
              let collection = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [identifier],
                options: nil
              ).firstObject else {
            throw PhotoError.albumCreationFailed
        }
        
        if let assets = assets, !assets.isEmpty {
            try await addPhotos(assets, to: collection)
        }
        
        return collection
    }
    
    func addPhotos(_ assets: [PHAsset], to album: PHAssetCollection) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            if let addRequest = PHAssetCollectionChangeRequest(for: album) {
                addRequest.addAssets(assets as NSFastEnumeration)
            }
        }
    }
    
    func removePhotos(_ assets: [PHAsset], from album: PHAssetCollection) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            if let removeRequest = PHAssetCollectionChangeRequest(for: album) {
                removeRequest.removeAssets(assets as NSFastEnumeration)
            }
        }
    }
    
    // MARK: - Metadata Operations
    
    func saveFavoriteState(_ isFavorite: Bool, for asset: PHAsset) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest(for: asset)
            request.isFavorite = isFavorite
        }
    }
    
    func saveMetadata(_ metadata: [String: Any], for asset: PHAsset) async throws {
        let context = PersistenceController.shared.container.viewContext
        
        try await context.perform {
            let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "Photo")
            fetchRequest.predicate = NSPredicate(format: "localIdentifier == %@", asset.localIdentifier)
            
            let results = try context.fetch(fetchRequest)
            let photo: NSManagedObject
            
            if let existingPhoto = results.first {
                photo = existingPhoto
            } else {
                photo = NSEntityDescription.insertNewObject(forEntityName: "Photo", into: context)
                photo.setValue(asset.localIdentifier, forKey: "localIdentifier")
                photo.setValue(UUID(), forKey: "uuid")
                photo.setValue(Date(), forKey: "createdAt")
            }
            
            photo.setValue(try? JSONSerialization.data(withJSONObject: metadata), forKey: "customMetadata")
            photo.setValue(Date(), forKey: "lastModifiedAt")
            
            try context.save()
        }
    }
}

// MARK: - Supporting Types

enum PhotoSortOption {
    case creationDate
    case modificationDate
    case title
    
    var sortDescriptor: NSSortDescriptor {
        switch self {
        case .creationDate:
            return NSSortDescriptor(key: "creationDate", ascending: false)
        case .modificationDate:
            return NSSortDescriptor(key: "modificationDate", ascending: false)
        case .title:
            return NSSortDescriptor(key: "filename", ascending: true)
        }
    }
}

enum PhotoError: LocalizedError {
    case unauthorized
    case loadFailed
    case cancelled
    case albumCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Photo library access is not authorized"
        case .loadFailed:
            return "Failed to load photo"
        case .cancelled:
            return "Photo loading was cancelled"
        case .albumCreationFailed:
            return "Failed to create album"
        }
    }
} 