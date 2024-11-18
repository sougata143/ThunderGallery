import SwiftUI
import Photos

struct PhotoEditorView: View {
    @StateObject private var viewModel: PhotoEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showError = false
    @State private var errorMessage = ""
    
    init(asset: PHAsset) {
        _viewModel = StateObject(wrappedValue: PhotoEditorViewModel(asset: asset))
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Image preview
                    ImagePreviewView(image: viewModel.editedImage)
                        .frame(height: geometry.size.height * 0.7)
                    
                    // Editing controls
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            EditingToolButton(title: "Adjust", icon: "slider.horizontal.3") {
                                viewModel.currentTool = .adjust
                            }
                            
                            EditingToolButton(title: "Filters", icon: "camera.filters") {
                                viewModel.currentTool = .filters
                            }
                            
                            EditingToolButton(title: "Crop", icon: "crop") {
                                viewModel.currentTool = .crop
                            }
                            
                            EditingToolButton(title: "Text", icon: "textformat") {
                                viewModel.currentTool = .text
                            }
                        }
                        .padding()
                    }
                    
                    // Tool-specific controls
                    EditingControlsView(viewModel: viewModel)
                        .frame(height: geometry.size.height * 0.2)
                }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Task {
                            do {
                                try await viewModel.saveEdits()
                                dismiss()
                            } catch {
                                errorMessage = error.localizedDescription
                                showError = true
                            }
                        }
                    }
                    .disabled(!viewModel.hasChanges)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
} 