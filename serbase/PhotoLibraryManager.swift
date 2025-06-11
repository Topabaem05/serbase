//
//  PhotoLibraryManager.swift
//  serbase
//
//  Created by 구리뽕 on 6/8/25.
//

import SwiftUI
import Photos
import AppKit
import CoreLocation

class PhotoLibraryManager: ObservableObject {
    @Published var photos: [PhotoItem] = [] {
        didSet { updateFilteredPhotos() }
    }
    @Published var albums: [Album] = [] {
        didSet { updateFilteredPhotos() }
    }
    
    @Published var filteredPhotos: [PhotoItem] = []
    @Published var groupedPhotos: [(date: Date, photos: [PhotoItem])] = []
    
    var selectedFilter: SidebarNavigationItem? = .library {
        didSet { updateFilteredPhotos() }
    }
    var selectedAlbumId: UUID? {
        didSet {
            if oldValue != selectedAlbumId {
                selectedFilter = nil // 앨범 선택 시, 다른 필터는 해제
                updateFilteredPhotos()
            }
        }
    }

    func updateFilteredPhotos() {
        var preFilteredPhotos: [PhotoItem]
        
        if let albumId = selectedAlbumId, let album = albums.first(where: { $0.id == albumId }) {
            preFilteredPhotos = photos.filter { album.photoIDs.contains($0.id) }
        } else if let filter = selectedFilter {
            switch filter {
            case .library:
                preFilteredPhotos = photos
            case .favorites:
                preFilteredPhotos = photos.filter { $0.isFavorite }
            case .recentlySaved:
                let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
                preFilteredPhotos = photos.filter {
                    ($0.modificationDate ?? $0.creationDate ?? Date.distantPast) > thirtyDaysAgo
                }.sorted(by: { ($0.modificationDate ?? $0.creationDate!) > ($1.modificationDate ?? $1.creationDate!) })
            case .mapLocation:
                preFilteredPhotos = photos.filter { $0.location != nil }
            case .days:
                let groupedDictionary = Dictionary(grouping: self.photos.filter { !$0.isHidden }, by: {
                    Calendar.current.startOfDay(for: $0.creationDate ?? Date.distantPast)
                })
                let sortedGroups = groupedDictionary.sorted { $0.key < $1.key }
                self.groupedPhotos = sortedGroups.map { (date: $0.key, photos: $0.value) }
                self.filteredPhotos = []
                return
            default:
                // peopleAndPets, memories, trips, featuredPhotos 등
                preFilteredPhotos = photos
            }
        } else {
            preFilteredPhotos = photos
        }

        // 공통 필터: 가려진 사진 제외
        filteredPhotos = preFilteredPhotos.filter { !$0.isHidden }
        groupedPhotos = []
    }

    func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            switch status {
            case .notDetermined:
                print("Photo library access not determined.")
                // 사용자가 아직 선택하지 않았으므로, 다시 권한 요청을 유도할 수 있습니다.
            case .restricted:
                print("Photo library access restricted.")
            case .denied:
                print("Photo library access denied.")
            case .authorized:
                print("Photo library access authorized.")
                self?.fetchPhotos()
            case .limited:
                print("Photo library access limited.")
                self?.fetchPhotos()
            @unknown default:
                print("An unknown authorization status was returned.")
            }
        }
    }
    
    func fetchPhotos() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let fetchResult: PHFetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            let imageManager = PHImageManager.default()
            let requestOptions = PHImageRequestOptions()
            requestOptions.isSynchronous = true
            requestOptions.deliveryMode = .opportunistic
            
            var fetchedPhotos: [PhotoItem] = []
            
            if fetchResult.count > 0 {
                // For performance, we'll fetch a limited number of photos.
                // In a real app, you might implement paging.
                let countToFetch = min(fetchResult.count, 100)
                
                fetchResult.enumerateObjects(at: IndexSet(0..<countToFetch), options: []) { (asset, count, stop) in
                    imageManager.requestImage(for: asset, targetSize: CGSize(width: 300, height: 300), contentMode: .aspectFill, options: requestOptions) { (image, info) in
                        if let image = image {
                            let newPhoto = PhotoItem(
                                id: asset.localIdentifier,
                                image: image,
                                creationDate: asset.creationDate,
                                modificationDate: asset.modificationDate,
                                location: asset.location,
                                isFavorite: asset.isFavorite
                            )
                            fetchedPhotos.append(newPhoto)
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.photos = fetchedPhotos
            }
        }
    }
    
    func openFilePicker() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = true
        openPanel.allowedContentTypes = [.image]
        
        if openPanel.runModal() == .OK {
            for url in openPanel.urls {
                self.addPhoto(from: url)
            }
        }
    }

    func addPhoto(from url: URL) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            // 디렉토리인 경우
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey], options: .skipsHiddenFiles)
                for fileURL in fileURLs {
                    self.createPhotoItem(from: fileURL)
                }
            } catch {
                print("Error enumerating files: \(error.localizedDescription)")
            }
        } else {
            // 단일 파일인 경우
            self.createPhotoItem(from: url)
        }
    }

    private func createPhotoItem(from url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            
            // TODO: 이미지 파일에서 EXIF 데이터를 읽어 위치 정보(location)를 추출하는 로직 추가 필요
            
            let newPhoto = PhotoItem(
                id: url.path,
                image: image,
                creationDate: resourceValues.creationDate,
                modificationDate: resourceValues.contentModificationDate,
                location: nil, // Placeholder
                sourceURL: url
            )
            
            DispatchQueue.main.async {
                self.photos.insert(newPhoto, at: 0)
            }
        } catch {
            print("Error getting file resource values: \(error)")
        }
    }

    // MARK: - Photo Actions

    func deletePhoto(id: String) {
        photos.removeAll { $0.id == id }
        // TODO: PHPhotoLibrary에서 삭제, 로컬 파일 삭제 로직 추가 필요
    }

    func toggleFavorite(id: String) {
        if let index = photos.firstIndex(where: { $0.id == id }) {
            photos[index].isFavorite.toggle()
            updateFilteredPhotos() // 즐겨찾기 상태 변경 후 필터 업데이트
        }
    }
    
    // MARK: - Album Actions
    
    func createAlbum(name: String) {
        let newAlbum = Album(name: name)
        albums.append(newAlbum)
    }
    
    func addPhoto(_ photoId: String, to albumId: UUID) {
        if let albumIndex = albums.firstIndex(where: { $0.id == albumId }) {
            if !albums[albumIndex].photoIDs.contains(photoId) {
                albums[albumIndex].photoIDs.append(photoId)
            }
        }
    }
    
    func rotatePhoto(id: String) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        
        let originalImage = photos[index].image
        let newImage = NSImage(size: NSSize(width: originalImage.size.height, height: originalImage.size.width))
        
        newImage.lockFocus()
        
        let transform = NSAffineTransform()
        transform.rotate(byDegrees: -90)
        transform.translateX(by: -originalImage.size.height, yBy: 0)
        transform.concat()
        
        originalImage.draw(at: .zero, from: NSRect(origin: .zero, size: originalImage.size), operation: .sourceOver, fraction: 1.0)
        
        newImage.unlockFocus()
        
        photos[index].image = newImage
        objectWillChange.send() // Manually notify views of the change
    }

    func duplicatePhoto(id: String) {
        guard let originalPhotoIndex = photos.firstIndex(where: { $0.id == id }) else { return }
        let originalPhoto = photos[originalPhotoIndex]
        
        let newPhoto = PhotoItem(
            id: UUID().uuidString, // 새 사진에는 새 ID 부여
            image: originalPhoto.image.copy() as! NSImage,
            creationDate: originalPhoto.creationDate,
            modificationDate: Date(), // 복제 시점을 수정 시각으로
            location: originalPhoto.location,
            isFavorite: originalPhoto.isFavorite,
            sourceURL: originalPhoto.sourceURL
        )
        
        photos.insert(newPhoto, at: originalPhotoIndex + 1)
    }
    
    func hidePhoto(id: String) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        photos[index].isHidden = true
        updateFilteredPhotos()
    }
} 
