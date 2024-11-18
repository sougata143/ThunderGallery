import SwiftUI

struct EditingControlsView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    
    var body: some View {
        VStack {
            switch viewModel.currentTool {
            case .adjust:
                AdjustmentControlsView(viewModel: viewModel)
            case .filters:
                FiltersControlView(viewModel: viewModel)
            case .crop:
                CropControlView(viewModel: viewModel)
            case .text:
                TextControlView(viewModel: viewModel)
            }
        }
        .padding()
    }
}

// Adjustment Controls
struct AdjustmentControlsView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            AdjustmentSlider(
                value: $viewModel.adjustments.brightness,
                range: -1...1,
                label: "Brightness"
            ) {
                viewModel.applyAdjustments()
            }
            
            AdjustmentSlider(
                value: $viewModel.adjustments.contrast,
                range: 0.5...1.5,
                label: "Contrast"
            ) {
                viewModel.applyAdjustments()
            }
            
            AdjustmentSlider(
                value: $viewModel.adjustments.saturation,
                range: 0...2,
                label: "Saturation"
            ) {
                viewModel.applyAdjustments()
            }
        }
    }
}

// Filters Control (placeholder)
struct FiltersControlView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    
    var body: some View {
        Text("Filters coming soon")
    }
}

// Crop Control (placeholder)
struct CropControlView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    
    var body: some View {
        Text("Crop tools coming soon")
    }
}

// Text Control (placeholder)
struct TextControlView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    
    var body: some View {
        Text("Text tools coming soon")
    }
}

// Reusable Adjustment Slider
struct AdjustmentSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    let onEditingChanged: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Slider(
                value: $value,
                in: range
            ) { _ in
                onEditingChanged()
            }
        }
    }
} 