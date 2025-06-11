//
//  FaceClusteringManager.swift
//  serbase
//
//  Created by 구리뽕 on 6/8/25.
//

import Foundation
import Vision
import CoreML
import AppKit
import CoreImage

// 얼굴 클러스터 모델
struct FaceCluster: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var faceInstances: [FaceInstance] = []
    var representativePhoto: PhotoItem? // 대표 사진
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FaceCluster, rhs: FaceCluster) -> Bool {
        lhs.id == rhs.id
    }
}

// 개별 얼굴 인스턴스
struct FaceInstance: Identifiable, Hashable {
    let id = UUID()
    let photoId: String
    let boundingBox: CGRect
    let featureVector: [Float]
    let confidence: Float
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FaceInstance, rhs: FaceInstance) -> Bool {
        lhs.id == rhs.id
    }
}

class FaceClusteringManager: ObservableObject {
    @Published var faceClusters: [FaceCluster] = []
    @Published var isProcessing: Bool = false
    @Published var processingProgress: Double = 0.0
    
    private let faceDetectionRequest = VNDetectFaceRectanglesRequest()
    private let featureExtractRequest = VNGenerateImageFeaturePrintRequest()
    
    init() {
        setupVisionRequests()
    }
    
    private func setupVisionRequests() {
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
        featureExtractRequest.revision = VNGenerateImageFeaturePrintRequestRevision1
    }
    
    // 사진들에서 얼굴을 탐지하고 클러스터링 수행
    func processPhotosForFaceDetection(_ photos: [PhotoItem]) {
        guard !photos.isEmpty else { return }
        
        isProcessing = true
        processingProgress = 0.0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var allFaceInstances: [FaceInstance] = []
            let totalPhotos = photos.count
            
            for (index, photo) in photos.enumerated() {
                // 각 사진에서 얼굴 탐지
                let faceInstances = self.detectFacesInPhoto(photo)
                allFaceInstances.append(contentsOf: faceInstances)
                
                DispatchQueue.main.async {
                    self.processingProgress = Double(index + 1) / Double(totalPhotos) * 0.8 // 80%까지는 얼굴 탐지
                }
            }
            
            // 클러스터링 수행
            let clusters = self.performClustering(faceInstances: allFaceInstances, photos: photos)
            
            DispatchQueue.main.async {
                self.faceClusters = clusters
                self.processingProgress = 1.0
                self.isProcessing = false
            }
        }
    }
    
    private func detectFacesInPhoto(_ photo: PhotoItem) -> [FaceInstance] {
        guard let cgImage = photo.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }
        
        var faceInstances: [FaceInstance] = []
        
        // 얼굴 탐지 요청
        let faceRequest = VNDetectFaceRectanglesRequest { request, error in
            guard let observations = request.results as? [VNFaceObservation], error == nil else {
                return
            }
            
            for observation in observations {
                // 각 얼굴에 대해 특징 벡터 추출
                if let featureVector = self.extractFaceFeatures(from: cgImage, faceBox: observation.boundingBox) {
                    let faceInstance = FaceInstance(
                        photoId: photo.id,
                        boundingBox: observation.boundingBox,
                        featureVector: featureVector,
                        confidence: observation.confidence
                    )
                    faceInstances.append(faceInstance)
                }
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([faceRequest])
        
        return faceInstances
    }
    
    private func extractFaceFeatures(from cgImage: CGImage, faceBox: CGRect) -> [Float]? {
        // 얼굴 영역을 크롭
        let faceRect = VNImageRectForNormalizedRect(faceBox, cgImage.width, cgImage.height)
        guard let croppedImage = cgImage.cropping(to: faceRect) else { return nil }
        
        var featureVector: [Float]?
        
        let featureRequest = VNGenerateImageFeaturePrintRequest { request, error in
            guard let observations = request.results as? [VNFeaturePrintObservation],
                  let firstObservation = observations.first,
                  error == nil else {
                return
            }
            
            // Feature print를 Float 배열로 변환
            let data = firstObservation.data
            featureVector = data.withUnsafeBytes { rawBufferPointer in
                let bufferPointer = rawBufferPointer.bindMemory(to: Float.self)
                return Array(bufferPointer)
            }
        }
        
        let handler = VNImageRequestHandler(cgImage: croppedImage, options: [:])
        try? handler.perform([featureRequest])
        
        return featureVector
    }
    
    private func performClustering(faceInstances: [FaceInstance], photos: [PhotoItem]) -> [FaceCluster] {
        guard !faceInstances.isEmpty else { return [] }
        
        var clusters: [FaceCluster] = []
        let threshold: Float = 0.6 // 클러스터링 임계값 (조정 가능)
        
        for faceInstance in faceInstances {
            var addedToCluster = false
            
            // 기존 클러스터와 유사도 비교
            for (index, cluster) in clusters.enumerated() {
                if let representativeFace = cluster.faceInstances.first {
                    let similarity = cosineSimilarity(
                        vector1: faceInstance.featureVector,
                        vector2: representativeFace.featureVector
                    )
                    
                    if similarity > threshold {
                        clusters[index].faceInstances.append(faceInstance)
                        addedToCluster = true
                        break
                    }
                }
            }
            
            // 기존 클러스터에 속하지 않으면 새 클러스터 생성
            if !addedToCluster {
                let newCluster = FaceCluster(
                    name: "인물 \(clusters.count + 1)",
                    faceInstances: [faceInstance],
                    representativePhoto: photos.first { $0.id == faceInstance.photoId }
                )
                clusters.append(newCluster)
            }
        }
        
        // 클러스터별 대표 사진 설정 (가장 신뢰도 높은 얼굴이 포함된 사진)
        for (index, cluster) in clusters.enumerated() {
            if let bestFace = cluster.faceInstances.max(by: { $0.confidence < $1.confidence }) {
                clusters[index].representativePhoto = photos.first { $0.id == bestFace.photoId }
            }
        }
        
        // 최소 2개 이상의 얼굴이 있는 클러스터만 반환 (노이즈 제거)
        return clusters.filter { $0.faceInstances.count >= 2 }
    }
    
    private func cosineSimilarity(vector1: [Float], vector2: [Float]) -> Float {
        guard vector1.count == vector2.count, !vector1.isEmpty else { return 0 }
        
        let dotProduct = zip(vector1, vector2).map(*).reduce(0, +)
        let magnitude1 = sqrt(vector1.map { $0 * $0 }.reduce(0, +))
        let magnitude2 = sqrt(vector2.map { $0 * $0 }.reduce(0, +))
        
        return dotProduct / (magnitude1 * magnitude2)
    }
    
    // 클러스터 이름 변경
    func renameCluster(clusterId: UUID, newName: String) {
        if let index = faceClusters.firstIndex(where: { $0.id == clusterId }) {
            faceClusters[index].name = newName
        }
    }
    
    // 특정 클러스터의 모든 사진 가져오기
    func getPhotosForCluster(_ cluster: FaceCluster, from allPhotos: [PhotoItem]) -> [PhotoItem] {
        let photoIds = Set(cluster.faceInstances.map { $0.photoId })
        return allPhotos.filter { photoIds.contains($0.id) }
    }
    
    // 클러스터 병합
    func mergeClusters(sourceClusterId: UUID, targetClusterId: UUID) {
        guard let sourceIndex = faceClusters.firstIndex(where: { $0.id == sourceClusterId }),
              let targetIndex = faceClusters.firstIndex(where: { $0.id == targetClusterId }),
              sourceIndex != targetIndex else { return }
        
        let sourceFaces = faceClusters[sourceIndex].faceInstances
        faceClusters[targetIndex].faceInstances.append(contentsOf: sourceFaces)
        faceClusters.remove(at: sourceIndex)
    }
} 