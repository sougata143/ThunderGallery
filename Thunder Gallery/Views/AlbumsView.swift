import SwiftUI
import Photos

struct AlbumsView: View {
    @StateObject private var viewModel: AlbumsViewModel
    @State private var showingCreateSheet = false
    @State private var newAlbumName = ""
    @Environment(\.colorScheme) var colorScheme
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: AlbumsViewModel(context: context))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color.black : Color.white)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        if !viewModel.albums.isEmpty {
                            let faceAlbums = viewModel.albums.filter { $0.title.contains("Face Group") }
                            let regularAlbums = viewModel.albums.filter { !$0.title.contains("Face Group") }
                            
                            if !faceAlbums.isEmpty {
                                AlbumSection(title: "People", albums: faceAlbums)
                            }
                            
                            if !regularAlbums.isEmpty {
                                AlbumSection(title: "Albums", albums: regularAlbums)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Albums")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .overlay {
                if viewModel.isLoading {
                    LoadingView(message: "Processing albums...")
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateAlbumSheet(
                    albumName: $newAlbumName,
                    onCreate: {
                        if !newAlbumName.isEmpty {
                            viewModel.createNewAlbum(name: newAlbumName)
                            newAlbumName = ""
                            showingCreateSheet = false
                        }
                    }
                )
            }
        }
    }
}

struct AlbumSection: View {
    let title: String
    let albums: [AlbumItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            AlbumCard(album: album)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct AlbumCard: View {
    let album: AlbumItem
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let coverAsset = album.coverAsset {
                PhotoThumbnailView(asset: coverAsset)
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .overlay {
                        Image(systemName: "photo.on.rectangle")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(album.assetCount) photos")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: 160)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(colorScheme == .dark ? Color.black : Color.white)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
}

// Create Album Sheet
struct CreateAlbumSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var albumName: String
    let onCreate: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Album Name", text: $albumName)
            }
            .navigationTitle("New Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        onCreate()
                    }
                    .disabled(albumName.isEmpty)
                }
            }
        }
    }
} 