//
//  ContentView.swift
//  serbase
//
//  Created by 구리뽕 on 6/8/25.
//

import SwiftUI

// 사이드바 항목을 관리하기 위한 열거형 추가
enum SidebarNavigationItem: String, Identifiable, CaseIterable, Hashable {
    // Photos
    case library = "Library"
    case favorites = "Favorites"
    case recentlySaved = "Recently Saved"
    case mapLocation = "Map"

    // Collections
    case days = "Days"
    case peopleAndPets = "People & Pets"
    case memories = "Memories"
    case trips = "Trips"
    case featuredPhotos = "Featured Photos"

    // Albums
    case albums = "Albums"
    case mediaTypes = "Media Types"
    case utilities = "Utilities"
    case projects = "Projects"

    // Sharing
    case sharedAlbums = "Shared Albums"

    var id: String { self.rawValue }

    var iconName: String {
        switch self {
        case .library: return "photo.on.rectangle.angled"
        case .favorites: return "heart.fill"
        case .recentlySaved: return "clock.fill"
        case .mapLocation: return "map.fill"
        case .days: return "calendar"
        case .peopleAndPets: return "person.2.fill"
        case .memories: return "star.fill"
        case .trips: return "airplane"
        case .featuredPhotos: return "sparkles"
        case .albums: return "rectangle.stack.fill"
        case .mediaTypes: return "play.rectangle.fill"
        case .utilities: return "folder.badge.gearshape"
        case .projects: return "hammer.fill"
        case .sharedAlbums: return "person.2.crop.square.stack.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedSidebarItem: SidebarNavigationItem? = .library
    @StateObject private var photoManager = PhotoLibraryManager()

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedItem: $selectedSidebarItem, photoManager: photoManager)
        } detail: {
            MainContentView(selectedCollection: selectedSidebarItem, photoManager: photoManager)
        }
    }
}

struct SidebarView: View {
    @Binding var selectedItem: SidebarNavigationItem?
    @ObservedObject var photoManager: PhotoLibraryManager

    var body: some View {
        List(selection: $selectedItem) {
            Section("Photos") {
                ForEach([SidebarNavigationItem.library, .favorites, .recentlySaved, .mapLocation], id: \.self) { item in
                    SidebarRow(item: item)
                }
            }

            Section("Collections") {
                ForEach([SidebarNavigationItem.days, .peopleAndPets, .memories, .trips, .featuredPhotos], id: \.self) { item in
                     SidebarRow(item: item)
                }
            }
            
            Section {
                Button(action: {
                    photoManager.openFilePicker()
                }) {
                    Label("Import...", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                
                DisclosureGroup("Albums") {
                    Text("My Album 1").padding(.leading)
                    Text("My Album 2").padding(.leading)
                }
                DisclosureGroup("Sharing") {
                    Text("Shared Album 1").padding(.leading)
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 200)
    }
}

struct SidebarRow: View {
    let item: SidebarNavigationItem
    
    var body: some View {
        Label(item.rawValue, systemImage: item.iconName)
    }
}

struct MainContentView: View {
    let selectedCollection: SidebarNavigationItem?
    @ObservedObject var photoManager: PhotoLibraryManager
    @State private var gridColumns: Double = 7

    var body: some View {
        VStack(spacing: 0) {
            // 슬라이더 컨트롤 영역
            HStack {
                Image(systemName: "square.grid.2x2")
                    .foregroundColor(.secondary)
                Slider(value: $gridColumns, in: 3...15, step: 1)
                    .frame(width: 150)
                Image(systemName: "square.grid.3x3")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial)
            
            PhotoGridView(photos: photoManager.photos, columns: Int(gridColumns))
                .environmentObject(photoManager)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            photoManager.requestAuthorization()
        }
    }
}



struct EmptyPhotosView: View {
    @EnvironmentObject var photoManager: PhotoLibraryManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("현재 이미지가 없습니다.")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Button(action: {
                    photoManager.openFilePicker()
                }) {
                    Text("이미지를 추가해주세요")
                        .font(.body)
                        .foregroundColor(.blue)
                        .underline()
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct PhotoGridView: View {
    let photos: [PhotoItem]
    let columns: Int
    
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: columns)
    }

    var body: some View {
        ScrollView {
            if photos.isEmpty {
                EmptyPhotosView()
            } else {
                LazyVGrid(columns: gridColumns, spacing: 4) {
                    ForEach(photos) { photo in
                        PhotoThumbnailView(photo: photo)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct PhotoThumbnailView: View {
    let photo: PhotoItem

    var body: some View {
        Image(nsImage: photo.image)
            .resizable()
            .aspectRatio(1, contentMode: .fill)
            .onTapGesture {
                print("Selected photo: \(photo.id)")
            }
    }
}

// 데이터 모델
struct PhotoItem: Identifiable {
    let id: String
    let image: NSImage
}

// 프리뷰
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
    }
}

