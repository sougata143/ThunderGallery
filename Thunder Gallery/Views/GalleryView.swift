import SwiftUI
import Photos

struct GalleryView: View {
    @StateObject private var viewModel = GalleryViewModel()
    @State private var selectedAsset: PHAsset?
    @State private var showingEditor = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                (colorScheme == .dark ? Color.black : Color.white)
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    ScrollView(showsIndicators: false) {
                        LazyVGrid(
                            columns: Array(repeating: GridItem(.flexible(), spacing: 1),
                                         count: Int(geometry.size.width) / 120),
                            spacing: 1
                        ) {
                            ForEach(viewModel.photos, id: \.localIdentifier) { asset in
                                PhotoThumbnailView(asset: asset)
                                    .aspectRatio(1, contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation {
                                            selectedAsset = asset
                                            showingEditor = true
                                        }
                                    }
                            }
                        }
                        .padding(8)
                    }
                }
                
                if viewModel.isLoading {
                    LoadingView(message: "Loading photos...")
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { /* Sort by date */ }) {
                            Label("Sort by Date", systemImage: "calendar")
                        }
                        Button(action: { /* Sort by name */ }) {
                            Label("Sort by Name", systemImage: "textformat")
                        }
                        Button(action: { /* Filter */ }) {
                            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                if let asset = selectedAsset {
                    PhotoEditorView(asset: asset)
                        .transition(.move(edge: .bottom))
                }
            }
            .alert("Photo Access Required", 
                   isPresented: .constant(viewModel.error != nil)) {
                Button("Open Settings", action: openSettings)
                    .tint(.blue)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please allow access to your photos to use this app.")
            }
        }
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            }
        }
    }
} 