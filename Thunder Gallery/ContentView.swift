//
//  ContentView.swift
//  Thunder Gallery
//
//  Created by SOUGATA ROY on 11/8/24.
//

import SwiftUI

struct ContentView: View {
    // Tab selection state
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Gallery Tab
            GalleryView()
                .tabItem {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }
                .tag(0)
            
            // Albums Tab
            AlbumsView()
                .tabItem {
                    Label("Albums", systemImage: "rectangle.stack.fill")
                }
                .tag(1)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

// Preview provider
#Preview {
    ContentView()
}
