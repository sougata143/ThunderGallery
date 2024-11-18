import Foundation

struct PhotoAdjustments: Codable {
    var brightness: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var temperature: Double = 6500
    var tint: Double = 0
    var highlights: Double = 0
    var shadows: Double = 0
    var sharpness: Double = 0
    var definition: Double = 0
} 