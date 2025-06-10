//
//  PhotoLibraryManager.swift
//  serbase
//
//  Created by 구리뽕 on 6/8/25.
//

import SwiftUI
import Photos
import AppKit

class PhotoLibraryManager: ObservableObject {
    @Published var photos: [PhotoItem] = []
    
    func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            switch status {
            case .authorized:
                print("Photo library access authorized.")
                self?.fetchPhotos()
            case .denied, .restricted:
                print("Photo library access denied.")
            case .notDetermined:
                print("Photo library access not determined.")
            @unknown default:
                fatalError()
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
                            fetchedPhotos.append(PhotoItem(id: asset.localIdentifier, image: image))
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
            var newPhotos: [PhotoItem] = []
            for url in openPanel.urls {
                // Check if the URL points to a directory
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                    // It's a directory, enumerate its contents
                    do {
                        let fileURLs = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
                        for fileURL in fileURLs {
                            if let image = NSImage(contentsOf: fileURL) {
                                newPhotos.append(PhotoItem(id: fileURL.path, image: image))
                            }
                        }
                    } catch {
                        print("Error enumerating files: \(error.localizedDescription)")
                    }
                } else {
                    // It's a single file
                    if let image = NSImage(contentsOf: url) {
                        newPhotos.append(PhotoItem(id: url.path, image: image))
                    }
                }
            }
            
            DispatchQueue.main.async {
                // Prepend new photos to the existing list
                self.photos.insert(contentsOf: newPhotos, at: 0)
            }
        }
    }
} 