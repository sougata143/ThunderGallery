import SwiftUI
import Photos
import CoreImage
import CoreData

class PhotoEditorViewModel: ObservableObject {
    enum EditingTool {
        case adjust, filters, crop, text
    }
    
    @Published var editedImage: UIImage?
    @Published var currentTool: EditingTool = .adjust
    @Published var adjustments = PhotoAdjustments()
    @Published var hasChanges = false
    
    private let asset: PHAsset
    private let context = CIContext()
    
    init(asset: PHAsset) {
        self.asset = asset
        loadOriginalImage()
    }
    
    private func loadOriginalImage() {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, _ in
            DispatchQueue.main.async {
                self?.editedImage = image
            }
        }
    }
    
    func applyAdjustments() {
        guard let inputImage = CIImage(image: editedImage ?? UIImage()) else { return }
        
        var outputImage = inputImage
        
        // Apply adjustments
        outputImage = outputImage
            .applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: adjustments.brightness,
                kCIInputContrastKey: adjustments.contrast,
                kCIInputSaturationKey: adjustments.saturation
            ])
            .applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: adjustments.temperature, y: adjustments.tint)
            ])
        
        if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            editedImage = UIImage(cgImage: cgImage)
            hasChanges = true
        }
    }
    
    @MainActor
    func saveEdits() async throws {
        guard hasChanges, let editedImage = editedImage else { return }
        
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: editedImage)
        }
        
        // Save edit history to CoreData
        let context = PersistenceController.shared.container.viewContext
        let editHistory = NSEntityDescription.insertNewObject(forEntityName: "EditHistory", into: context) as! NSManagedObject
        
        editHistory.setValue(Date(), forKey: "editDate")
        editHistory.setValue("adjustment", forKey: "editType")
        editHistory.setValue(try? JSONEncoder().encode(adjustments), forKey: "editParameters")
        
        try context.save()
    }
} 