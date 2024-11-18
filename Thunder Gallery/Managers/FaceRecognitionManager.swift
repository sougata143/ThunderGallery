import Vision
import Photos
import CoreData

class FaceRecognitionManager: ObservableObject {
    @Published var progress: Double = 0
    @Published var isProcessing = false
    @Published var currentOperation: String = ""
    
    private let context: NSManagedObjectContext
    private let similarityThreshold: Float = 0.6
    private let processingQueue = DispatchQueue(label: "com.thundergallery.faceprocessing", qos: .userInitiated)
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    func processLibrary() async throws {
        isProcessing = true
        progress = 0
        currentOperation = "Scanning photos"
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        
        var processedFaces: [FaceFeatures] = []
        let totalAssets = assets.count
        var processedAssets = 0
        
        // Process assets in batches
        let batchSize = 10
        for i in stride(from: 0, to: totalAssets, by: batchSize) {
            let end = min(i + batchSize, totalAssets)
            let range = i..<end
            
            let batchAssets = assets.objects(at: IndexSet(range))
            if let batchFaces = try await processBatch(assets: Array(batchAssets)) {
                processedFaces.append(contentsOf: batchFaces)
            }
            
            processedAssets += batchSize
            await updateProgress(Double(processedAssets) / Double(totalAssets))
        }
        
        // Cluster faces
        await updateOperation("Clustering faces")
        let clusters = try await clusterFaces(processedFaces)
        
        // Save to Core Data
        await updateOperation("Saving results")
        try await saveClusters(clusters)
        
        isProcessing = false
    }
    
    private func processBatch(assets: [PHAsset]) async throws -> [FaceFeatures]? {
        var batchFaces: [FaceFeatures] = []
        
        for asset in assets {
            if let faces = try? await detectFaces(in: asset) {
                batchFaces.append(contentsOf: faces)
            }
        }
        
        return batchFaces.isEmpty ? nil : batchFaces
    }
    
    private func detectFaces(in asset: PHAsset) async throws -> [FaceFeatures] {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = true
        
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 1024, height: 1024),
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let image = image, let cgImage = image.cgImage else {
                    continuation.resume(throwing: FaceRecognitionError.failedToProcessImage)
                    return
                }
                
                do {
                    let requestHandler = VNImageRequestHandler(cgImage: cgImage)
                    let faceDetectionRequest = VNDetectFaceLandmarksRequest()
                    
                    try requestHandler.perform([faceDetectionRequest])
                    
                    guard let observations = faceDetectionRequest.results else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let faceFeatures = try observations.compactMap { observation in
                        try FaceFeatures(observation: observation, in: cgImage)
                    }
                    
                    continuation.resume(returning: faceFeatures)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func clusterFaces(_ faces: [FaceFeatures]) async throws -> [[FaceFeatures]] {
        await updateOperation("Analyzing face similarities")
        
        var clusters: [[FaceFeatures]] = []
        
        for face in faces {
            if let matchingClusterIndex = clusters.firstIndex(where: { cluster in
                cluster.contains { existingFace in
                    face.similarity(with: existingFace) > similarityThreshold
                }
            }) {
                clusters[matchingClusterIndex].append(face)
            } else {
                clusters.append([face])
            }
        }
        
        return clusters
    }
    
    private func saveClusters(_ clusters: [[FaceFeatures]]) async throws {
        try await context.perform {
            for (index, cluster) in clusters.enumerated() {
                let person = NSEntityDescription.insertNewObject(forEntityName: "FacePerson", into: self.context) as! NSManagedObject
                person.setValue("Person \(index + 1)", forKey: "name")
                person.setValue(Date(), forKey: "createdAt")
                person.setValue(Date(), forKey: "lastUpdated")
                
                for face in cluster {
                    let faceInstance = NSEntityDescription.insertNewObject(forEntityName: "FaceInstance", into: self.context) as! NSManagedObject
                    faceInstance.setValue(try? JSONEncoder().encode(face), forKey: "features")
                    faceInstance.setValue(Date(), forKey: "createdAt")
                    faceInstance.setValue(person, forKey: "person")
                }
            }
            
            try self.context.save()
        }
    }
    
    @MainActor
    private func updateProgress(_ value: Double) {
        progress = value
    }
    
    @MainActor
    private func updateOperation(_ operation: String) {
        currentOperation = operation
    }
} 