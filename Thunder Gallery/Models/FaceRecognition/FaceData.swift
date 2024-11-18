import Vision
import CoreData
import UIKit

struct FaceFeatures: Codable {
    let landmarks: [String: CGPoint]
    let embedding: [Float]
    let boundingBox: CGRect
    
    enum CodingKeys: String, CodingKey {
        case landmarks, embedding, boundingBox
    }
    
    init(observation: VNFaceObservation, in cgImage: CGImage) throws {
        // Get face landmarks
        var landmarkPoints: [String: CGPoint] = [:]
        if let landmarks = try? observation.landmarks?.allPoints?.normalizedPoints {
            for (index, point) in landmarks.enumerated() {
                landmarkPoints["point_\(index)"] = point
            }
        }
        self.landmarks = landmarkPoints
        
        // Store the bounding box
        self.boundingBox = observation.boundingBox
        
        // Get face embedding
        let faceRegion = VNImageRectForNormalizedRect(
            observation.boundingBox,
            cgImage.width,
            cgImage.height
        )
        
        guard let faceImage = cgImage.cropping(to: faceRegion) else {
            throw FaceRecognitionError.failedToComputeEmbedding
        }
        
        // Create face recognition request
        let requestHandler = VNImageRequestHandler(cgImage: faceImage)
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        try requestHandler.perform([faceDetectionRequest])
        
        // Extract embeddings from the face region
        var embeddings: [Float] = []
        if let faceObservations = faceDetectionRequest.results,
           let firstFace = faceObservations.first {
            // Convert the face region into grayscale values as a simple embedding
            let faceRegionWidth = Int(faceRegion.width)
            let faceRegionHeight = Int(faceRegion.height)
            let context = CIContext()
            let ciImage = CIImage(cgImage: faceImage)
            let grayscaleFilter = CIFilter(name: "CIPhotoEffectNoir")
            grayscaleFilter?.setValue(ciImage, forKey: kCIInputImageKey)
            
            if let outputImage = grayscaleFilter?.outputImage,
               let grayscaleCGImage = context.createCGImage(outputImage, from: outputImage.extent) {
                let dataProvider = grayscaleCGImage.dataProvider
                let pixelData = dataProvider?.data
                let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
                
                // Sample the image at regular intervals to create an embedding
                let sampleSize = 32 // Reduce the embedding size
                let stepX = faceRegionWidth / sampleSize
                let stepY = faceRegionHeight / sampleSize
                
                for y in stride(from: 0, to: faceRegionHeight, by: stepY) {
                    for x in stride(from: 0, to: faceRegionWidth, by: stepX) {
                        let offset = (y * faceRegionWidth + x) * 4 // 4 bytes per pixel (RGBA)
                        let intensity = Float(data[offset]) / 255.0 // Use only the first channel
                        embeddings.append(intensity)
                    }
                }
            }
        }
        
        self.embedding = embeddings.isEmpty ? Array(repeating: 0, count: 1024) : embeddings
    }
    
    // Compute similarity with another face
    func similarity(with other: FaceFeatures) -> Float {
        guard !embedding.isEmpty && !other.embedding.isEmpty else { return 0 }
        
        // Cosine similarity of embeddings
        let dotProduct = zip(embedding, other.embedding)
            .map { $0.0 * $0.1 }
            .reduce(0, +)
        
        let magnitude1 = sqrt(embedding.map { $0 * $0 }.reduce(0, +))
        let magnitude2 = sqrt(other.embedding.map { $0 * $0 }.reduce(0, +))
        
        guard magnitude1 > 0 && magnitude2 > 0 else { return 0 }
        return dotProduct / (magnitude1 * magnitude2)
    }
}

enum FaceRecognitionError: Error {
    case failedToComputeEmbedding
    case failedToProcessImage
    case failedToSaveData
    
    var localizedDescription: String {
        switch self {
        case .failedToComputeEmbedding:
            return "Failed to compute face embedding"
        case .failedToProcessImage:
            return "Failed to process image"
        case .failedToSaveData:
            return "Failed to save face data"
        }
    }
} 