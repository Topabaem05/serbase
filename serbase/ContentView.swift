//
//  ContentView.swift
//  serbase
//
//  Created by 구리뽕 on 6/8/25.
//

import SwiftUI
import CoreLocation
import MapKit

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
    @StateObject private var photoManager = PhotoLibraryManager()
    @State private var selectedSidebarItem: SidebarNavigationItem? = .library
    @State private var selectedAlbumId: UUID?

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selectedItem: $selectedSidebarItem,
                selectedAlbumId: $selectedAlbumId
            )
        } detail: {
            MainContentView(selectedCollection: selectedSidebarItem)
        }
        .environmentObject(photoManager)
        .onChange(of: selectedSidebarItem) { newValue in
            // 사이드바의 기본 항목이 선택되면 앨범 선택은 해제
            if newValue != nil {
                selectedAlbumId = nil
                photoManager.selectedAlbumId = nil
            }
            photoManager.selectedFilter = newValue
        }
        .onChange(of: selectedAlbumId) { newValue in
            // 앨범이 선택되면 사이드바 기본 항목 선택은 해제
            if newValue != nil {
                selectedSidebarItem = nil
                photoManager.selectedFilter = nil
            }
            photoManager.selectedAlbumId = newValue
        }
        .onAppear {
            photoManager.requestAuthorization()
        }
    }
}

struct SidebarView: View {
    @Binding var selectedItem: SidebarNavigationItem?
    @Binding var selectedAlbumId: UUID?
    @EnvironmentObject var photoManager: PhotoLibraryManager

    var body: some View {
        List {
            Section("Photos") {
                ForEach([SidebarNavigationItem.library, .favorites, .recentlySaved, .mapLocation], id: \.self) { item in
                    SidebarRow(item: item)
                        .onTapGesture { self.selectedItem = item }
                        .listRowBackground(self.selectedItem == item ? Color.accentColor.opacity(0.3) : Color.clear)
                }
            }

            Section("Collections") {
                ForEach([SidebarNavigationItem.days, .peopleAndPets, .memories, .trips, .featuredPhotos], id: \.self) { item in
                     SidebarRow(item: item)
                        .onTapGesture { self.selectedItem = item }
                        .listRowBackground(self.selectedItem == item ? Color.accentColor.opacity(0.3) : Color.clear)
                }
            }
            
            Section {
                Button(action: {
                    photoManager.openFilePicker()
                }) {
                    Label("Import...", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    let albumName = "New Album \(photoManager.albums.count + 1)"
                    photoManager.createAlbum(name: albumName)
                }) {
                    Label("Create Album", systemImage: "plus.square")
                }
                .buttonStyle(.plain)

                DisclosureGroup("Albums") {
                    List(selection: $selectedAlbumId) {
                        ForEach(photoManager.albums) { album in
                            Label(album.name, systemImage: "rectangle.stack").tag(album.id)
                        }
                    }
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
    @EnvironmentObject var photoManager: PhotoLibraryManager

    var body: some View {
        Group {
            if selectedCollection == .mapLocation {
                PhotoMapView(photos: photoManager.filteredPhotos)
            } else if selectedCollection == .days {
                GroupedPhotoGridView(groupedPhotos: photoManager.groupedPhotos)
            } else {
                ZStack(alignment: .topLeading) {
                    PhotoGridView(photos: photoManager.filteredPhotos)
                    if selectedCollection == .library {
                        DateHeaderView()
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct PhotoMapView: View {
    let photos: [PhotoItem]
    @State private var region: MKCoordinateRegion

    init(photos: [PhotoItem]) {
        self.photos = photos
        
        var initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780), // Default to Seoul
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
        
        if let firstLocation = photos.first?.coordinate {
            initialRegion.center = firstLocation
        }
        _region = State(initialValue: initialRegion)
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: photos) { photo in
            MapAnnotation(coordinate: photo.coordinate) {
                Image(nsImage: photo.image)
                    .resizable()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
            }
        }
    }
}

struct GroupedPhotoGridView: View {
    let groupedPhotos: [(date: Date, photos: [PhotoItem])]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    @State private var selectedPhotoForInfo: PhotoItem?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(groupedPhotos, id: \.date) { group in
                    GroupDateHeaderView(date: group.date)
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(group.photos) { photo in
                            PhotoThumbnailView(photo: photo, selectedPhotoForInfo: $selectedPhotoForInfo)
                        }
                    }
                }
            }
            .padding()
        }
        .sheet(item: $selectedPhotoForInfo) { photo in
            PhotoInfoView(photo: photo)
        }
    }
}

struct GroupDateHeaderView: View {
    let date: Date
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY년 M월 d일 EEEE"
        return formatter
    }()
    
    var body: some View {
        Text(Self.dateFormatter.string(from: date))
            .font(.headline)
            .fontWeight(.bold)
    }
}

struct DateHeaderView: View {
    var body: some View {
        Text("Mar 15, 2024")
            .font(.headline)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding()
    }
}

struct PhotoGridView: View {
    let photos: [PhotoItem]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    @State private var selectedPhotoForDetail: PhotoItem?
    @State private var selectedPhotoForInfo: PhotoItem?

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                if photos.isEmpty {
                    ForEach(0..<50) { _ in
                        Rectangle()
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .aspectRatio(1, contentMode: .fill)
                    }
                } else {
                    ForEach(photos) { photo in
                        PhotoThumbnailView(photo: photo, selectedPhotoForInfo: $selectedPhotoForInfo)
                            .onTapGesture(count: 2) {
                                selectedPhotoForDetail = photo
                            }
                    }
                }
            }
            .padding(.horizontal)
        }
        .sheet(item: $selectedPhotoForDetail) { photo in
            FullScreenPhotoView(photo: photo, isPresented: .constant(true))
        }
        .sheet(item: $selectedPhotoForInfo) { photo in
            PhotoInfoView(photo: photo)
        }
    }
}

struct PhotoThumbnailView: View {
    let photo: PhotoItem
    @Binding var selectedPhotoForInfo: PhotoItem?
    @EnvironmentObject var photoManager: PhotoLibraryManager

    var body: some View {
        Image(nsImage: photo.image)
            .resizable()
            .aspectRatio(1, contentMode: .fill)
            .overlay(alignment: .bottomTrailing) {
                if photo.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white)
                        .font(.callout)
                        .padding(4)
                        .shadow(radius: 2)
                }
            }
            .onTapGesture {} // Single tap gesture to make context menu work better
            .contextMenu {
                Button("Get Info") {
                    selectedPhotoForInfo = photo
                }
                
                Button("Share...") {
                    guard let url = photo.sourceURL else { return }
                    
                    // macOS 13+ compatible way to get the key window
                    if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }), let contentView = window.contentView {
                        let sharingPicker = NSSharingServicePicker(items: [url])
                        sharingPicker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                    }
                }
                
                Divider()

                Button("Rotate Clockwise") {
                    photoManager.rotatePhoto(id: photo.id)
                }
                
                Button("Duplicate") {
                    photoManager.duplicatePhoto(id: photo.id)
                }

                Menu("Add to Album") {
                    if photoManager.albums.isEmpty {
                        Text("No Albums")
                    }
                    ForEach(photoManager.albums) { album in
                        Button(album.name) {
                            photoManager.addPhoto(photo.id, to: album.id)
                        }
                    }
                }
                
                Button("Edit With...") {
                    if let url = photo.sourceURL {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()

                Button(photo.isFavorite ? "Unfavorite" : "Favorite") {
                    photoManager.toggleFavorite(id: photo.id)
                }
                
                Button("Hide Photo") {
                    photoManager.hidePhoto(id: photo.id)
                }
                
                Divider()

                Button("Delete Photo") {
                    photoManager.deletePhoto(id: photo.id)
                }
            }
    }
}

// 데이터 모델
struct PhotoItem: Identifiable, Equatable {
    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id && lhs.isFavorite == rhs.isFavorite
    }
    
    let id: String // PHAsset.localIdentifier 또는 파일 경로
    var image: NSImage
    
    // 확장된 속성
    var creationDate: Date?
    var modificationDate: Date?
    var location: CLLocation?
    var isFavorite: Bool = false
    var isHidden: Bool = false
    var sourceURL: URL?

    var coordinate: CLLocationCoordinate2D {
        location?.coordinate ?? CLLocationCoordinate2D()
    }
}

struct Album: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var photoIDs: [String] = []
}

// 프리뷰
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .frame(width: 1200, height: 800)
            .environmentObject(PhotoLibraryManager())
    }
}

