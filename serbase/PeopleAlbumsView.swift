//
//  PeopleAlbumsView.swift
//  serbase
//
//  Created by 구리뽕 on 6/8/25.
//

import SwiftUI

struct PeopleAlbumsView: View {
    @EnvironmentObject var photoManager: PhotoLibraryManager
    @StateObject private var faceClusteringManager = FaceClusteringManager()
    @State private var selectedCluster: FaceCluster?
    @State private var showingClusterPhotos = false
    @State private var showingProcessingAlert = false
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
    
    var body: some View {
        VStack {
            // 헤더
            HStack {
                Text("인물 앨범")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                if faceClusteringManager.isProcessing {
                    HStack {
                        ProgressView(value: faceClusteringManager.processingProgress)
                            .frame(width: 200)
                        Text("\(Int(faceClusteringManager.processingProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button("얼굴 분석 시작") {
                        startFaceAnalysis()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(photoManager.photos.isEmpty)
                }
            }
            .padding()
            
            if faceClusteringManager.faceClusters.isEmpty && !faceClusteringManager.isProcessing {
                // 빈 상태
                EmptyPeopleView {
                    startFaceAnalysis()
                }
            } else {
                // 인물 클러스터 그리드
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(faceClusteringManager.faceClusters) { cluster in
                            PersonClusterCard(
                                cluster: cluster,
                                photoCount: cluster.faceInstances.count
                            )
                            .onTapGesture {
                                selectedCluster = cluster
                                showingClusterPhotos = true
                            }
                            .contextMenu {
                                Button("이름 변경") {
                                    renameCluster(cluster)
                                }
                                
                                Button("앨범으로 저장") {
                                    createAlbumFromCluster(cluster)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingClusterPhotos) {
            if let cluster = selectedCluster {
                ClusterPhotosView(
                    cluster: cluster,
                    photos: faceClusteringManager.getPhotosForCluster(cluster, from: photoManager.photos)
                )
            }
        }
        .alert("얼굴 분석", isPresented: $showingProcessingAlert) {
            Button("확인") { }
        } message: {
            Text("사진들에서 얼굴을 분석하여 인물별로 자동으로 분류합니다. 처리 시간이 다소 걸릴 수 있습니다.")
        }
    }
    
    private func startFaceAnalysis() {
        guard !photoManager.photos.isEmpty else { return }
        showingProcessingAlert = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            faceClusteringManager.processPhotosForFaceDetection(photoManager.photos)
        }
    }
    
    private func renameCluster(_ cluster: FaceCluster) {
        // 이름 변경 다이얼로그 (간단하게 구현)
        let alert = NSAlert()
        alert.messageText = "인물 이름 변경"
        alert.informativeText = "새로운 이름을 입력하세요:"
        alert.addButton(withTitle: "확인")
        alert.addButton(withTitle: "취소")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = cluster.name
        alert.accessoryView = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty {
                faceClusteringManager.renameCluster(clusterId: cluster.id, newName: newName)
            }
        }
    }
    
    private func createAlbumFromCluster(_ cluster: FaceCluster) {
        let albumName = "\(cluster.name) 앨범"
        photoManager.createAlbum(name: albumName)
        
        // 새로 생성된 앨범에 해당 클러스터의 사진들 추가
        if let newAlbum = photoManager.albums.last {
            let clusterPhotoIds = Set(cluster.faceInstances.map { $0.photoId })
            for photoId in clusterPhotoIds {
                photoManager.addPhoto(photoId, to: newAlbum.id)
            }
        }
    }
}

struct PersonClusterCard: View {
    let cluster: FaceCluster
    let photoCount: Int
    
    var body: some View {
        VStack {
            // 대표 사진
            if let representativePhoto = cluster.representativePhoto {
                ZStack {
                    // 투명한 원형 배경
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 120, height: 120)
                    
                    // 원본 비율을 유지하는 이미지
                    Image(nsImage: representativePhoto.image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 120, maxHeight: 120)
                }
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 120)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    )
            }
            
            VStack(spacing: 4) {
                Text(cluster.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Text("\(photoCount)장의 사진")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onHover { isHovered in
            // 호버 효과는 필요에 따라 추가
        }
    }
}

struct ClusterPhotosView: View {
    let cluster: FaceCluster
    let photos: [PhotoItem]
    @Environment(\.dismiss) private var dismiss
    @State private var thumbnailSize: Double = 120.0
    
    private var dynamicColumns: [GridItem] {
        let screenWidth = NSScreen.main?.frame.width ?? 1200
        let availableWidth = screenWidth - 80 // 패딩 고려
        let columnCount = max(3, Int(availableWidth / (thumbnailSize + 8))) // spacing 고려
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // 헤더
                HStack {
                    VStack(alignment: .leading) {
                        Text(cluster.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("\(photos.count)장의 사진")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("완료") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                // 확대/축소 컨트롤
                HStack {
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                    Slider(value: $thumbnailSize, in: 80...200, step: 10)
                        .frame(maxWidth: 200)
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                        .font(.title2)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // 사진 그리드
                ScrollView {
                    LazyVGrid(columns: dynamicColumns, spacing: 8) {
                        ForEach(photos) { photo in
                            ClusterPhotoThumbnail(photo: photo, thumbnailSize: thumbnailSize)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct ClusterPhotoThumbnail: View {
    let photo: PhotoItem
    let thumbnailSize: Double
    @State private var selectedPhotoForDetail: PhotoItem?
    
    var body: some View {
        ZStack {
            // 투명한 사각형 배경
            Rectangle()
                .fill(Color.clear)
                .frame(width: thumbnailSize, height: thumbnailSize)
            
            // 원본 비율을 유지하는 이미지
            Image(nsImage: photo.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: thumbnailSize, maxHeight: thumbnailSize)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(count: 2) {
            selectedPhotoForDetail = photo
        }
        .sheet(item: $selectedPhotoForDetail) { photo in
            FullScreenPhotoView(photo: photo, isPresented: .constant(true))
        }
    }
}

struct EmptyPeopleView: View {
    let onStartAnalysis: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("인물 앨범이 없습니다")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("사진에서 얼굴을 자동으로 인식하여\n인물별로 앨범을 만들어보세요")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("얼굴 분석 시작") {
                onStartAnalysis()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PeopleAlbumsView_Previews: PreviewProvider {
    static var previews: some View {
        PeopleAlbumsView()
            .environmentObject(PhotoLibraryManager())
            .frame(width: 1000, height: 700)
    }
} 