import Photos
import SwiftUI
import Vision
import CoreData

class AlbumsViewModel: ObservableObject {
    @Published var albums: [AlbumItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var detectedFaces: [FaceGroup] = []
    @Published var faceRecognitionManager: FaceRecognitionManager
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext) {
        self.context = context
        self.faceRecognitionManager = FaceRecognitionManager(context: context)
        fetchAlbums()
    }
    
    func fetchAlbums() {
        isLoading = true
        
        // Fetch user created albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )
        
        // Fetch smart albums (Recently Added, Favorites, etc.)
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        
        var albumItems: [AlbumItem] = []
        
        // Process smart albums
        smartAlbums.enumerateObjects { collection, _, _ in
            if let album = self.createAlbumItem(from: collection) {
                albumItems.append(album)
            }
        }
        
        // Process user albums
        userAlbums.enumerateObjects { collection, _, _ in
            if let album = self.createAlbumItem(from: collection) {
                albumItems.append(album)
            }
        }
        
        DispatchQueue.main.async {
            self.albums = albumItems
            self.isLoading = false
        }
    }
    
    private func detectFacesInLibrary() {
        isLoading = true
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var faceGroups: [FaceGroup] = []
        let faceDetectionQueue = DispatchQueue(label: "com.thundergallery.facedetection")
        
        faceDetectionQueue.async {
            let semaphore = DispatchSemaphore(value: 0)
            var processedAssets = 0
            
            assets.enumerateObjects { asset, _, _ in
                self.detectFaces(in: asset) { faces in
                    if !faces.isEmpty {
                        for face in faces {
                            if let existingGroup = faceGroups.first(where: { $0.matches(face) }) {
                                existingGroup.addFace(face, in: asset)
                            } else {
                                let newGroup = FaceGroup(face: face, asset: asset)
                                faceGroups.append(newGroup)
                            }
                        }
                    }
                    
                    processedAssets += 1
                    if processedAssets == assets.count {
                        semaphore.signal()
                    }
                }
            }
            
            semaphore.wait()
            
            // Create albums for face groups
            DispatchQueue.main.async {
                self.createFaceAlbums(from: faceGroups)
                self.isLoading = false
            }
        }
    }
    
    private func detectFaces(in asset: PHAsset, completion: @escaping ([VNFaceObservation]) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 1024, height: 1024),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            guard let cgImage = image?.cgImage else {
                completion([])
                return
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage)
            let faceDetectionRequest = VNDetectFaceRectanglesRequest()
            
            do {
                try requestHandler.perform([faceDetectionRequest])
                if let faces = faceDetectionRequest.results {
                    completion(faces)
                } else {
                    completion([])
                }
            } catch {
                print("Face detection failed: \(error)")
                completion([])
            }
        }
    }
    
    private func createFaceAlbums(from groups: [FaceGroup]) {
        for (index, group) in groups.enumerated() {
            let albumName = "Face Group \(index + 1)"
            
            do {
                var placeholderIdentifier: String?
                
                try PHPhotoLibrary.shared().performChangesAndWait {
                    let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                    placeholderIdentifier = createRequest.placeholderForCreatedAssetCollection.localIdentifier
                }
                
                // Only proceed if we have a valid placeholder identifier
                guard let identifier = placeholderIdentifier else { continue }
                
                // Wait for the album to be created
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Add photos to the album
                    let fetchResult = PHAssetCollection.fetchAssetCollections(
                        withLocalIdentifiers: [identifier],
                        options: nil
                    )
                    
                    guard let collection = fetchResult.firstObject else { return }
                    
                    do {
                        try PHPhotoLibrary.shared().performChangesAndWait {
                            let assets = PHAsset.fetchAssets(withLocalIdentifiers: group.assetIdentifiers, options: nil)
                            if let addAssetRequest = PHAssetCollectionChangeRequest(for: collection) {
                                addAssetRequest.addAssets(assets as NSFastEnumeration)
                            }
                        }
                    } catch {
                        print("Failed to add photos to face album: \(error)")
                    }
                }
            } catch {
                print("Failed to create face album: \(error)")
            }
        }
        
        // Refresh albums list
        fetchAlbums()
    }
    
    private func createAlbumItem(from collection: PHAssetCollection) -> AlbumItem? {
        // Fetch assets count
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        let assets = PHAsset.fetchAssets(in: collection, options: fetchOptions)
        
        // Only show albums that contain images
        guard assets.count > 0 else { return nil }
        
        // Get the latest asset as cover photo
        let coverAsset = assets.lastObject
        
        return AlbumItem(
            id: collection.localIdentifier,
            title: collection.localizedTitle ?? "",
            assetCount: assets.count,
            coverAsset: coverAsset,
            collection: collection
        )
    }
    
    func createNewAlbum(name: String) {
        do {
            try PHPhotoLibrary.shared().performChangesAndWait {
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            }
            
            // Refresh albums list
            fetchAlbums()
            
        } catch {
            self.error = error
        }
    }
    
    func startFaceRecognition() async {
        do {
            try await faceRecognitionManager.processLibrary()
            await createFaceAlbumsFromRecognizedPeople()
        } catch {
            print("Face recognition failed: \(error)")
        }
    }
    
    private func createFaceAlbumsFromRecognizedPeople() async {
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "FacePerson")
        
        do {
            let people = try context.fetch(fetchRequest)
            for person in people {
                let name = person.value(forKey: "name") as? String ?? "Unknown Person"
                let faces = person.value(forKey: "faces") as? Set<NSManagedObject> ?? []
                
                let assetIds = faces.compactMap { face in
                    face.value(forKey: "assetIdentifier") as? String
                }
                
                if !assetIds.isEmpty {
                    try await createAlbumForPerson(name: name, assetIds: assetIds)
                }
            }
        } catch {
            print("Failed to create face albums: \(error)")
        }
    }
    
    private func createAlbumForPerson(name: String, assetIds: [String]) async throws {
        do {
            var placeholderIdentifier: String?
            
            try PHPhotoLibrary.shared().performChangesAndWait {
                let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                placeholderIdentifier = createRequest.placeholderForCreatedAssetCollection.localIdentifier
            }
            
            // Only proceed if we have a valid placeholder identifier
            guard let identifier = placeholderIdentifier else { return }
            
            // Wait for the album to be created
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Add photos to the album
            let fetchResult = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [identifier],
                options: nil
            )
            
            guard let collection = fetchResult.firstObject else { return }
            
            try PHPhotoLibrary.shared().performChangesAndWait {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIds, options: nil)
                if let addAssetRequest = PHAssetCollectionChangeRequest(for: collection) {
                    addAssetRequest.addAssets(assets as NSFastEnumeration)
                }
            }
            
            // Refresh albums list after creating the new album
            await MainActor.run {
                self.fetchAlbums()
            }
        } catch {
            print("Failed to create album for person \(name): \(error)")
            throw error
        }
    }
}

// Model for album items
struct AlbumItem: Identifiable {
    let id: String
    let title: String
    let assetCount: Int
    let coverAsset: PHAsset?
    let collection: PHAssetCollection
}

// Face grouping support
class FaceGroup {
    private var faceObservation: VNFaceObservation
    private(set) var assetIdentifiers: [String] = []
    private var faceDescriptor: [Float]?
    
    init(face: VNFaceObservation, asset: PHAsset) {
        self.faceObservation = face
        self.assetIdentifiers.append(asset.localIdentifier)
    }
    
    func matches(_ face: VNFaceObservation) -> Bool {
        // In a real app, you would use face landmarks or face embeddings
        // to determine if faces match. This is a simplified version.
        let currentBounds = faceObservation.boundingBox
        let newBounds = face.boundingBox
        
        // Compare face rectangles with some tolerance
        let tolerance: CGFloat = 0.2
        return abs(currentBounds.width - newBounds.width) < tolerance &&
               abs(currentBounds.height - newBounds.height) < tolerance
    }
    
    func addFace(_ face: VNFaceObservation, in asset: PHAsset) {
        assetIdentifiers.append(asset.localIdentifier)
    }
} 